package lambdas

import (
	"github.com/aws/aws-sdk-go/service/autoscaling"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/connectors"
	"github.com/weka/go-cloud-lib/lib/strings"
	"github.com/weka/go-cloud-lib/lib/types"
	"github.com/weka/go-cloud-lib/protocol"
	"time"
)

type asgInfo struct {
	instances       []protocol.HgInstance
	desiredCapacity int
}

func GetFetchDataParams(clusterName, wekaBackendsAsgName, nfsAsgName, usernameId, passwordId, role string, downBackendsRemovalTimeout time.Duration, fetchWekaCredentials bool) (fd protocol.HostGroupInfoResponse, err error) {
	svc := connectors.GetAWSSession().ASG
	asgNames := []string{wekaBackendsAsgName}
	if nfsAsgName != "" {
		asgNames = append(asgNames, nfsAsgName)
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
	terminatedHgsIps := make(map[string]types.Nilt)

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

		if asgName == nfsAsgName {
			nfsInterfaceGroupInstanceIps = getInterfaceGroupInstanceIps(instances)
		}

		for _, instance := range instances {
			if instance.State != nil && *instance.State.Name == "terminated" {
				if instance.PrivateIpAddress != nil {
					terminatedHgsIps[*instance.PrivateIpAddress] = types.Nilt{}
				} else {
					log.Info().Msgf("Instance %s is terminated and has no private IP", *instance.InstanceId)
				}
			}
		}
	}

	backendIps, err := common.GetBackendsPrivateIps(clusterName, "backend")
	if err != nil {
		return
	}

	var creds protocol.ClusterCreds
	if fetchWekaCredentials {
		creds, err = common.GetUsernameAndPassword(usernameId, passwordId)
		if err != nil {
			return
		}
	}

	return protocol.HostGroupInfoResponse{
		Username:                     creds.Username,
		Password:                     creds.Password,
		WekaBackendsDesiredCapacity:  asgsInfo[wekaBackendsAsgName].desiredCapacity,
		WekaBackendInstances:         asgsInfo[wekaBackendsAsgName].instances,
		NfsBackendsDesiredCapacity:   asgsInfo[nfsAsgName].desiredCapacity,
		NfsBackendInstances:          asgsInfo[nfsAsgName].instances,
		NfsInterfaceGroupInstanceIps: nfsInterfaceGroupInstanceIps,
		BackendIps:                   backendIps,
		Role:                         role,
		DownBackendsRemovalTimeout:   downBackendsRemovalTimeout,
		TerminatedHgsIps:             terminatedHgsIps,
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
