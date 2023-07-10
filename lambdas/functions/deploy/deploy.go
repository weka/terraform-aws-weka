package deploy

import (
	"context"
	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/aws_functions_def"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/go-cloud-lib/bash_functions"
	"github.com/weka/go-cloud-lib/deploy"
	"github.com/weka/go-cloud-lib/join"
	"github.com/weka/go-cloud-lib/protocol"
)

func getAWSInstanceNameCmd() string {
	return "echo $HOSTNAME"
}

func GetDeployScript(
	ctx context.Context,
	usernameId,
	passwordId,
	tokenId,
	clusterName,
	bucket,
	instanceName,
	nicsNum,
	computeMemory,
	installUrl string,
	computeContainerNum,
	frontendContainerNum,
	driveContainerNum int,
) (bashScript string, err error) {

	log.Info().Msg("Getting deploy script")

	state, err := common.GetClusterState(bucket)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	funcDef := aws_functions_def.NewFuncDef()
	// used for getting failure domain
	getHashedIpCommand := bash_functions.GetHashedPrivateIpBashCmd()
	instanceParams := protocol.BackendCoreCount{Compute: computeContainerNum, Frontend: frontendContainerNum, Drive: driveContainerNum, ComputeMemory: computeMemory}

	if !state.Clusterized {
		var token string
		token, err = common.GetWekaIoToken(tokenId)
		if err != nil {
			return
		}

		deploymentParams := deploy.DeploymentParams{
			VMName:         instanceName,
			InstanceParams: instanceParams,
			WekaInstallUrl: installUrl,
			WekaToken:      token,
			NicsNum:        nicsNum,
			InstallDpdk:    true,
		}
		deployScriptGenerator := deploy.DeployScriptGenerator{
			FuncDef:          funcDef,
			Params:           deploymentParams,
			FailureDomainCmd: getHashedIpCommand,
		}
		bashScript = deployScriptGenerator.GetDeployScript()
	} else {
		creds, err2 := common.GetUsernameAndPassword(usernameId, passwordId)
		if err2 != nil {
			log.Error().Msgf("Error while getting weka creds: %v", err2)
			return "", err2
		}

		ips, err2 := common.GetBackendsPrivateIps(clusterName)

		if err2 != nil {
			log.Error().Err(err2).Send()
			return "", err2
		}

		joinParams := join.JoinParams{
			WekaUsername:   creds.Username,
			WekaPassword:   creds.Password,
			IPs:            ips,
			InstallDpdk:    true,
			InstanceParams: instanceParams,
		}

		scriptBase := `
		#!/bin/bash
		set -ex
		`

		findDrivesScript := common.FindDrivesScript
		joinScriptGenerator := join.JoinScriptGenerator{
			FailureDomainCmd:   getHashedIpCommand,
			GetInstanceNameCmd: getAWSInstanceNameCmd(),
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
