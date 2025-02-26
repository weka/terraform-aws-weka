package main

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/connectors"
	lambdas "github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/fetch"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/terminate"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/management"
	"github.com/weka/go-cloud-lib/logging"
	"github.com/weka/go-cloud-lib/scale_down"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/clusterize"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/clusterize_finalization"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/deploy"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/report"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/status"
	clusterizeCommon "github.com/weka/go-cloud-lib/clusterize"
	strings2 "github.com/weka/go-cloud-lib/lib/strings"
	"github.com/weka/go-cloud-lib/protocol"
)

type StatusRequest struct {
	Type     string              `json:"type"`
	Protocol protocol.ProtocolGW `json:"protocol"`
}

type Protocol struct {
	Protocol protocol.ProtocolGW `json:"protocol"`
}

type vmName struct {
	Name string `json:"name"`
}

func clusterizeFinalizationHandler(ctx context.Context, VmProtocol Protocol) (string, error) {
	logger := logging.LoggerFromCtx(ctx)

	stateTable := os.Getenv("STATE_TABLE")
	stateTableHashKey := os.Getenv("STATE_TABLE_HASH_KEY")
	var stateKey string
	svc := connectors.GetAWSSession().EC2

	if VmProtocol.Protocol == protocol.NFS {
		stateKey = os.Getenv("NFS_STATE_KEY")

		state, err := common.GetClusterStateWithoutLock(stateTable, stateTableHashKey, stateKey)
		if err != nil {
			logger.Error().Err(err).Send()
			return err.Error(), err
		}
		var instanceIds []*string
		for i := range state.Instances {
			instanceIds = append(instanceIds, &state.Instances[i].Name)
		}
		logger.Info().Msgf("Adding tag %s to instances %v", common.NfsInterfaceGroupPortKey, strings2.RefListToList(instanceIds))
		_, err = svc.CreateTags(&ec2.CreateTagsInput{
			Resources: instanceIds,
			Tags: []*ec2.Tag{
				{
					Key:   aws.String(common.NfsInterfaceGroupPortKey),
					Value: aws.String(common.NfsInterfaceGroupPortValue),
				},
			},
		})
		if err != nil {
			logger.Error().Err(err).Send()
			return err.Error(), err
		}
	} else {
		stateKey = os.Getenv("STATE_KEY")
	}

	err := clusterize_finalization.ClusterizeFinalization(stateTable, stateTableHashKey, stateKey)

	if err != nil {
		logger.Error().Err(err).Send()
		return err.Error(), err
	} else {
		return "ClusterizeFinalization completed successfully", nil
	}
}

func joinNfsFinalizationHandler(ctx context.Context, vm vmName) (string, error) {
	logger := logging.LoggerFromCtx(ctx)
	svc := connectors.GetAWSSession().EC2
	logger.Info().Msgf("Adding tag %s to instance %s", common.NfsInterfaceGroupPortKey, vm.Name)
	_, err := svc.CreateTags(&ec2.CreateTagsInput{
		Resources: []*string{aws.String(vm.Name)},
		Tags: []*ec2.Tag{
			{
				Key:   aws.String(common.NfsInterfaceGroupPortKey),
				Value: aws.String(common.NfsInterfaceGroupPortValue),
			},
		},
	})

	if err != nil {
		logger.Error().Err(err).Send()
		return err.Error(), err
	} else {
		return "JoinFinalizationFinalization completed successfully", nil
	}
}

