package deploy

import (
	"context"
	"fmt"
	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/bash_functions"
	"github.com/weka/go-cloud-lib/deploy"
	"github.com/weka/go-cloud-lib/join"
	"github.com/weka/go-cloud-lib/protocol"
)

func getGCPInstanceNameCmd() string {
	return "echo $HOSTNAME"
}

func getWekaIoToken(ctx context.Context, tokenId, region string) (token string, err error) {
	return
}

func GetDeployScript(
	ctx context.Context,
	region,
	asgName,
	usernameId,
	passwordId,
	tokenId,
	bucket,
	instanceName,
	computeMemory,
	installUrl string,
	installDpdk bool,
	nicsNum,
	computeContainerNum,
	frontendContainerNum,
	driveContainerNum int,
	gateways []string,
) (bashScript string, err error) {
	state, err := common.GetClusterState(ctx, bucket)
	if err != nil {
		return
	}
	funcDef := aws_functions_def.NewFuncDef()
	// used for getting failure domain
	getHashedIpCommand := bash_functions.GetHashedPrivateIpBashCmd()
	instanceParams := protocol.BackendCoreCount{Compute: computeContainerNum, Frontend: frontendContainerNum, Drive: driveContainerNum, ComputeMemory: computeMemory}

	if !state.Clusterized {
		var token string
		token, err = getWekaIoToken(ctx, tokenId, region)
		if err != nil {
			return
		}

		deploymentParams := deploy.DeploymentParams{
			VMName:         instanceName,
			WekaInstallUrl: installUrl,
			WekaToken:      token,
			NicsNum:        nicsNum,
			InstallDpdk:    installDpdk,
			Gateways:       gateways,
		}
		deployScriptGenerator := deploy.DeployScriptGenerator{
			FuncDef:          funcDef,
			Params:           deploymentParams,
			FailureDomainCmd: getHashedIpCommand,
		}
		bashScript = deployScriptGenerator.GetDeployScript()
	} else {
		creds, err := common.GetUsernameAndPassword(ctx, usernameId, passwordId)
		if err != nil {
			log.Error().Msgf("Error while getting weka creds: %v", err)
			return "", err
		}

		instanceNames := common.GetInstanceGroupInstanceNames(ctx, region, instanceGroup)
		instances, err := common.GetInstances(ctx, region, instanceNames)
		if err != nil {
			return "", err
		}

		var ips []string
		for _, instance := range instances {
			ips = append(ips, *instance.NetworkInterfaces[0].NetworkIP)
		}
		if len(ips) == 0 {
			err = fmt.Errorf("no instances found for instance group %s, can't join", instanceGroup)
			return "", err
		}

		if err != nil {
			log.Error().Err(err).Send()
			return "", err
		}

		joinParams := join.JoinParams{
			WekaUsername:   creds.Username,
			WekaPassword:   creds.Password,
			IPs:            ips,
			InstallDpdk:    installDpdk,
			InstanceParams: instanceParams,
			Gateways:       gateways,
		}

		scriptBase := `
		#!/bin/bash
		set -ex
		`

		findDrivesScript := `
		import json
		import sys
		for d in json.load(sys.stdin)['disks']:
			if d['isRotational']: continue
			if d['type'] != 'DISK': continue
			if d['isMounted']: continue
			if d['model'] != 'nvme_card': continue
			print(d['devPath'])
		`
		joinScriptGenerator := join.JoinScriptGenerator{
			FailureDomainCmd:   getHashedIpCommand,
			GetInstanceNameCmd: getGCPInstanceNameCmd(),
			FindDrivesScript:   dedent.Dedent(findDrivesScript),
			ScriptBase:         dedent.Dedent(scriptBase),
			Params:             joinParams,
			FuncDef:            funcDef,
		}
		bashScript = joinScriptGenerator.GetJoinScript(ctx)
	}
	bashScript = dedent.Dedent(bashScript)
	return
}
