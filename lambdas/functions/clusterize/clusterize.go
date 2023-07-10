package clusterize

import (
	"fmt"
	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/aws_functions_def"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/go-cloud-lib/clusterize"
	cloudCommon "github.com/weka/go-cloud-lib/common"
	"github.com/weka/go-cloud-lib/protocol"
	"os"
)

type ClusterizationParams struct {
	UsernameId string
	PasswordId string
	Bucket     string
	VmName     string
	Cluster    clusterize.ClusterParams
	Obs        protocol.ObsParams
}

func Clusterize(p ClusterizationParams) (clusterizeScript string) {
	instancesNames, err := common.AddInstanceToStateInstances(p.Bucket, p.VmName)
	if err != nil {
		clusterizeScript = cloudCommon.GetErrorScript(err)
		return
	}

	if err != nil {
		clusterizeScript = cloudCommon.GetErrorScript(err)
		return
	}

	initialSize := p.Cluster.HostsNum
	msg := fmt.Sprintf("This (%s) is instance %d/%d that is ready for clusterization", p.VmName, len(instancesNames), initialSize)
	log.Info().Msgf(msg)
	if len(instancesNames) != initialSize {
		clusterizeScript = dedent.Dedent(fmt.Sprintf(`
		#!/bin/bash
		echo "%s"
		`, msg))
		return
	}

	creds, err := common.GetUsernameAndPassword(p.UsernameId, p.PasswordId)
	if err != nil {
		log.Error().Msgf("%s", err)
		clusterizeScript = cloudCommon.GetErrorScript(err)
		return
	}
	log.Info().Msgf("Fetched weka cluster creds successfully")

	funcDef := aws_functions_def.NewFuncDef()

	ips, err := common.GetBackendsPrivateIps(p.Cluster.ClusterName)

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

	weka fs tier s3 add aws-bucket --hostname s3-$REGION.amazonaws.com --port 443 --bucket "$OBS_NAME" --protocol https --auth-method AWSSignature4 --region $REGION --site local
	weka fs tier s3 attach default aws-bucket
	tiering_percent=$(echo "$full_capacity * 100 / $OBS_TIERING_SSD_PERCENT" | bc)
	weka fs update default --total-capacity "$tiering_percent"B
	`
	return fmt.Sprintf(
		dedent.Dedent(template), obsParams.TieringSsdPercent, obsParams.Name, os.Getenv("REGION"),
	)
}
