package main

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	lambdas "github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/fetch"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/terminate"
	"github.com/weka/go-cloud-lib/scale_down"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/clusterize"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/clusterize_finalization"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/deploy"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/report"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/status"
	clusterizeCommon "github.com/weka/go-cloud-lib/clusterize"
	"github.com/weka/go-cloud-lib/protocol"
)

type Vm struct {
	Vm string `json:"vm"`
}

type StatusRequest struct {
	Type string `json:"type"`
}

func clusterizeFinalizationHandler() (string, error) {
	stateTable := os.Getenv("STATE_TABLE")
	stateTableHashKey := os.Getenv("STATE_TABLE_HASH_KEY")
	err := clusterize_finalization.ClusterizeFinalization(stateTable, stateTableHashKey)

	if err != nil {
		return err.Error(), err
	} else {
		return "ClusterizeFinalization completed successfully", nil
	}
}

func clusterizeHandler(ctx context.Context, vm Vm) (string, error) {
	hostsNum, _ := strconv.Atoi(os.Getenv("HOSTS_NUM"))
	clusterName := os.Getenv("CLUSTER_NAME")
	prefix := os.Getenv("PREFIX")
	nvmesNum, _ := strconv.Atoi(os.Getenv("NVMES_NUM"))
	usernameId := os.Getenv("USERNAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")
	stateTable := os.Getenv("STATE_TABLE")
	stateTableHashKey := os.Getenv("STATE_TABLE_HASH_KEY")
	// data protection-related vars
	stripeWidth, _ := strconv.Atoi(os.Getenv("STRIPE_WIDTH"))
	protectionLevel, _ := strconv.Atoi(os.Getenv("PROTECTION_LEVEL"))
	hotspare, _ := strconv.Atoi(os.Getenv("HOTSPARE"))
	setObs, _ := strconv.ParseBool(os.Getenv("SET_OBS"))
	obsName := os.Getenv("OBS_NAME")
	tieringSsdPercent := os.Getenv("OBS_TIERING_SSD_PERCENT")
	addFrontendNum, _ := strconv.Atoi(os.Getenv("FRONTEND_CONTAINER_CORES_NUM"))
	proxyUrl := os.Getenv("PROXY_URL")
	smbwEnabled, _ := strconv.ParseBool(os.Getenv("SMBW_ENABLED"))
	wekaHomeUrl := os.Getenv("WEKA_HOME_URL")

	addFrontend := false
	if addFrontendNum > 0 {
		addFrontend = true
	}

	if stripeWidth == 0 || protectionLevel == 0 || hotspare == 0 {
		msg := "Failed getting data protection params"
		return msg, fmt.Errorf("%s", msg)
	}

	params := clusterize.ClusterizationParams{
		UsernameId:        usernameId,
		PasswordId:        passwordId,
		StateTable:        stateTable,
		StateTableHashKey: stateTableHashKey,
		VmName:            vm.Vm,
		Cluster: clusterizeCommon.ClusterParams{
			ClusterizationTarget: hostsNum,
			ClusterName:          clusterName,
			Prefix:               prefix,
			NvmesNum:             nvmesNum,
			SetObs:               setObs,
			InstallDpdk:          true,
			SmbwEnabled:          smbwEnabled,
			DataProtection: clusterizeCommon.DataProtectionParams{
				StripeWidth:     stripeWidth,
				ProtectionLevel: protectionLevel,
				Hotspare:        hotspare,
			},
			AddFrontend: addFrontend,
			ProxyUrl:    proxyUrl,
			WekaHomeUrl: wekaHomeUrl,
		},
		Obs: protocol.ObsParams{
			Name:              obsName,
			TieringSsdPercent: tieringSsdPercent,
		},
	}

	return clusterize.Clusterize(params), nil
}