func clusterizeHandler(ctx context.Context, vm protocol.Vm) (string, error) {
	hostsNum, _ := strconv.Atoi(os.Getenv("HOSTS_NUM"))
	clusterName := os.Getenv("CLUSTER_NAME")
	prefix := os.Getenv("PREFIX")
	adminPasswordId := os.Getenv("ADMIN_PASSWORD_ID")
	deploymentPasswordId := os.Getenv("DEPLOYMENT_PASSWORD_ID")
	stateTable := os.Getenv("STATE_TABLE")
	stateTableHashKey := os.Getenv("STATE_TABLE_HASH_KEY")
	stateKey := os.Getenv("STATE_KEY")
	nfsStateKey := os.Getenv("NFS_STATE_KEY")
	// data protection-related vars
	stripeWidth, _ := strconv.Atoi(os.Getenv("STRIPE_WIDTH"))
	protectionLevel, _ := strconv.Atoi(os.Getenv("PROTECTION_LEVEL"))
	hotspare, _ := strconv.Atoi(os.Getenv("HOTSPARE"))
	setObs, _ := strconv.ParseBool(os.Getenv("SET_OBS"))
	obsName := os.Getenv("OBS_NAME")
	tieringSsdPercent := os.Getenv("OBS_TIERING_SSD_PERCENT")
	tieringTargetSsdRetention, _ := strconv.Atoi(os.Getenv("TIERING_TARGET_SSD_RETENTION"))
	tieringStartDemote, _ := strconv.Atoi(os.Getenv("TIERING_START_DEMOTE"))
	addFrontendNum, _ := strconv.Atoi(os.Getenv("FRONTEND_CONTAINER_CORES_NUM"))
	proxyUrl := os.Getenv("PROXY_URL")
	wekaHomeUrl := os.Getenv("WEKA_HOME_URL")
	interfaceGroupName := os.Getenv("NFS_INTERFACE_GROUP_NAME")
	nfsProtocolgwsNum, _ := strconv.Atoi(os.Getenv("NFS_PROTOCOL_GATEWAYS_NUM"))
	albArnSuffix := os.Getenv("ALB_ARN_SUFFIX")
	installDpdk, _ := strconv.ParseBool(os.Getenv("INSTALL_DPDK"))
	setDefaultFs, _ := strconv.ParseBool(os.Getenv("SET_DEFAULT_FS"))
	postClusterSetupScript := os.Getenv("POST_CLUSTER_SETUP_SCRIPT")

	addFrontend := false
	if addFrontendNum > 0 {
		addFrontend = true
	}

	if stripeWidth == 0 || protectionLevel == 0 || hotspare == 0 {
		msg := "Failed getting data protection params"
		return msg, fmt.Errorf("%s", msg)
	}

	params := clusterize.ClusterizationParams{
		AdminPasswordId:      adminPasswordId,
		DeploymentPasswordId: deploymentPasswordId,
		StateTable:           stateTable,
		StateTableHashKey:    stateTableHashKey,
		StateKey:             stateKey,
		NfsStateKey:          nfsStateKey,
		Vm:                   vm,
		Cluster: clusterizeCommon.ClusterParams{
			ClusterizationTarget: hostsNum,
			ClusterName:          clusterName,
			Prefix:               prefix,
			SetObs:               setObs,
			InstallDpdk:          installDpdk,
			DataProtection: clusterizeCommon.DataProtectionParams{
				StripeWidth:     stripeWidth,
				ProtectionLevel: protectionLevel,
				Hotspare:        hotspare,
			},
			AddFrontend:               addFrontend,
			ProxyUrl:                  proxyUrl,
			WekaHomeUrl:               wekaHomeUrl,
			TieringTargetSSDRetention: tieringTargetSsdRetention,
			TieringStartDemote:        tieringStartDemote,
			SetDefaultFs:              setDefaultFs,
			PostClusterSetupScript:    postClusterSetupScript,
		},
		Obs: protocol.ObsParams{
			Name:              obsName,
			TieringSsdPercent: tieringSsdPercent,
		},
		NFSParams: protocol.NFSParams{
			InterfaceGroupName: interfaceGroupName,
			HostsNum:           nfsProtocolgwsNum,
		},
		AlbArnSuffix: albArnSuffix,
	}

	return clusterize.Clusterize(params)
}

