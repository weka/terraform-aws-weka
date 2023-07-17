package main

import (
	"context"
	"fmt"
	"github.com/aws/aws-sdk-go/aws"
	lambda2 "github.com/aws/aws-sdk-go/service/lambda"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/connectors"
	"os"
	"strconv"

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
	addFrontendNum, _ := strconv.Atoi(os.Getenv("NUM_FRONTEND_CONTAINERS"))
	proxyUrl := os.Getenv("PROXY_URL")

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
			HostsNum:    hostsNum,
			ClusterName: clusterName,
			Prefix:      prefix,
			NvmesNum:    nvmesNum,
			SetObs:      setObs,
			InstallDpdk: true,
			DataProtection: clusterizeCommon.DataProtectionParams{
				StripeWidth:     stripeWidth,
				ProtectionLevel: protectionLevel,
				Hotspare:        hotspare,
			},
			AddFrontend: addFrontend,
			ProxyUrl:    proxyUrl,
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
	computeContainerNum, _ := strconv.Atoi(os.Getenv("NUM_COMPUTE_CONTAINERS"))
	frontendContainerNum, _ := strconv.Atoi(os.Getenv("NUM_FRONTEND_CONTAINERS"))
	driveContainerNum, _ := strconv.Atoi(os.Getenv("NUM_DRIVE_CONTAINERS"))
	installUrl := os.Getenv("INSTALL_URL")
	nicsNumStr := os.Getenv("NICS_NUM")

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
	log.Info().Msg("running status handler")
	if req.Type == "status" {
		log.Info().Msg("Getting weka status from lambda")
		svc := connectors.GetAWSSession().Lambda
		res, err2 := svc.Invoke(&lambda2.InvokeInput{
			FunctionName: aws.String("weka-tf-test-weka-status-lambda"),
		},
		)
		err = err2
		clusterStatus = res.Payload
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

func wekaStatusHandler(ctx context.Context) (clusterStatus protocol.ClusterStatus, err error) {
	stateTable := os.Getenv("STATE_TABLE")
	stateTableHashKey := os.Getenv("STATE_TABLE_HASH_KEY")
	clusterName := os.Getenv("CLUSTER_NAME")
	usernameId := os.Getenv("USERNAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")

	clusterStatus, err = status.GetClusterStatus(ctx, stateTable, stateTableHashKey, clusterName, usernameId, passwordId)

	return
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
	case "wekaStatus":
		lambda.Start(wekaStatusHandler)
	default:
		lambda.Start(func() error { return fmt.Errorf("unsupported lambda command") })
	}
}
