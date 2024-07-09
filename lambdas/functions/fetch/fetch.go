package lambdas

import (
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go/service/autoscaling"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/connectors"
	"github.com/weka/go-cloud-lib/lib/strings"
	"github.com/weka/go-cloud-lib/lib/types"
	"github.com/weka/go-cloud-lib/protocol"
)

type asgInfo struct {
	instances       []protocol.HgInstance
	desiredCapacity int
}

type FetchInput struct {
	ClusterName                string
	WekaBackendsAsgName        string
	NfsAsgName                 string
	DeploymentUsernameId       string
	DeploymentPasswordId       string
	AdminPasswordId            string
	Role                       string
	DownBackendsRemovalTimeout time.Duration
	FetchWekaCredentials       bool
	ShowAdminPassword          bool
}

func FetchHostGroupInfo(params FetchInput) (fd protocol.HostGroupInfoResponse, err error) {
	svc := connectors.GetAWSSession().ASG
	asgNames := []string{params.WekaBackendsAsgName}
	if params.NfsAsgName != "" {
		asgNames = append(asgNames, params.NfsAsgName)
	}

	input := &autoscaling.DescribeAutoScalingGroupsInput{AutoScalingGroupNames: strings.ListToRefList(asgNames)}
	asgOutput, err := svc.DescribeAutoScalingGroups(input)
	if err != nil {
		return
	}

	asgInstances, err := common.GetASGInstances(asgNames)
	if err != nil {
		return
	}

	asgsInfo := make(map[string]asgInfo)
	var nfsInterfaceGroupInstanceIps map[string]types.Nilt

	for _, asg := range asgOutput.AutoScalingGroups {
		asgName := *asg.AutoScalingGroupName
		instanceIds := common.UnpackASGInstanceIds(asgInstances[asgName])
		log.Info().Msgf("Found %d instances on %s ASG", len(instanceIds), asgName)
		instances, err1 := common.GetInstances(instanceIds)
		if err1 != nil {
			err = err1
			return
		}
		asgsInfo[asgName] = asgInfo{
			desiredCapacity: int(*asg.DesiredCapacity),
			instances:       getHostGroupInfoInstances(instances),
		}

		if asgName == params.NfsAsgName {
			nfsInterfaceGroupInstanceIps = getInterfaceGroupInstanceIps(instances)
		}
	}

	backendIps, err := common.GetBackendsPrivateIps(params.ClusterName, "backend")
	if err != nil {
		return
	}

	var wekaPassword string
	var adminPassword string
	var username string

	if params.FetchWekaCredentials {
		var creds protocol.ClusterCreds
		if params.ShowAdminPassword {
			creds, err = common.GetWekaAdminCredentials(params.AdminPasswordId)
			if err != nil {
				err = fmt.Errorf("failed to get admin password: %w", err)
				log.Error().Err(err).Send()
				return
			}
			adminPassword = creds.Password

			creds, err = common.GetWekaDeploymentCredentials(params.DeploymentUsernameId, params.DeploymentPasswordId)
			if err != nil {
				err = fmt.Errorf("failed to get deployment credentials: %w", err)
				log.Error().Err(err).Send()
				return
			}
			wekaPassword = creds.Password
			username = creds.Username
		} else {
			creds, err = common.GetDeploymentOrAdminUsernameAndPassword(params.DeploymentUsernameId, params.DeploymentPasswordId, params.AdminPasswordId)
			if err != nil {
				err = fmt.Errorf("failed to get weka credentials: %w", err)
				log.Error().Err(err).Send()
				return
			}
			wekaPassword = creds.Password
			username = creds.Username
		}
	}

	return protocol.HostGroupInfoResponse{
		Username:                     username,
		Password:                     wekaPassword,
		AdminPassword:                adminPassword,
		WekaBackendsDesiredCapacity:  asgsInfo[params.WekaBackendsAsgName].desiredCapacity,
		WekaBackendInstances:         asgsInfo[params.WekaBackendsAsgName].instances,
		NfsBackendsDesiredCapacity:   asgsInfo[params.NfsAsgName].desiredCapacity,
		NfsBackendInstances:          asgsInfo[params.NfsAsgName].instances,
		NfsInterfaceGroupInstanceIps: nfsInterfaceGroupInstanceIps,
		BackendIps:                   backendIps,
		Role:                         params.Role,
		DownBackendsRemovalTimeout:   params.DownBackendsRemovalTimeout,
		Version:                      protocol.Version,
	}, nil
}

func getHostGroupInfoInstances(instances []*ec2.Instance) (ret []protocol.HgInstance) {
	for _, i := range instances {
		if i.InstanceId != nil && i.PrivateIpAddress != nil {
			ret = append(ret, protocol.HgInstance{
				Id:        *i.InstanceId,
				PrivateIp: *i.PrivateIpAddress,
			})
		}
	}
	return
}

func getInterfaceGroupInstanceIps(instances []*ec2.Instance) (nfsInterfaceGroupInstanceIps map[string]types.Nilt) {
	nfsInterfaceGroupInstanceIps = make(map[string]types.Nilt)

	for _, i := range instances {
		if i.InstanceId != nil && i.PrivateIpAddress != nil {
			for _, tag := range i.Tags {
				if *tag.Key == common.NfsInterfaceGroupPortKey && *tag.Value == common.NfsInterfaceGroupPortValue {
					nfsInterfaceGroupInstanceIps[*i.PrivateIpAddress] = types.Nilt{}
				}
			}
		}
	}
	return
}
