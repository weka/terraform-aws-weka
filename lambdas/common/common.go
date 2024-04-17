package common

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/connectors"
	"github.com/weka/go-cloud-lib/lib/strings"
	"github.com/weka/go-cloud-lib/lib/types"
	"github.com/weka/go-cloud-lib/protocol"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/service/autoscaling"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
	"github.com/aws/aws-sdk-go/service/dynamodb/expression"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/rs/zerolog/log"
	"golang.org/x/sync/semaphore"
)

var (
	WaitForLockTimeout = time.Minute * 5
)

const NfsInterfaceGroupPortKey = "nfs_interface_group_port"
const NfsInterfaceGroupPortValue = "ready"

type InstancePrivateIpsSet map[string]types.Nilt

type StateItem struct {
	Value  protocol.ClusterState `json:"Value"`
	Locked bool                  `json:"Locked"`
}

const FindDrivesScript = `
import json
import sys
for d in json.load(sys.stdin)['disks']:
	if d['isRotational']: continue
	if d['type'] != 'DISK': continue
	if d['isMounted']: continue
	if d['model'] != 'Amazon EC2 NVMe Instance Storage': continue
	print(d['devPath'])
`

type AwsObsParams struct {
	Name              string
	TieringSsdPercent string
}

func LockState(table, hashKey, stateKey string) (err error) {
	client := connectors.GetAWSSession().DynamoDB
	log.Debug().Msgf("Trying to lock state in table %s", table)

	for start := time.Now(); time.Since(start) < WaitForLockTimeout; {
		expr, err := expression.NewBuilder().WithCondition(
			expression.Equal(expression.Name("Locked"), expression.Value(false)),
		).WithUpdate(
			expression.Set(expression.Name("Locked"), expression.Value(true)),
		).Build()
		if err != nil {
			log.Error().Err(err).Send()
			return err
		}

		input := &dynamodb.UpdateItemInput{
			TableName:                 aws.String(table),
			Key:                       map[string]*dynamodb.AttributeValue{hashKey: {S: aws.String(stateKey)}},
			UpdateExpression:          expr.Update(),
			ConditionExpression:       expr.Condition(),
			ExpressionAttributeNames:  expr.Names(),
			ExpressionAttributeValues: expr.Values(),
		}
		_, err = client.UpdateItem(input)
		// get aws error code
		if err != nil && err.(awserr.Error).Code() == dynamodb.ErrCodeConditionalCheckFailedException {
			// wait for state being unlocked
			log.Info().Msg("State is locked, waiting for a second")
			time.Sleep(time.Second)
			continue
		}
		if err != nil {
			err = fmt.Errorf("failed to lock state: %v", err)
			log.Debug().Err(err).Send()
			return err
		} else {
			log.Debug().Msg("Locked state")
			break
		}
	}
	return
}

func UnlockState(table, hashKey, stateKey string) (err error) {
	client := connectors.GetAWSSession().DynamoDB

	expr, err := expression.NewBuilder().WithUpdate(
		expression.Set(expression.Name("Locked"), expression.Value(false)),
	).Build()
	if err != nil {
		log.Error().Err(err).Send()
		return err
	}

	input := &dynamodb.UpdateItemInput{
		TableName:                 aws.String(table),
		Key:                       map[string]*dynamodb.AttributeValue{hashKey: {S: aws.String(stateKey)}},
		UpdateExpression:          expr.Update(),
		ExpressionAttributeNames:  expr.Names(),
		ExpressionAttributeValues: expr.Values(),
	}
	_, err = client.UpdateItem(input)

	if err == nil {
		log.Debug().Msg("Unlocked state")
	}
	return
}

func GetClusterStateWithoutLock(table, hashKey, stateKey string) (state protocol.ClusterState, err error) {
	client := connectors.GetAWSSession().DynamoDB
	input := dynamodb.GetItemInput{
		TableName:      aws.String(table),
		Key:            map[string]*dynamodb.AttributeValue{hashKey: {S: aws.String(stateKey)}},
		ConsistentRead: aws.Bool(true),
	}

	result, err := client.GetItem(&input)
	if err != nil {
		log.Error().Err(err).Send()
		return state, err
	}

	var stateItem StateItem
	err = dynamodbattribute.UnmarshalMap(result.Item, &stateItem)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	state = stateItem.Value
	return
}

