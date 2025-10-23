package clusterize

import (
	"fmt"
	"os"
	"strings"

	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"

	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/aws_functions_def"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/report"
	"github.com/weka/go-cloud-lib/clusterize"
	cloudCommon "github.com/weka/go-cloud-lib/common"
	"github.com/weka/go-cloud-lib/functions_def"
	cloudStrings "github.com/weka/go-cloud-lib/lib/strings"
	"github.com/weka/go-cloud-lib/protocol"
	"github.com/weka/go-cloud-lib/utils"
)

type ClusterizationParams struct {
	AdminPasswordId      string
	DeploymentPasswordId string
	StateTable           string
	StateTableHashKey    string
	StateKey             string
	NfsStateKey          string
	InstallDpdk          bool
	Vm                   protocol.Vm
	Cluster              clusterize.ClusterParams
	NFSParams            protocol.NFSParams
	Obs                  protocol.ObsParams
	AlbArnSuffix         string
}

func Clusterize(p ClusterizationParams) (clusterizeScript string, err error) {
	funcDef := aws_functions_def.NewFuncDef()

	if p.Vm.Protocol == protocol.NFS {
		clusterizeScript, err = doNFSClusterize(p, funcDef)
	} else if p.Vm.Protocol == protocol.SMB || p.Vm.Protocol == protocol.S3 {
		msg := fmt.Sprintf("%s protocol gw: %s setup is done", strings.ToUpper(string(p.Vm.Protocol)), p.Vm.Name)
		clusterizeScript = cloudCommon.GetScriptWithReport(msg, funcDef.GetFunctionCmdDefinition(functions_def.Report), "")
	} else {
		clusterizeScript, err = doClusterize(p, funcDef)
	}
	return
}

func doClusterize(p ClusterizationParams, funcDef functions_def.FunctionDef) (clusterizeScript string, err error) {
	state, err := common.AddInstanceToStateInstances(p.StateTable, p.StateTableHashKey, p.StateKey, p.Vm)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	msg := fmt.Sprintf("This (%s) is instance %d/%d that is ready for clusterization", p.Vm.Name, len(state.Instances), state.DesiredSize)
	log.Info().Msgf(msg)
	if len(state.Instances) != p.Cluster.ClusterizationTarget {
		clusterizeScript = cloudCommon.GetScriptWithReport(msg, funcDef.GetFunctionCmdDefinition(functions_def.Report), "")
		return
	}

	if p.Cluster.SetObs {
		if p.Obs.Name == "" {
			p.Obs.Name = strings.ToLower(strings.Join([]string{p.Cluster.Prefix, p.Cluster.ClusterName, "obs"}, "-"))
			err = common.CreateBucket(p.Obs.Name)
			if err != nil {
				log.Error().Err(err).Send()
				err = report.Report(
					protocol.Report{
						Type:     "error",
						Hostname: p.Vm.Name,
						Message:  fmt.Sprintf("Failed creating obs bucket %s: %s", p.Obs.Name, err),
					}, p.StateTable, p.StateTableHashKey, p.StateKey)
				if err != nil {
					log.Error().Err(err).Send()
				}
			}
		} else {
			log.Info().Msgf("Using existing obs bucket %s", p.Obs.Name)
		}
	}

	instancesNames := common.GetInstancesNames(state.Instances)
	ips, err := common.GetBackendsPrivateIPsFromInstanceIds(cloudStrings.ListToRefList(instancesNames))
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	log.Info().Msg("setting weka admin password in secrets manager")
	adminPassword := utils.GeneratePassword(16, 1, 1, 1)
	err = common.SetSecret(p.AdminPasswordId, adminPassword)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	log.Info().Msg("setting weka deployment password in secrets manager")
	wekaDeploymentPassword := utils.GeneratePassword(16, 1, 1, 1)
	err = common.SetSecret(p.DeploymentPasswordId, wekaDeploymentPassword)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	clusterParams := p.Cluster
	clusterParams.VMNames = instancesNames
	clusterParams.IPs = ips
	clusterParams.InstallDpdk = p.InstallDpdk
	clusterParams.FindDrivesScript = common.FindDrivesScript
	clusterParams.ObsScript = GetObsScript(p.Obs)

	scriptGenerator := clusterize.ClusterizeScriptGenerator{
		Params:  clusterParams,
		FuncDef: funcDef,
	}
	clusterizeScript = scriptGenerator.GetClusterizeScript()

	log.Info().Msg("Clusterization script generated")
	return
}

func doNFSClusterize(p ClusterizationParams, funcDef functions_def.FunctionDef) (clusterizeScript string, err error) {
	state, err := common.AddInstanceToStateInstances(p.StateTable, p.StateTableHashKey, p.NfsStateKey, p.Vm)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	initialSize := p.NFSParams.HostsNum
	msg := fmt.Sprintf("This (%s) is nfs instance %d/%d that is ready for joining the interface group", p.Vm.Name, len(state.Instances), initialSize)
	log.Info().Msgf(msg)
	if len(state.Instances) != initialSize {
		clusterizeScript = cloudCommon.GetScriptWithReport(msg, funcDef.GetFunctionCmdDefinition(functions_def.Report), protocol.NFS)
		return
	}

	var containersUid []string
	var nicNames []string
	var instanceIds []string
	for _, instance := range state.Instances {
		containersUid = append(containersUid, instance.ContainerUid)
		nicNames = append(nicNames, instance.NicName)
		instanceIds = append(instanceIds, instance.Name)
	}

	secondaryIps, err := common.GetNfsClusterSecondaryIps(p.Cluster.ClusterName, cloudStrings.ListToRefList(instanceIds))
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	nfsParams := protocol.NFSParams{
		InterfaceGroupName: p.NFSParams.InterfaceGroupName,
		SecondaryIps:       secondaryIps,
		ContainersUid:      containersUid,
		NicNames:           nicNames,
	}

	albIp, err := common.GetALBIp(p.AlbArnSuffix)
	if err != nil {
		log.Error().Err(err).Send()
	}

	scriptGenerator := clusterize.ConfigureNfsScriptGenerator{
		Params:         nfsParams,
		FuncDef:        funcDef,
		LoadBalancerIP: albIp,
		Name:           p.Vm.Name,
	}

	clusterizeScript = scriptGenerator.GetNFSSetupScript()
	log.Info().Msg("Clusterization script generated")
	return
}

func GetObsScript(obsParams protocol.ObsParams) string {
	template := `
	OBS_TIERING_SSD_PERCENT=%s
	OBS_NAME="%s"
	REGION=%s

	weka fs tier s3 add aws-bucket --hostname s3.$REGION.amazonaws.com --port 443 --bucket "$OBS_NAME" --protocol https --auth-method AWSSignature4 --region $REGION --site local || return 1
	weka fs tier s3 attach default aws-bucket || return 1
	tiering_percent=$(echo "$full_capacity * 100 / $OBS_TIERING_SSD_PERCENT" | bc) || return 1
	weka fs update default --total-capacity "$tiering_percent"B || return 1
	`
	return fmt.Sprintf(
		dedent.Dedent(template), obsParams.TieringSsdPercent, obsParams.Name, os.Getenv("REGION"),
	)
}
