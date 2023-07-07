package main

import (
	"context"
	"fmt"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/functions/clusterize"
	"github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/functions/clusterize_finalization"
	"github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/functions/deploy"
	clusterizeCommon "github.com/weka/go-cloud-lib/clusterize"
	"github.com/weka/go-cloud-lib/protocol"
	"os"
	"strconv"
)

type Vm struct {
	Vm string `json:"vm"`
}

func clusterizeFinalizationHandler() (string, error) {
	bucket := os.Getenv("BUCKET")
	err := clusterize_finalization.ClusterizeFinalization(bucket)

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
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")
	bucket := os.Getenv("BUCKET")
	// data protection-related vars
	stripeWidth, _ := strconv.Atoi(os.Getenv("STRIPE_WIDTH"))
	protectionLevel, _ := strconv.Atoi(os.Getenv("PROTECTION_LEVEL"))
	hotspare, _ := strconv.Atoi(os.Getenv("HOTSPARE"))
	setObs, _ := strconv.ParseBool(os.Getenv("SET_OBS"))
	obsName := os.Getenv("OBS_NAME")
	tieringSsdPercent := os.Getenv("OBS_TIERING_SSD_PERCENT")
	addFrontendNum, _ := strconv.Atoi(os.Getenv("NUM_FRONTEND_CONTAINERS"))

	addFrontend := false
	if addFrontendNum > 0 {
		addFrontend = true
	}

	if stripeWidth == 0 || protectionLevel == 0 || hotspare == 0 {
		msg := "Failed getting data protection params"
		return msg, fmt.Errorf("%s", msg)
	}

	params := clusterize.ClusterizationParams{
		UsernameId: usernameId,
		PasswordId: passwordId,
		Bucket:     bucket,
		VmName:     vm.Vm,
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
		},
		Obs: protocol.ObsParams{
			Name:              obsName,
			TieringSsdPercent: tieringSsdPercent,
		},
	}

	return clusterize.Clusterize(params), nil
}

func deployHandler(ctx context.Context, vm Vm) (string, error) {
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")
	tokenId := os.Getenv("TOKEN_ID")
	bucket := os.Getenv("BUCKET")
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
		bucket,
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

func main() {
	switch lambdaType := os.Getenv("LAMBDA"); lambdaType {
	case "deploy":
		lambda.Start(deployHandler)
	case "clusterize":
		lambda.Start(clusterizeHandler)
	case "clusterizeFinalization":
		lambda.Start(clusterizeFinalizationHandler)
	default:
		lambda.Start(func() error { return fmt.Errorf("unsupported lambda command") })
	}
}