func deployHandler(ctx context.Context, vm protocol.Vm) (string, error) {
	tokenId := os.Getenv("TOKEN_ID")
	stateTable := os.Getenv("STATE_TABLE")
	stateTableHashKey := os.Getenv("STATE_TABLE_HASH_KEY")
	stateKey := os.Getenv("STATE_KEY")
	nfsStateKey := os.Getenv("NFS_STATE_KEY")
	clusterName := os.Getenv("CLUSTER_NAME")
	computeMemory := os.Getenv("COMPUTE_MEMORY")
	computeContainerNum, _ := strconv.Atoi(os.Getenv("COMPUTE_CONTAINER_CORES_NUM"))
	frontendContainerNum, _ := strconv.Atoi(os.Getenv("FRONTEND_CONTAINER_CORES_NUM"))
	driveContainerNum, _ := strconv.Atoi(os.Getenv("DRIVE_CONTAINER_CORES_NUM"))
	installUrl := os.Getenv("INSTALL_URL")
	nicsNumStr := os.Getenv("NICS_NUM")
	proxyUrl := os.Getenv("PROXY_URL")
	nfsInterfaceGroupName := os.Getenv("NFS_INTERFACE_GROUP_NAME")
	nfsSecondaryIpsNum, _ := strconv.Atoi(os.Getenv("NFS_SECONDARY_IPS_NUM"))
	nfsProtocolGatewayFeCoresNum, _ := strconv.Atoi(os.Getenv("NFS_PROTOCOL_GATEWAY_FE_CORES_NUM"))
	smbProtocolGatewayFeCoresNum, _ := strconv.Atoi(os.Getenv("SMB_PROTOCOL_GATEWAY_FE_CORES_NUM"))
	s3ProtocolGatewayFeCoresNum, _ := strconv.Atoi(os.Getenv("S3_PROTOCOL_GATEWAY_FE_CORES_NUM"))
	albArnSuffix := os.Getenv("ALB_ARN_SUFFIX")
	installDpdk, _ := strconv.ParseBool(os.Getenv("INSTALL_DPDK"))
	nvmesNum, _ := strconv.Atoi(os.Getenv("NVMES_NUM"))

	msg := fmt.Sprintf("generating deploy script for vm: %s", vm.Name)
	if vm.Protocol != "" {
		msg += fmt.Sprintf(", protocol: %s", vm.Protocol)
	}
	log.Info().Msg(msg)

	awsDeploymentParams := deploy.AWSDeploymentParams{
		Ctx:                          ctx,
		TokenId:                      tokenId,
		ClusterName:                  clusterName,
		StateTable:                   stateTable,
		StateTableHashKey:            stateTableHashKey,
		StateKey:                     stateKey,
		NfsStateKey:                  nfsStateKey,
		InstanceName:                 vm.Name,
		NicsNumStr:                   nicsNumStr,
		ComputeMemory:                computeMemory,
		ProxyUrl:                     proxyUrl,
		InstallUrl:                   installUrl,
		InstallDpdk:                  installDpdk,
		ComputeContainerNum:          computeContainerNum,
		FrontendContainerNum:         frontendContainerNum,
		DriveContainerNum:            driveContainerNum,
		NFSInterfaceGroupName:        nfsInterfaceGroupName,
		NFSSecondaryIpsNum:           nfsSecondaryIpsNum,
		NFSProtocolGatewayFeCoresNum: nfsProtocolGatewayFeCoresNum,
		SMBProtocolGatewayFeCoresNum: smbProtocolGatewayFeCoresNum,
		S3ProtocolGatewayFeCoresNum:  s3ProtocolGatewayFeCoresNum,
		AlbArnSuffix:                 albArnSuffix,
		NvmesNum:                     nvmesNum,
	}

	if vm.Protocol == protocol.NFS {
		return deploy.GetNfsDeployScript(awsDeploymentParams)
	} else if vm.Protocol == protocol.SMB || vm.Protocol == protocol.SMBW || vm.Protocol == protocol.S3 {
		return deploy.GetSmbAndS3DeployScript(awsDeploymentParams, vm.Protocol)
	} else if vm.Protocol == protocol.DATA {
		return deploy.GetDataServicesDeployScript(awsDeploymentParams)
	}
	return deploy.GetDeployScript(awsDeploymentParams)
}

func reportHandler(ctx context.Context, currentReport protocol.Report) (string, error) {
	stateTable := os.Getenv("STATE_TABLE")
	stateTableHashKey := os.Getenv("STATE_TABLE_HASH_KEY")
	stateKey := os.Getenv("STATE_KEY")
	if currentReport.Protocol == protocol.NFS {
		stateKey = os.Getenv("NFS_STATE_KEY")
	}

	err := report.Report(currentReport, stateTable, stateTableHashKey, stateKey)
	if err != nil {
		log.Error().Err(err).Send()
		return "Failed adding report to state table", err
	}

	log.Info().Msg("The report was added successfully")
	return "The report was added successfully", nil
}

