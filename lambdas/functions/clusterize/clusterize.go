package clusterize

import (
	"fmt"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/report"
	"os"
	"strings"

	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/aws_functions_def"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/go-cloud-lib/aws/aws_common"
	"github.com/weka/go-cloud-lib/clusterize"
	cloudCommon "github.com/weka/go-cloud-lib/common"
	"github.com/weka/go-cloud-lib/functions_def"
	cloudStrings "github.com/weka/go-cloud-lib/lib/strings"
	"github.com/weka/go-cloud-lib/protocol"
)

type ClusterizationParams struct {
	UsernameId        string
	PasswordId        string
	StateTable        string
	StateTableHashKey string
	VmName            string
	Cluster           clusterize.ClusterParams
	Obs               protocol.ObsParams
}

func Clusterize(p ClusterizationParams) (clusterizeScript string) {
	funcDef := aws_functions_def.NewFuncDef()
	reportFunction := funcDef.GetFunctionCmdDefinition(functions_def.Report)

	clusterizeScript, err := doClusterize(p, funcDef)
	if err != nil {
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction)
	}
	return
}

func doClusterize(p ClusterizationParams, funcDef functions_def.FunctionDef) (clusterizeScript string, err error) {
	instancesNames, err := common.AddInstanceToStateInstances(p.StateTable, p.StateTableHashKey, p.VmName)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	initialSize := p.Cluster.HostsNum
	msg := fmt.Sprintf("This (%s) is instance %d/%d that is ready for clusterization", p.VmName, len(instancesNames), initialSize)
	log.Info().Msgf(msg)
	if len(instancesNames) != initialSize {
		clusterizeScript = cloudCommon.GetScriptWithReport(msg, funcDef.GetFunctionCmdDefinition(functions_def.Report))
		return
	}

	if p.Cluster.SetObs {
		if p.Obs.Name == "" {
			p.Obs.Name = strings.Join([]string{p.Cluster.Prefix, p.Cluster.ClusterName, "obs"}, "-")
			err = common.CreateBucket(p.Obs.Name)
			if err != nil {
				log.Error().Err(err).Send()
				err = report.Report(
					protocol.Report{
						Type:     "error",
						Hostname: p.VmName,
						Message:  fmt.Sprintf("Failed creating obs bucket %s: %s", p.Obs.Name, err),
					}, p.StateTable, p.StateTableHashKey)
				if err != nil {
					log.Error().Err(err).Send()
				}
			}
		} else {
			log.Info().Msgf("Using existing obs bucket %s", p.Obs.Name)
		}
	}

	creds, err := aws_common.GetUsernameAndPassword(p.UsernameId, p.PasswordId)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	log.Info().Msgf("Fetched weka cluster creds successfully")

	ips, err := common.GetBackendsPrivateIPsFromInstanceIds(cloudStrings.ListToRefList(instancesNames))
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	clusterParams := p.Cluster
	clusterParams.VMNames = instancesNames
	clusterParams.IPs = ips
	clusterParams.DebugOverrideCmds = "echo 'nothing here'"
	clusterParams.WekaPassword = creds.Password
	clusterParams.WekaUsername = creds.Username
	clusterParams.InstallDpdk = true
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