func GetClusterState(table, hashKey, stateKey string) (state protocol.ClusterState, err error) {
	log.Info().Msgf("Fetching cluster state %s from dynamodb", stateKey)

	err = LockState(table, hashKey, stateKey)
	if err != nil {
		log.Error().Err(err).Send()
		return state, err
	}

	state, err = GetClusterStateWithoutLock(table, hashKey, stateKey)

	unlockErr := UnlockState(table, hashKey, stateKey)
	if unlockErr != nil {
		// expand existing error
		err = fmt.Errorf("%v; %v", err, unlockErr)
	}

	if err != nil {
		log.Error().Err(err).Send()
		return state, err
	}

	log.Info().Msg("Fetched cluster state successfully")
	return
}

func UpdateClusterState(table, hashKey, stateKey string, state protocol.ClusterState) (err error) {
	client := connectors.GetAWSSession().DynamoDB

	value, err := dynamodbattribute.Marshal(state)
	if err != nil {
		log.Error().Err(err).Send()
		return err
	}

	_, err = client.UpdateItem(&dynamodb.UpdateItemInput{
		TableName: aws.String(table),
		Key:       map[string]*dynamodb.AttributeValue{hashKey: {S: aws.String(stateKey)}},
		AttributeUpdates: map[string]*dynamodb.AttributeValueUpdate{
			"Value": {
				Action: aws.String("PUT"),
				Value:  value,
			},
		},
	})
	return
}

func GetWekaIoToken(tokenId string) (token string, err error) {
	log.Info().Msgf("Fetching token %s", tokenId)
	return GetSecret(tokenId)
}

func GetBackendsPrivateIps(clusterName, hostGroup string) (ips []string, err error) {
	svc := connectors.GetAWSSession().EC2
	log.Debug().Msgf("Fetching running backends ips...")
	describeResponse, err := svc.DescribeInstances(&ec2.DescribeInstancesInput{
		Filters: []*ec2.Filter{
			{
				Name: aws.String("instance-state-name"),
				Values: []*string{
					aws.String("running"),
				},
			},
			{
				Name: aws.String("tag:weka_cluster_name"),
				Values: []*string{
					aws.String(clusterName),
				},
			},
			{
				Name: aws.String("tag:weka_hostgroup_type"),
				Values: []*string{
					aws.String(hostGroup),
				},
			},
		},
	})
	if err != nil {
		return
	}

	for _, reservation := range describeResponse.Reservations {
		for _, instance := range reservation.Instances {
			if instance.PrivateIpAddress == nil {
				log.Warn().Msgf("Found backend instance %s without private ip!", *instance.InstanceId)
				continue
			}
			ips = append(ips, *instance.PrivateIpAddress)
		}
	}
	log.Debug().Msgf("found %d backends private ips: %s", len(ips), ips)
	return
}

func GetBackendWekaVolumeId(InstanceId string) (volumeId string, err error) {
	svc := connectors.GetAWSSession().EC2
	log.Debug().Msgf("Fetching backend %s volume ids...", InstanceId)
	describeResponse, err := svc.DescribeInstances(&ec2.DescribeInstancesInput{
		InstanceIds: []*string{aws.String(InstanceId)},
	})
	if err != nil {
		return
	}

	for _, reservation := range describeResponse.Reservations {
		for _, instance := range reservation.Instances {
			for _, blockDevice := range instance.BlockDeviceMappings {
				log.Debug().Msgf("found block device %s", *blockDevice.DeviceName)
				if *blockDevice.DeviceName == "/dev/sdp" {
					volumeId = *blockDevice.Ebs.VolumeId
					break
				}
			}
		}
	}
	log.Debug().Msgf("found volume id %s", volumeId)
	return
}

func AddInstanceToStateInstances(table, hashKey, stateKey string, newInstance protocol.Vm) (state protocol.ClusterState, err error) {
	err = LockState(table, hashKey, stateKey)
	if err != nil {
		return
	}

	state, err = addInstanceToStateInstances(table, hashKey, stateKey, newInstance)
	if err != nil {
		log.Error().Err(err).Send()
	}

	unlockErr := UnlockState(table, hashKey, stateKey)
	if unlockErr != nil {
		// expand existing error
		err = fmt.Errorf("%v; %v", err, unlockErr)
	}
	return
}

