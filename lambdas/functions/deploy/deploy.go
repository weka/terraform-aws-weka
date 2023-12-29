package deploy

import (
	"context"
	"fmt"
	"strings"

	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/aws_functions_def"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/go-cloud-lib/deploy"
	"github.com/weka/go-cloud-lib/join"
	"github.com/weka/go-cloud-lib/protocol"
)

type AWSDeploymentParams struct {
	Ctx                          context.Context
	UsernameId                   string
	PasswordId                   string
	TokenId                      string
	Prefix                       string
	ClusterName                  string
	StateTable                   string
	StateTableHashKey            string
	InstanceName                 string
	NicsNumStr                   string
	ComputeMemory                string
	ProxyUrl                     string
	InstallUrl                   string
	ComputeContainerNum          int
	FrontendContainerNum         int
	DriveContainerNum            int
	NFSInterfaceGroupName        string
	NFSClientGroupName           string
	NFSSecondaryIpsNum           int
	NFSProtocolGatewayFeCoresNum int
	AlbArnSuffix                 string
}

func getAWSInstanceNameCmd() string {
	return "echo $HOSTNAME"
}

func GetNfsDeployScript(awsDeploymentParams AWSDeploymentParams) (bashScript string, err error) {
	log.Info().Msg("Getting NFS deploy script")
	stateKey := fmt.Sprintf("%s-%s-nfs-state", awsDeploymentParams.Prefix, awsDeploymentParams.ClusterName)
	state, err := common.GetClusterState(awsDeploymentParams.StateTable, awsDeploymentParams.StateTableHashKey, stateKey)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	funcDef := aws_functions_def.NewFuncDef()
	instanceParams := protocol.BackendCoreCount{
		Compute:       awsDeploymentParams.ComputeContainerNum,
		Frontend:      awsDeploymentParams.FrontendContainerNum,
		Drive:         awsDeploymentParams.DriveContainerNum,
		ComputeMemory: awsDeploymentParams.ComputeMemory,
	}

	albIp, err := common.GetALBIp(awsDeploymentParams.AlbArnSuffix)
	if err != nil {
		log.Error().Err(err).Send()
	}

	creds, err := common.GetUsernameAndPassword(awsDeploymentParams.UsernameId, awsDeploymentParams.PasswordId)
	if err != nil {
		log.Error().Msgf("Error while getting weka creds: %v", err)
		return
	}

	var token string
	token, err = common.GetWekaIoToken(awsDeploymentParams.TokenId)
	if err != nil {
		return
	}

	deploymentParams := deploy.DeploymentParams{
		VMName:                       awsDeploymentParams.InstanceName,
		InstanceParams:               instanceParams,
		WekaInstallUrl:               awsDeploymentParams.InstallUrl,
		WekaToken:                    token,
		NicsNum:                      awsDeploymentParams.NicsNumStr,
		InstallDpdk:                  true,
		ProxyUrl:                     awsDeploymentParams.ProxyUrl,
		Protocol:                     protocol.NFS,
		WekaUsername:                 creds.Username,
		WekaPassword:                 creds.Password,
		NFSInterfaceGroupName:        awsDeploymentParams.NFSInterfaceGroupName,
		NFSClientGroupName:           awsDeploymentParams.NFSClientGroupName,
		NFSSecondaryIpsNum:           awsDeploymentParams.NFSSecondaryIpsNum,
		NFSProtocolGatewayFeCoresNum: awsDeploymentParams.NFSProtocolGatewayFeCoresNum,
		LoadBalancerIP:               albIp,
	}

	ebsVolumeId, err := common.GetBackendWekaVolumeId(awsDeploymentParams.InstanceName)
	if err != nil {
		log.Error().Err(err).Send()
		return "", err
	}

	if !state.Clusterized {
		deployScriptGenerator := deploy.DeployScriptGenerator{
			FuncDef:       funcDef,
			Params:        deploymentParams,
			DeviceNameCmd: GetDeviceName(ebsVolumeId),
		}
		bashScript = deployScriptGenerator.GetDeployScript()
	} else {
		joinScriptGenerator := join.JoinNFSScriptGenerator{
			DeviceNameCmd:      GetDeviceName(ebsVolumeId),
			DeploymentParams:   deploymentParams,
			InterfaceGroupName: awsDeploymentParams.NFSInterfaceGroupName,
			FuncDef:            funcDef,
			Name:               awsDeploymentParams.InstanceName,
		}
		bashScript = joinScriptGenerator.GetJoinNFSHostScript()
	}

	return
}

