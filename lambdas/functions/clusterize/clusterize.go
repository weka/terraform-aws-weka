package clusterize

import (
	"fmt"
	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/common"
	AwsFunctionDef "github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/functions/aws_functions_def"
	"github.com/weka/go-cloud-lib/clusterize"
	cloudCommon "github.com/weka/go-cloud-lib/common"
	"github.com/weka/go-cloud-lib/protocol"
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

	funcDef := AwsFunctionDef.NewFuncDef()

	ips, err := common.GetBackendsPrivateIps(p.Cluster.ClusterName)

	clusterParams := p.Cluster
	clusterParams.VMNames = instancesNames
	clusterParams.IPs = ips
	clusterParams.DebugOverrideCmds = "echo 'nothing here'"
	clusterParams.WekaPassword = creds.Password
	clusterParams.WekaUsername = creds.Username
	clusterParams.InstallDpdk = true
	clusterParams.FindDrivesScript = common.FindDrivesScript

	scriptGenerator := clusterize.ClusterizeScriptGenerator{
		Params:  clusterParams,
		FuncDef: funcDef,
	}
	clusterizeScript = scriptGenerator.GetClusterizeScript()

	log.Info().Msg("Clusterization script generated")
	return
}
