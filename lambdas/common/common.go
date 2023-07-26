package common

import (
	"context"
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go/service/autoscaling"
	"github.com/weka/go-cloud-lib/aws/aws_common"
	"github.com/weka/go-cloud-lib/lib/strings"
	"github.com/weka/go-cloud-lib/lib/types"
	"golang.org/x/sync/semaphore"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
	"github.com/aws/aws-sdk-go/service/dynamodb/expression"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/rs/zerolog/log"
	"github.com/weka/go-cloud-lib/aws/connectors"
	"github.com/weka/go-cloud-lib/protocol"
)

var (
	StateKey           = getStateKey()
	WaitForLockTimeout = time.Minute * 5
)

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

func getStateKey() string {
	prefix := os.Getenv("PREFIX")
	clusterName := os.Getenv("CLUSTER_NAME")
	if prefix == "" || clusterName == "" {
		log.Fatal().Msgf("Missing PREFIX or CLUSTER_NAME env vars")
	}
	return fmt.Sprintf("%s-%s-state", prefix, clusterName)
}

func LockState(table, hashKey string) (err error) {
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
			Key:                       map[string]*dynamodb.AttributeValue{hashKey: {S: aws.String(StateKey)}},
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

func UnlockState(table, hashKey string) (err error) {
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
		Key:                       map[string]*dynamodb.AttributeValue{hashKey: {S: aws.String(StateKey)}},
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

func GetClusterStateWithoutLock(table, hashKey string) (state protocol.ClusterState, err error) {
	client := connectors.GetAWSSession().DynamoDB
	input := dynamodb.GetItemInput{
		TableName:      aws.String(table),
		Key:            map[string]*dynamodb.AttributeValue{hashKey: {S: aws.String(StateKey)}},
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

func GetClusterState(table, hashKey string) (state protocol.ClusterState, err error) {
	log.Info().Msgf("Fetching cluster state %s from dynamodb", StateKey)

	err = LockState(table, hashKey)
	if err != nil {
		log.Error().Err(err).Send()
		return state, err
	}

	state, err = GetClusterStateWithoutLock(table, hashKey)

	unlockErr := UnlockState(table, hashKey)
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

func UpdateClusterState(table, hashKey string, state protocol.ClusterState) (err error) {
	client := connectors.GetAWSSession().DynamoDB

	value, err := dynamodbattribute.Marshal(state)
	if err != nil {
		log.Error().Err(err).Send()
		return err
	}

	_, err = client.UpdateItem(&dynamodb.UpdateItemInput{
		TableName: aws.String(table),
		Key:       map[string]*dynamodb.AttributeValue{hashKey: {S: aws.String(StateKey)}},
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
	return aws_common.GetSecret(tokenId)
}

func GetBackendsPrivateIps(clusterName string) (ips []string, err error) {
	svc := connectors.GetAWSSession().EC2
	log.Debug().Msgf("Fetching backends ips...")
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
					&clusterName,
				},
			},
			{
				Name: aws.String("tag:weka_hostgroup_type"),
				Values: []*string{
					aws.String("backend"),
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

func AddInstanceToStateInstances(table, hashKey, newInstance string) (instancesNames []string, err error) {
	err = LockState(table, hashKey)
	if err != nil {
		return
	}

	instancesNames, err = addInstanceToStateInstances(table, hashKey, newInstance)
	if err != nil {
		log.Error().Err(err).Send()
	}

	unlockErr := UnlockState(table, hashKey)
	if unlockErr != nil {
		// expand existing error
		err = fmt.Errorf("%v; %v", err, unlockErr)
	}
	return
}

// NOTE: Modifies state in dynamodb
// This function should be called only using Lock and Unlock state functions surrounding it
func addInstanceToStateInstances(table, hashKey, newInstance string) (instancesNames []string, err error) {
	state, err := GetClusterStateWithoutLock(table, hashKey)
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

	err = UpdateClusterState(table, hashKey, state)
	if err == nil {
		instancesNames = state.Instances
	}
	return
}

func UnpackASGInstanceIds(instances []*autoscaling.Instance) []*string {
	instanceIds := []*string{}
	if len(instances) == 0 {
		return instanceIds
	}
	for _, instance := range instances {
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

func setDisableInstanceApiTermination(instanceId string, value bool) (*ec2.ModifyInstanceAttributeOutput, error) {
	svc := connectors.GetAWSSession().EC2
	input := &ec2.ModifyInstanceAttributeInput{
		DisableApiTermination: &ec2.AttributeBooleanValue{
			Value: aws.Bool(value),
		},
		InstanceId: aws.String(instanceId),
	}
	return svc.ModifyInstanceAttribute(input)
}

var terminationSemaphore *semaphore.Weighted

func init() {
	terminationSemaphore = semaphore.NewWeighted(20)
}

func SetDisableInstancesApiTermination(instanceIds []string, value bool) (updated []string, errs []error) {
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
			_, err := setDisableInstanceApiTermination(instanceIds[i], value)
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

func GetASGInstances(asgName string) ([]*autoscaling.Instance, error) {
	svc := connectors.GetAWSSession().ASG
	asgOutput, err := svc.DescribeAutoScalingGroups(
		&autoscaling.DescribeAutoScalingGroupsInput{
			AutoScalingGroupNames: []*string{&asgName},
		},
	)
	if err != nil {
		return []*autoscaling.Instance{}, err
	}
	return asgOutput.AutoScalingGroups[0].Instances, nil
}