// NOTE: Modifies state in dynamodb
// This function should be called only using Lock and Unlock state functions surrounding it
func addInstanceToStateInstances(table, hashKey, stateKey string, newInstance protocol.Vm) (state protocol.ClusterState, err error) {
	state, err = GetClusterStateWithoutLock(table, hashKey, stateKey)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	if state.Clusterized {
		err = fmt.Errorf("not adding instance %s to state instances list (this extra instance was created before the end of clusterization)", newInstance)
		log.Error().Err(err).Send()
		return
	}

	if len(state.Instances) == state.InitialSize {
		//This might happen if someone increases the desired number before the clusterization id done
		err = fmt.Errorf("number of instances is already the initial size, not adding instance %s to state instances list", newInstance)
		log.Error().Err(err).Send()
		return
	}
	state.Instances = append(state.Instances, newInstance)

	err = UpdateClusterState(table, hashKey, stateKey, state)

	return
}

func UnpackASGInstanceIds(asgInstances []*autoscaling.Instance) (instanceIds []*string) {
	if len(asgInstances) == 0 {
		return instanceIds
	}
	for _, instance := range asgInstances {
		instanceIds = append(instanceIds, instance.InstanceId)
	}
	return instanceIds
}

func getEc2InstancesFromDescribeOutput(describeResponse *ec2.DescribeInstancesOutput) (instances []*ec2.Instance) {
	for _, reservation := range describeResponse.Reservations {
		for _, instance := range reservation.Instances {
			instances = append(instances, instance)
		}
	}
	return
}

func GetInstances(instanceIds []*string) (instances []*ec2.Instance, err error) {
	if len(instanceIds) == 0 {
		err = fmt.Errorf("instanceIds list must not be empty")
		return
	}
	svc := connectors.GetAWSSession().EC2
	describeResponse, err := svc.DescribeInstances(&ec2.DescribeInstancesInput{
		InstanceIds: instanceIds,
	})
	if err != nil {
		return
	}

	instances = getEc2InstancesFromDescribeOutput(describeResponse)
	return
}

func GetBackendsPrivateIPsFromInstanceIds(instanceIds []*string) (privateIps []string, err error) {
	instances, err := GetInstances(instanceIds)
	if err != nil {
		return
	}
	for _, i := range instances {
		if i.InstanceId != nil && i.PrivateIpAddress != nil {
			privateIps = append(privateIps, *i.PrivateIpAddress)
		}
	}
	return
}

func Min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func DetachInstancesFromASG(instancesIds []string, autoScalingGroupsName string) error {
	svc := connectors.GetAWSSession().ASG
	limit := 20
	for i := 0; i < len(instancesIds); i += limit {
		batch := strings.ListToRefList(instancesIds[i:Min(i+limit, len(instancesIds))])
		_, err := svc.DetachInstances(&autoscaling.DetachInstancesInput{
			AutoScalingGroupName:           &autoScalingGroupsName,
			InstanceIds:                    batch,
			ShouldDecrementDesiredCapacity: aws.Bool(false),
		})
		if err != nil {
			return err
		}
		log.Info().Msgf("Detached %d instances from %s successfully!", len(batch), autoScalingGroupsName)
	}
	return nil
}

func setDisableInstanceApiStopAndTermination(instanceId string, value bool) (err error) {
	// aws sdk doesn't allow to set both attrs in one api call

	svc := connectors.GetAWSSession().EC2

	_, err = svc.ModifyInstanceAttribute(&ec2.ModifyInstanceAttributeInput{
		DisableApiTermination: &ec2.AttributeBooleanValue{
			Value: aws.Bool(value),
		},
		InstanceId: aws.String(instanceId),
	})
	if err != nil {
		return
	}

	_, err = svc.ModifyInstanceAttribute(&ec2.ModifyInstanceAttributeInput{
		DisableApiStop: &ec2.AttributeBooleanValue{
			Value: aws.Bool(value),
		},
		InstanceId: aws.String(instanceId),
	})
	return
}

var terminationSemaphore *semaphore.Weighted

func init() {
	terminationSemaphore = semaphore.NewWeighted(20)
}

