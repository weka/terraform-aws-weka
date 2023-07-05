package cloud_functions

import (
	"encoding/json"
	"fmt"
	"github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/functions/clusterize"
	"github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/functions/clusterize_finalization"
	"github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/functions/deploy"
	clusterizeCommon "github.com/weka/go-cloud-lib/clusterize"
	"net/http"
	"os"
	"strconv"
)

func ClusterizeFinalization(w http.ResponseWriter, r *http.Request) {
	region := os.Getenv("REGION")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	bucket := os.Getenv("BUCKET")

	ctx := r.Context()
	err := clusterize_finalization.ClusterizeFinalization(ctx, region, instanceGroup, bucket)

	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, "ClusterizeFinalization completed successfully")
	}
}

func Clusterize(w http.ResponseWriter, r *http.Request) {
	region := os.Getenv("REGION")
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
		fmt.Fprint(w, "Failed getting data protection params")
		return
	}

	var d struct {
		Vm string `json:"vm"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}

	ctx := r.Context()

	params := clusterize.ClusterizationParams{
		Region:     region,
		UsernameId: usernameId,
		PasswordId: passwordId,
		Bucket:     bucket,
		VmName:     d.Vm,
		Cluster: clusterizeCommon.ClusterParams{
			HostsNum:    hostsNum,
			ClusterName: clusterName,
			Prefix:      prefix,
			NvmesNum:    nvmesNum,
			SetObs:      setObs,
			InstallDpdk: installDpdk,
			DataProtection: clusterizeCommon.DataProtectionParams{
				StripeWidth:     stripeWidth,
				ProtectionLevel: protectionLevel,
				Hotspare:        hotspare,
			},
			AddFrontend: addFrontend,
		},
		Obs: common.AwsObsParams{
			Name:              obsName,
			TieringSsdPercent: tieringSsdPercent,
		},
	}
	fmt.Fprint(w, clusterize.Clusterize(ctx, params))
}

func Deploy(w http.ResponseWriter, r *http.Request) {
	region := os.Getenv("REGION")
	asgName := os.Getenv("ASG_NAME")
	role := os.Getenv("ROLE")
	passwordId := os.Getenv("PASSWORD")
	tokenId := os.Getenv("TOKEN")
	bucket := os.Getenv("BUCKET")
	installDpdk, _ := strconv.ParseBool(os.Getenv("INSTALL_DPDK"))
	computeMemory := os.Getenv("COMPUTE_MEMORY")
	computeContainerNum, _ := strconv.Atoi(os.Getenv("NUM_COMPUTE_CONTAINERS"))
	frontendContainerNum, _ := strconv.Atoi(os.Getenv("NUM_FRONTEND_CONTAINERS"))
	driveContainerNum, _ := strconv.Atoi(os.Getenv("NUM_DRIVE_CONTAINERS"))
	installUrl := os.Getenv("INSTALL_URL")
	nics_num, _ := strconv.Atoi(os.Getenv("NICS_NUM"))

	var d struct {
		Vm string `json:"vm"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}

	ctx := r.Context()

	bashScript, err := deploy.GetDeployScript(
		ctx,
		region,
		asgName,
		instanceParams,
		role,
		passwordId,
		tokenId,
		bucket,
		d.Vm,
		nics_num,
		computeMemory,
		installUrl,
		computeContainerNum,
		frontendContainerNum,
		driveContainerNum,
		installDpdk,
	)
	if err != nil {
		_, _ = fmt.Fprintf(w, "%s", err)
		return
	}
	w.Write([]byte(bashScript))
}

func Status(w http.ResponseWriter, r *http.Request) {
	region := os.Getenv("REGION")
	bucket := os.Getenv("BUCKET")
	asgName := os.Getenv("ASG_NAME")
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")

	ctx := r.Context()
	clusterStatus, err := status.GetClusterStatus(ctx, region, bucket, asgName, usernameId, passwordId)
	if err != nil {
		fmt.Fprintf(w, "Failed retrieving status: %s", err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	err = json.NewEncoder(w).Encode(clusterStatus)
	if err != nil {
		fmt.Fprintf(w, "Failed decoding status: %s", err)
	}
}