func statusHandler(ctx context.Context, req StatusRequest) (interface{}, error) {
	stateTable := os.Getenv("STATE_TABLE")
	stateTableHashKey := os.Getenv("STATE_TABLE_HASH_KEY")
	stateKey := os.Getenv("STATE_KEY")
	hostGroup := "backend"
	if req.Protocol == protocol.NFS {
		stateKey = os.Getenv("NFS_STATE_KEY")
		hostGroup = "gateways-protocol"
	} else if req.Protocol != "" {
		return "", fmt.Errorf("unsupported protocol: %s", req.Protocol)
	}

	clusterName := os.Getenv("CLUSTER_NAME")

	var clusterStatus interface{}
	var err error
	if req.Type == "status" {
		clusterStatus, err = getClusterStatus(ctx, stateTable, stateTableHashKey, stateKey)
	} else if req.Type == "progress" {
		clusterStatus, err = status.GetReports(ctx, stateTable, stateTableHashKey, stateKey, clusterName, hostGroup)
	} else {
		clusterStatus = "Invalid status type"
	}

	if err != nil {
		log.Error().Err(err).Send()
		return "Failed retrieving status: %s", err
	}

	return clusterStatus, nil
}

func getClusterStatus(ctx context.Context, stateTable, stateTableHashKey, stateKey string) (protocol.ClusterStatus, error) {
	clusterStatus, err := status.GetClusterStatus(ctx, stateTable, stateTableHashKey, stateKey)
	if err != nil {
		return protocol.ClusterStatus{}, fmt.Errorf("getClusterStatus > %w", err)
	}

	if !clusterStatus.Clusterized {
		log.Info().Msg("Cluster is not yet clusterized, skipping status retrieval")
		return clusterStatus, nil
	}

	clusterName := os.Getenv("CLUSTER_NAME")
	if clusterName == "" {
		return protocol.ClusterStatus{}, fmt.Errorf("CLUSTER_NAME is not set")
	}
	ips, err := common.GetBackendsPrivateIps(clusterName, "backend")
	if err != nil {
		return protocol.ClusterStatus{}, fmt.Errorf("getClusterStatus > GetBackendsPrivateIps: %w", err)
	}
	log.Info().Msgf("GetClusterStatus > Backend private IPs: %v", ips)

	managementLambdaName := os.Getenv("MANAGEMENT_LAMBDA")
	if managementLambdaName == "" {
		return protocol.ClusterStatus{}, fmt.Errorf("MANAGEMENT_LAMBDA is not set")
	}

	useSecretManagerEndpoint, err := strconv.ParseBool(os.Getenv("USE_SECRETMANAGER_ENDPOINT"))
	if err != nil {
		log.Warn().Msg("Failed to parse USE_SECRETMANAGER_ENDPOINT, assuming false")
	}
	var username, password string
	if !useSecretManagerEndpoint {
		log.Info().Msg("Secret manager endpoint not in use, sending credentials in body")
		usernameId := os.Getenv("USERNAME_ID")
		deploymentPasswordId := os.Getenv("DEPLOYMENT_PASSWORD_ID")
		adminPasswordId := os.Getenv("ADMIN_PASSWORD_ID")
		creds, err := common.GetDeploymentOrAdminUsernameAndPassword(usernameId, deploymentPasswordId, adminPasswordId)
		if err != nil {
			return protocol.ClusterStatus{}, fmt.Errorf("getClusterStatus > GetDeploymentOrAdminUsernameAndPassword: %w", err)
		}

		username = creds.Username
		password = creds.Password
	}

	managementRequest := management.ManagementRequest{
		Type: "status",
		WekaStatusRequest: management.WekaStatusRequest{
			BackendPrivateIps: ips,
			Username:          username,
			Password:          password, // empty string is interpreted as no credentials
		},
	}
	var wekaStatus *protocol.WekaStatus
	wekaStatus, err = common.InvokeLambdaFunction[protocol.WekaStatus](managementLambdaName, managementRequest)
	if err != nil {
		wrappedError := fmt.Errorf("getClusterStatus > InvokeLambdaFunction: %w", err)
		log.Error().Err(wrappedError).Send()
		wekaStatus = &protocol.WekaStatus{}
	}
	clusterStatus.WekaStatus = *wekaStatus

	return clusterStatus, nil
}