func deployHandler(ctx context.Context, vm Vm) (string, error) {
	usernameId := os.Getenv("USERNAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")
	tokenId := os.Getenv("TOKEN_ID")
	stateTable := os.Getenv("STATE_TABLE")
	stateTableHashKey := os.Getenv("STATE_TABLE_HASH_KEY")
	clusterName := os.Getenv("CLUSTER_NAME")
	computeMemory := os.Getenv("COMPUTE_MEMORY")
	computeContainerNum, _ := strconv.Atoi(os.Getenv("COMPUTE_CONTAINER_CORES_NUM"))
	frontendContainerNum, _ := strconv.Atoi(os.Getenv("FRONTEND_CONTAINER_CORES_NUM"))
	driveContainerNum, _ := strconv.Atoi(os.Getenv("DRIVE_CONTAINER_CORES_NUM"))
	installUrl := os.Getenv("INSTALL_URL")
	nicsNumStr := os.Getenv("NICS_NUM")
	proxyUrl := os.Getenv("PROXY_URL")

	log.Info().Msgf("generating deploy script for vm: %s", vm.Vm)

	bashScript, err := deploy.GetDeployScript(
		ctx,
		usernameId,
		passwordId,
		tokenId,
		clusterName,
		stateTable,
		stateTableHashKey,
		vm.Vm,
		nicsNumStr,
		computeMemory,
		proxyUrl,
		installUrl,
		computeContainerNum,
		frontendContainerNum,
		driveContainerNum,
	)
	if err != nil {
		return " ", err
	}
	return bashScript, nil
}

func reportHandler(ctx context.Context, currentReport protocol.Report) (string, error) {
	stateTable := os.Getenv("STATE_TABLE")
	stateTableHashKey := os.Getenv("STATE_TABLE_HASH_KEY")

	err := report.Report(currentReport, stateTable, stateTableHashKey)
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
	//clusterName := os.Getenv("CLUSTER_NAME")
	//usernameId := os.Getenv("USERNAME_ID")
	//passwordId := os.Getenv("PASSWORD_ID")

	var clusterStatus interface{}
	var err error
	if req.Type == "status" {
		// clusterStatus, err = status.GetClusterStatus(ctx, bucket, clusterName, usernameId, passwordId)
		clusterStatus = "Not implemented yet"
	} else if req.Type == "progress" {
		clusterStatus, err = status.GetReports(ctx, stateTable, stateTableHashKey)
	} else {
		clusterStatus = "Invalid status type"
	}

	if err != nil {
		return "Failed retrieving status: %s", err
	}

	return clusterStatus, nil
}

func fetchHandler() (protocol.HostGroupInfoResponse, error) {
	useSecretManagerEndpoint, err := strconv.ParseBool(os.Getenv("USE_SECRETMANAGER_ENDPOINT"))
	if err != nil {
		return protocol.HostGroupInfoResponse{}, err
	}
	result, err := lambdas.GetFetchDataParams(
		os.Getenv("CLUSTER_NAME"),
		os.Getenv("ASG_NAME"),
		os.Getenv("USERNAME_ID"),
		os.Getenv("PASSWORD_ID"),
		os.Getenv("ROLE"),
		useSecretManagerEndpoint,
	)
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
		passwordId := os.Getenv("PASSWORD_ID")
		creds, err := common.GetUsernameAndPassword(usernameId, passwordId)
		if err != nil {
			return protocol.ScaleResponse{}, err
		}
		info.Username = creds.Username
		info.Password = creds.Password
	}
	return scale_down.ScaleDown(ctx, info)
}

func main() {
	switch lambdaType := os.Getenv("LAMBDA"); lambdaType {
	case "deploy":
		lambda.Start(deployHandler)
	case "clusterize":
		lambda.Start(clusterizeHandler)
	case "clusterizeFinalization":
		lambda.Start(clusterizeFinalizationHandler)
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
	default:
		lambda.Start(func() error { return fmt.Errorf("unsupported lambda command") })
	}
}
