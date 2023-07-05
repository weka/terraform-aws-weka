package clusterize

import (
	"context"
	"fmt"
	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/functions/aws_functions_def"
	"github.com/weka/go-cloud-lib/clusterize"
	"strings"
)

type ClusterizationParams struct {
	Region     string
	UsernameId string
	PasswordId string
	Bucket     string
	VmName     string
	Cluster    clusterize.ClusterParams
	Obs        common.AwsObsParams
}

func GetErrorScript(err error) string {
	s := `
	#!/bin/bash
	<<'###ERROR'
	%s
	###ERROR
	exit 1
	`
	return fmt.Sprintf(dedent.Dedent(s), err.Error())
}

func Clusterize(ctx context.Context, p ClusterizationParams) (clusterizeScript string) {
	instancesNames, err := common.AddInstanceToStateInstances(ctx, p.Bucket, p.VmName)
	if err != nil {
		clusterizeScript = GetErrorScript(err)
		return
	}

	err = common.SetDeletionProtection(ctx, p.Region, p.VmName)
	if err != nil {
		clusterizeScript = GetErrorScript(err)
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

	if p.Cluster.SetObs {
		if p.Obs.Name == "" {
			bucketName := strings.Join([]string{p.Region, p.Cluster.Prefix, p.Cluster.ClusterName, "obs"}, "-")
			err = common.CreateBucket(ctx, p.Region, bucketName)
			if err != nil {
				clusterizeScript = GetErrorScript(err)
				return
			}
			p.Obs.Name = bucketName
		} else {
			log.Info().Msgf("Using existing obs bucket %s", p.Obs.Name)
		}
	}

	creds, err := common.GetUsernameAndPassword(ctx, p.UsernameId, p.PasswordId)
	if err != nil {
		log.Error().Msgf("%s", err)
		clusterizeScript = GetErrorScript(err)
		return
	}
	log.Info().Msgf("Fetched weka cluster creds successfully")

	funcDef := gcp_functions_def.NewFuncDef()

	ips := common.GetBackendsIps(ctx, p.Region, instancesNames)

	clusterParams := p.Cluster
	clusterParams.VMNames = instancesNames
	clusterParams.IPs = ips
	clusterParams.DebugOverrideCmds = "echo 'nothing here'"
	clusterParams.ObsScript = GetObsScript(p.Obs)
	clusterParams.WekaPassword = creds.Password
	clusterParams.WekaUsername = creds.Username
	clusterParams.InstallDpdk = true

	scriptGenerator := clusterize.ClusterizeScriptGenerator{
		Params:  clusterParams,
		FuncDef: funcDef,
	}
	clusterizeScript = scriptGenerator.GetClusterizeScript()

	log.Info().Msg("Clusterization script generated")
	return
}

func GetObsScript(obsParams common.AwsObsParams) string {
	template := `
	OBS_TIERING_SSD_PERCENT=%s
	OBS_NAME="%s"

	weka fs tier s3 add gcp-bucket --hostname storage.googleapis.com --port 443 --bucket "$OBS_NAME" --protocol https --auth-method AWSSignature4
	weka fs tier s3 attach default gcp-bucket
	tiering_percent=$(echo "$full_capacity * 100 / $OBS_TIERING_SSD_PERCENT" | bc)
	weka fs update default --total-capacity "$tiering_percent"B
	`
	return fmt.Sprintf(
		dedent.Dedent(template), obsParams.TieringSsdPercent, obsParams.Name,
	)
}