func fetchHandler(request protocol.FetchRequest) (protocol.HostGroupInfoResponse, error) {
	useSecretManagerEndpoint, err := strconv.ParseBool(os.Getenv("USE_SECRETMANAGER_ENDPOINT"))
	if err != nil {
		return protocol.HostGroupInfoResponse{}, err
	}
	fetchWekaCredentials := !useSecretManagerEndpoint || request.FetchWekaCredentials
	downBackendsRemovalTimeout, _ := time.ParseDuration(os.Getenv("DOWN_BACKENDS_REMOVAL_TIMEOUT"))

	log.Info().Msgf("fetching data, request: %+v", request)

	input := lambdas.FetchInput{
		ClusterName:                os.Getenv("CLUSTER_NAME"),
		WekaBackendsAsgName:        os.Getenv("ASG_NAME"),
		NfsAsgName:                 os.Getenv("NFS_ASG_NAME"),
		DeploymentUsernameId:       os.Getenv("USERNAME_ID"),
		DeploymentPasswordId:       os.Getenv("DEPLOYMENT_PASSWORD_ID"),
		AdminPasswordId:            os.Getenv("ADMIN_PASSWORD_ID"),
		Role:                       os.Getenv("ROLE"),
		DownBackendsRemovalTimeout: downBackendsRemovalTimeout,
		FetchWekaCredentials:       fetchWekaCredentials,
		ShowAdminPassword:          request.ShowAdminPassword,
	}

	result, err := lambdas.FetchHostGroupInfo(input)
	if err != nil {
		return protocol.HostGroupInfoResponse{}, err
	}
	return result, nil
}

func transientHandler(terminateResponse protocol.TerminatedInstancesResponse) error {
	errs := terminateResponse.TransientErrors
	if len(errs) > 0 {
		return fmt.Errorf("the following errors were found:\n%s", strings.Join(errs, "\n"))
	}
	return nil
}

func scaleDownHandler(ctx context.Context, info protocol.HostGroupInfoResponse) (protocol.ScaleResponse, error) {
	if info.Password == "" {
		usernameId := os.Getenv("USERNAME_ID")
		deploymentPasswordId := os.Getenv("DEPLOYMENT_PASSWORD_ID")
		adminPasswordId := os.Getenv("ADMIN_PASSWORD_ID")
		creds, err := common.GetDeploymentOrAdminUsernameAndPassword(usernameId, deploymentPasswordId, adminPasswordId)
		if err != nil {
			return protocol.ScaleResponse{}, err
		}
		info.Username = creds.Username
		info.Password = creds.Password
	}

	return scale_down.ScaleDown(ctx, info)
}

func managementHandler(ctx context.Context, req management.ManagementRequest) (protocol.WekaStatus, error) {
	switch req.Type {
	case "status":
		useSecretManagerEndpoint, err := strconv.ParseBool(os.Getenv("USE_SECRETMANAGER_ENDPOINT"))
		if err != nil {
			log.Warn().Msg("Failed to parse USE_SECRETMANAGER_ENDPOINT, assuming false")
		}
		if useSecretManagerEndpoint && req.Password == "" {
			usernameId := os.Getenv("USERNAME_ID")
			deploymentPasswordId := os.Getenv("DEPLOYMENT_PASSWORD_ID")
			adminPasswordId := os.Getenv("ADMIN_PASSWORD_ID")
			creds, err := common.GetDeploymentOrAdminUsernameAndPassword(usernameId, deploymentPasswordId, adminPasswordId)
			if err != nil {
				log.Error().Err(err).Send()
				return protocol.WekaStatus{}, err
			}
			req.Username = creds.Username
			req.Password = creds.Password
		}
		return management.GetWekaStatus(ctx, req.WekaStatusRequest)
	default:
		log.Error().Msgf("Invalid management type: %s", req.Type)
		return protocol.WekaStatus{}, fmt.Errorf("invalid management type: %s", req.Type)
	}
}

func main() {
	switch lambdaType := os.Getenv("LAMBDA"); lambdaType {
	case "deploy":
		lambda.Start(deployHandler)
	case "clusterize":
		lambda.Start(clusterizeHandler)
	case "clusterizeFinalization":
		lambda.Start(clusterizeFinalizationHandler)
	case "joinNfsFinalization":
		lambda.Start(joinNfsFinalizationHandler)
	case "report":
		lambda.Start(reportHandler)
	case "status":
		lambda.Start(statusHandler)
	case "fetch":
		lambda.Start(fetchHandler)
	case "scaleDown":
		lambda.Start(scaleDownHandler)
	case "terminate":
		lambda.Start(terminate.Handler)
	case "transient":
		lambda.Start(transientHandler)
	case "management":
		lambda.Start(managementHandler)
	default:
		lambda.Start(func() error { return fmt.Errorf("unsupported lambda command") })
	}
}