func GetDeployScript(awsDeploymentParams AWSDeploymentParams) (bashScript string, err error) {
	log.Info().Msg("Getting deploy script")
	stateKey := fmt.Sprintf("%s-%s-state", awsDeploymentParams.Prefix, awsDeploymentParams.ClusterName)

	state, err := common.GetClusterState(awsDeploymentParams.StateTable, awsDeploymentParams.StateTableHashKey, stateKey)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	funcDef := aws_functions_def.NewFuncDef()
	instanceParams := protocol.BackendCoreCount{
		Compute:       awsDeploymentParams.ComputeContainerNum,
		Frontend:      awsDeploymentParams.FrontendContainerNum,
		Drive:         awsDeploymentParams.DriveContainerNum,
		ComputeMemory: awsDeploymentParams.ComputeMemory,
	}

	ebsVolumeId, err := common.GetBackendWekaVolumeId(awsDeploymentParams.InstanceName)
	if err != nil {
		log.Error().Err(err).Send()
		return "", err
	}

	if !state.Clusterized {
		var token string
		token, err = common.GetWekaIoToken(awsDeploymentParams.TokenId)
		if err != nil {
			return
		}
		deploymentParams := deploy.DeploymentParams{
			VMName:         awsDeploymentParams.InstanceName,
			InstanceParams: instanceParams,
			WekaInstallUrl: awsDeploymentParams.InstallUrl,
			WekaToken:      token,
			NicsNum:        awsDeploymentParams.NicsNumStr,
			InstallDpdk:    true,
			ProxyUrl:       awsDeploymentParams.ProxyUrl,
		}
		deployScriptGenerator := deploy.DeployScriptGenerator{
			FuncDef:       funcDef,
			Params:        deploymentParams,
			DeviceNameCmd: GetDeviceName(ebsVolumeId),
		}
		bashScript = deployScriptGenerator.GetDeployScript()
	} else {
		creds, err1 := common.GetUsernameAndPassword(awsDeploymentParams.UsernameId, awsDeploymentParams.PasswordId)
		if err1 != nil {
			log.Error().Msgf("Error while getting weka creds: %v", err1)
			err = err1
			return
		}
		ips, err2 := common.GetBackendsPrivateIps(awsDeploymentParams.ClusterName)

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
			ProxyUrl:       awsDeploymentParams.ProxyUrl,
		}

		scriptBase := `
		#!/bin/bash
		set -ex
		`

		findDrivesScript := common.FindDrivesScript
		joinScriptGenerator := join.JoinScriptGenerator{
			DeviceNameCmd:      GetDeviceName(ebsVolumeId),
			GetInstanceNameCmd: getAWSInstanceNameCmd(),
			FindDrivesScript:   dedent.Dedent(findDrivesScript),
			ScriptBase:         dedent.Dedent(scriptBase),
			Params:             joinParams,
			FuncDef:            funcDef,
		}
		bashScript = joinScriptGenerator.GetJoinScript(awsDeploymentParams.Ctx)
	}
	bashScript = dedent.Dedent(bashScript)
	return
}

func GetDeviceName(ebsVolumeId string) string {
	template := "$(ls /dev/xvdp || lsblk --output NAME,SERIAL --path --list --noheadings | grep %s | cut --delimiter ' ' --field 1)"
	return fmt.Sprintf(dedent.Dedent(template), strings.Replace(ebsVolumeId, "-", "", -1))
}
