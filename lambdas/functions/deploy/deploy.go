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
	InstallDpdk                  bool
	ComputeContainerNum          int
	FrontendContainerNum         int
	DriveContainerNum            int
	NFSInterfaceGroupName        string
	NFSClientGroupName           string
	NFSSecondaryIpsNum           int
	NFSProtocolGatewayFeCoresNum int
	SMBProtocolGatewayFeCoresNum int
	S3ProtocolGatewayFeCoresNum  int
	AlbArnSuffix                 string
	NvmesNum                     int
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
		VMName:                    awsDeploymentParams.InstanceName,
		InstanceParams:            instanceParams,
		WekaInstallUrl:            awsDeploymentParams.InstallUrl,
		WekaToken:                 token,
		NicsNum:                   awsDeploymentParams.NicsNumStr,
		InstallDpdk:               awsDeploymentParams.InstallDpdk,
		ProxyUrl:                  awsDeploymentParams.ProxyUrl,
		Protocol:                  protocol.NFS,
		WekaUsername:              creds.Username,
		WekaPassword:              creds.Password,
		NFSInterfaceGroupName:     awsDeploymentParams.NFSInterfaceGroupName,
		NFSClientGroupName:        awsDeploymentParams.NFSClientGroupName,
		NFSSecondaryIpsNum:        awsDeploymentParams.NFSSecondaryIpsNum,
		ProtocolGatewayFeCoresNum: awsDeploymentParams.NFSProtocolGatewayFeCoresNum,
		LoadBalancerIP:            albIp,
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

func GetSmbDeployScript(awsDeploymentParams AWSDeploymentParams, protocolGw protocol.ProtocolGW) (bashScript string, err error) {
	log.Info().Msgf("Getting %s deploy script", protocolGw)
	funcDef := aws_functions_def.NewFuncDef()

	albIp, err := common.GetALBIp(awsDeploymentParams.AlbArnSuffix)
	if err != nil {
		log.Error().Err(err).Send()
	}

	var token string
	token, err = common.GetWekaIoToken(awsDeploymentParams.TokenId)
	if err != nil {
		return
	}
	var protocolGatewayFeCoresNum int
	if protocolGw == protocol.SMB || protocolGw == protocol.SMBW {
		protocolGatewayFeCoresNum = awsDeploymentParams.SMBProtocolGatewayFeCoresNum
	} else if protocolGw == protocol.S3 {
		protocolGatewayFeCoresNum = awsDeploymentParams.S3ProtocolGatewayFeCoresNum
	}

	deploymentParams := deploy.DeploymentParams{
		VMName:                    awsDeploymentParams.InstanceName,
		WekaInstallUrl:            awsDeploymentParams.InstallUrl,
		WekaToken:                 token,
		NicsNum:                   awsDeploymentParams.NicsNumStr,
		InstallDpdk:               awsDeploymentParams.InstallDpdk,
		ProxyUrl:                  awsDeploymentParams.ProxyUrl,
		Protocol:                  protocolGw,
		ProtocolGatewayFeCoresNum: protocolGatewayFeCoresNum,
		LoadBalancerIP:            albIp,
	}

	ebsVolumeId, err := common.GetBackendWekaVolumeId(awsDeploymentParams.InstanceName)
	if err != nil {
		log.Error().Err(err).Send()
		return "", err
	}

	deployScriptGenerator := deploy.DeployScriptGenerator{
		FuncDef:       funcDef,
		Params:        deploymentParams,
		DeviceNameCmd: GetDeviceName(ebsVolumeId),
	}
	bashScript = deployScriptGenerator.GetDeployScript()

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
			VMName:           awsDeploymentParams.InstanceName,
			InstanceParams:   instanceParams,
			WekaInstallUrl:   awsDeploymentParams.InstallUrl,
			WekaToken:        token,
			NicsNum:          awsDeploymentParams.NicsNumStr,
			InstallDpdk:      awsDeploymentParams.InstallDpdk,
			ProxyUrl:         awsDeploymentParams.ProxyUrl,
			NvmesNum:         awsDeploymentParams.NvmesNum,
			FindDrivesScript: dedent.Dedent(common.FindDrivesScript),
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
		ips, err2 := common.GetBackendsPrivateIps(awsDeploymentParams.ClusterName, "backend")

		if err2 != nil {
			log.Error().Err(err2).Send()
			return "", err2
		}

		joinParams := join.JoinParams{
			WekaUsername:   creds.Username,
			WekaPassword:   creds.Password,
			IPs:            ips,
			InstallDpdk:    awsDeploymentParams.InstallDpdk,
			InstanceParams: instanceParams,
			ProxyUrl:       awsDeploymentParams.ProxyUrl,
		}

		scriptBase := `
		#!/bin/bash
		set -ex
		`

		joinScriptGenerator := join.JoinScriptGenerator{
			DeviceNameCmd:      GetDeviceName(ebsVolumeId),
			GetInstanceNameCmd: getAWSInstanceNameCmd(),
			FindDrivesScript:   dedent.Dedent(common.FindDrivesScript),
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
