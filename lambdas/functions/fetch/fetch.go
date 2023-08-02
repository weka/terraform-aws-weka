package lambdas

import (
	"github.com/aws/aws-sdk-go/service/autoscaling"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/connectors"
	"github.com/weka/go-cloud-lib/protocol"
)

func getAutoScalingGroupDesiredCapacity(asgOutput *autoscaling.DescribeAutoScalingGroupsOutput) int {
	if len(asgOutput.AutoScalingGroups) == 0 {
		return -1
	}

	return int(*asgOutput.AutoScalingGroups[0].DesiredCapacity)
}

func GetFetchDataParams(clusterName, asgName, usernameId, passwordId, role string, useSecretManagerEndpoint bool) (fd protocol.HostGroupInfoResponse, err error) {
	svc := connectors.GetAWSSession().ASG
	input := &autoscaling.DescribeAutoScalingGroupsInput{AutoScalingGroupNames: []*string{&asgName}}
	asgOutput, err := svc.DescribeAutoScalingGroups(input)
	if err != nil {
		return
	}

	instanceIds := common.UnpackASGInstanceIds(asgOutput.AutoScalingGroups[0].Instances)
	instances, err := common.GetInstances(instanceIds)
	if err != nil {
		return
	}

	backendIps, err := common.GetBackendsPrivateIps(clusterName)
	if err != nil {
		return
	}

	var creds protocol.ClusterCreds
	if !useSecretManagerEndpoint {
		creds, err = common.GetUsernameAndPassword(usernameId, passwordId)
		if err != nil {
			return
		}
	}

	return protocol.HostGroupInfoResponse{
		Username:        creds.Username,
		Password:        creds.Password,
		DesiredCapacity: getAutoScalingGroupDesiredCapacity(asgOutput),
		Instances:       getHostGroupInfoInstances(instances),
		BackendIps:      backendIps,
		Role:            role,
		Version:         protocol.Version,
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