func SetDisableInstancesApiStopAndTermination(instanceIds []string, value bool) (updated []string, errs []error) {
	var wg sync.WaitGroup
	var responseLock sync.Mutex

	log.Debug().Msgf("Setting instances DisableApiTermination to: %t ...", value)
	wg.Add(len(instanceIds))
	for i := range instanceIds {
		go func(i int) {
			_ = terminationSemaphore.Acquire(context.Background(), 1)
			defer terminationSemaphore.Release(1)
			defer wg.Done()

			responseLock.Lock()
			defer responseLock.Unlock()
			err := setDisableInstanceApiStopAndTermination(instanceIds[i], value)
			if err != nil {
				errs = append(errs, err)
				log.Error().Err(err)
				log.Error().Msgf("failed to set DisableApiTermination on %s", instanceIds[i])
			}
			updated = append(updated, instanceIds[i])
		}(i)
	}
	wg.Wait()
	return
}

func GetASGInstances(asgNames []string) (asgInstances map[string][]*autoscaling.Instance, err error) {
	svc := connectors.GetAWSSession().ASG
	asgInstances = make(map[string][]*autoscaling.Instance)
	asgNamesRefList := strings.ListToRefList(asgNames)
	asgOutput, err := svc.DescribeAutoScalingGroups(
		&autoscaling.DescribeAutoScalingGroupsInput{
			AutoScalingGroupNames: asgNamesRefList,
		},
	)
	if err != nil {
		return
	}

	for _, asg := range asgOutput.AutoScalingGroups {
		asgInstances[*asg.AutoScalingGroupName] = asg.Instances
	}
	return
}

func CreateBucket(bucketName string) (err error) {
	svc := connectors.GetAWSSession().S3
	_, err = svc.CreateBucket(&s3.CreateBucketInput{
		Bucket: aws.String(bucketName),
	})
	return
}

func GetSecret(secretId string) (secret string, err error) {
	svc := connectors.GetAWSSession().SecretsManager
	input := &secretsmanager.GetSecretValueInput{
		SecretId: aws.String(secretId),
	}

	result, err := svc.GetSecretValue(input)
	if err != nil {
		log.Error().Err(err).Msg("Failed to get secret value")
		return
	}
	secret = *result.SecretString
	return
}

func GetUsernameAndPassword(usernameId, passwordId string) (clusterCreds protocol.ClusterCreds, err error) {
	log.Info().Msgf("Fetching username %s and password %s", usernameId, passwordId)
	clusterCreds.Username, err = GetSecret(usernameId)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	clusterCreds.Password, err = GetSecret(passwordId)
	return
}

func GetALBIp(albArnSuffix string) (albIp string, err error) {
	if albArnSuffix == "" {
		return
	}

	svc := connectors.GetAWSSession().EC2
	log.Debug().Msgf("Fetching ALB %s ip...", albArnSuffix)

	describeOutput, err := svc.DescribeNetworkInterfaces(&ec2.DescribeNetworkInterfacesInput{
		Filters: []*ec2.Filter{
			{
				Name: aws.String("description"),
				Values: []*string{
					aws.String("ELB " + albArnSuffix),
				},
			},
		},
	})
	if err != nil {
		return
	}

	if len(describeOutput.NetworkInterfaces) > 0 {
		albIp = *describeOutput.NetworkInterfaces[0].PrivateIpAddress
		log.Debug().Msgf("ALB ip %s", albIp)
	} else {
		log.Debug().Msgf("No ALB network interface was found")
	}

	return
}

func GetInstancesNames(instances []protocol.Vm) (vmNames []string) {
	for _, instance := range instances {
		vmNames = append(vmNames, instance.Name)
	}
	return
}

func GetClusterSecondaryIps(gatewaysName string) (secondaryIps []string, err error) {
	svc := connectors.GetAWSSession().EC2
	log.Debug().Msgf("Fetching cluster %s secondary ips...", gatewaysName)

	describeOutput, err := svc.DescribeNetworkInterfaces(&ec2.DescribeNetworkInterfacesInput{
		Filters: []*ec2.Filter{
			{
				Name:   aws.String("tag:Name"),
				Values: []*string{&gatewaysName},
			},
		},
	})
	if err != nil {
		return
	}

	for _, networkInterface := range describeOutput.NetworkInterfaces {
		for _, privateIp := range networkInterface.PrivateIpAddresses {
			secondaryIps = append(secondaryIps, *privateIp.PrivateIpAddress)
		}
	}

	return
}
