package common

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math/rand"
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
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbiface"
	"github.com/aws/aws-sdk-go/service/dynamodb/expression"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/lambda"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/rs/zerolog/log"
	"golang.org/x/sync/semaphore"
)

const (
	NfsInterfaceGroupPortKey   = "nfs_interface_group_port"
	NfsInterfaceGroupPortValue = "ready"

	AdminUsername = "admin"
)

type InstancePrivateIpsSet map[string]types.Nilt

type StateItem struct {
	Value   protocol.ClusterState `json:"Value"`
	Version int64                 `json:"Version"`
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

// Cluster state lives in a single DynamoDB item per state key. Writes use optimistic concurrency
// on the top-level numeric "Version" attribute: read state+version, mutate, write conditionally on
// the version being unchanged, retry on conflict. An item without Version counts as version 0.

const (
	versionAttr = "Version"
	valueAttr   = "Value"
)

// Retry policy for conflicting attempts (package vars so tests can shrink them). Retries are bounded
// by a time budget rather than an attempt count: the budget is capped at the Lambda context deadline
// minus a margin, so there is time left to return the error before the Lambda is killed.
var (
	stateUpdateBackoffBase    = 50 * time.Millisecond
	stateUpdateBackoffMax     = 500 * time.Millisecond
	stateUpdateBudget         = 15 * time.Second
	stateUpdateDeadlineMargin = 2 * time.Second
)

var errStateUpdateConflict = errors.New("cluster state update conflict")

func isConditionalCheckFailed(err error) bool {
	var aerr awserr.Error
	return errors.As(err, &aerr) && aerr.Code() == dynamodb.ErrCodeConditionalCheckFailedException
}

// backoffDelay returns a jittered delay in [d/2, d] where d doubles with each (0-based) attempt up to the max.
func backoffDelay(attempt int) time.Duration {
	// The clamp only prevents shift overflow; the max applies long before it.
	d := min(stateUpdateBackoffBase<<min(attempt, 30), stateUpdateBackoffMax)
	return d/2 + time.Duration(rand.Int63n(int64(d/2)+1))
}

func readStateItem(client dynamodbiface.DynamoDBAPI, table, hashKey, stateKey string) (item StateItem, err error) {
	result, err := client.GetItem(&dynamodb.GetItemInput{
		TableName:      aws.String(table),
		Key:            map[string]*dynamodb.AttributeValue{hashKey: {S: aws.String(stateKey)}},
		ConsistentRead: aws.Bool(true),
	})
	if err != nil {
		return
	}
	if len(result.Item) == 0 {
		err = fmt.Errorf("state item %s not found in table %s", stateKey, table)
		return
	}
	err = dynamodbattribute.UnmarshalMap(result.Item, &item)
	return
}

func GetClusterState(table, hashKey, stateKey string) (state protocol.ClusterState, err error) {
	log.Info().Msgf("Fetching cluster state %s from dynamodb", stateKey)
	item, err := readStateItem(connectors.GetAWSSession().DynamoDB, table, hashKey, stateKey)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	return item.Value, nil
}

// UpdateClusterState atomically read-modify-writes the cluster state using optimistic locking.
// mutate may be called several times (once per attempt) and must be idempotent on its input;
// an error from mutate aborts immediately without writing or retrying.
// Conflicts are retried with jittered backoff until stateUpdateBudget elapses, or until
// stateUpdateDeadlineMargin before ctx's deadline if that is sooner, or ctx is cancelled;
// then errStateUpdateConflict is returned.
// Returns the state as written.
func UpdateClusterState(ctx context.Context, table, hashKey, stateKey string, mutate func(*protocol.ClusterState) error) (protocol.ClusterState, error) {
	return updateClusterState(ctx, connectors.GetAWSSession().DynamoDB, table, hashKey, stateKey, mutate)
}

func updateClusterState(ctx context.Context, client dynamodbiface.DynamoDBAPI, table, hashKey, stateKey string, mutate func(*protocol.ClusterState) error) (protocol.ClusterState, error) {
	deadline := time.Now().Add(stateUpdateBudget)
	if ctxDeadline, ok := ctx.Deadline(); ok {
		if capped := ctxDeadline.Add(-stateUpdateDeadlineMargin); capped.Before(deadline) {
			deadline = capped
		}
	}
	ctx, cancel := context.WithDeadline(ctx, deadline)
	defer cancel()

	for attempt := 0; ; attempt++ {
		item, err := readStateItem(client, table, hashKey, stateKey)
		if err != nil {
			return protocol.ClusterState{}, err
		}
		state := item.Value
		if err := mutate(&state); err != nil {
			return state, err
		}

		value, err := dynamodbattribute.Marshal(state)
		if err != nil {
			return state, err
		}
		expr, err := expression.NewBuilder().WithCondition(
			expression.Or(
				expression.AttributeNotExists(expression.Name(versionAttr)),
				expression.Equal(expression.Name(versionAttr), expression.Value(item.Version)),
			),
		).WithUpdate(
			expression.Set(expression.Name(valueAttr), expression.Value(value)).
				Set(expression.Name(versionAttr), expression.Value(item.Version+1)),
		).Build()
		if err != nil {
			return state, err
		}

		_, err = client.UpdateItem(&dynamodb.UpdateItemInput{
			TableName:                 aws.String(table),
			Key:                       map[string]*dynamodb.AttributeValue{hashKey: {S: aws.String(stateKey)}},
			UpdateExpression:          expr.Update(),
			ConditionExpression:       expr.Condition(),
			ExpressionAttributeNames:  expr.Names(),
			ExpressionAttributeValues: expr.Values(),
		})
		if err == nil {
			return state, nil
		}
		if !isConditionalCheckFailed(err) {
			return state, fmt.Errorf("failed to update state: %w", err)
		}
		log.Info().Msgf("State %s changed concurrently, retrying (attempt %d)", stateKey, attempt+1)
		select {
		case <-ctx.Done():
			return protocol.ClusterState{}, fmt.Errorf("%w: state %s still changing after %d attempts", errStateUpdateConflict, stateKey, attempt+1)
		case <-time.After(backoffDelay(attempt)):
		}
	}
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

func AddInstanceToStateInstances(ctx context.Context, table, hashKey, stateKey string, newInstance protocol.Vm) (protocol.ClusterState, error) {
	state, err := UpdateClusterState(ctx, table, hashKey, stateKey, func(state *protocol.ClusterState) error {
		if state.Clusterized {
			return fmt.Errorf("not adding instance %s to state instances list (this extra instance was created before the end of clusterization)", newInstance)
		}
		if len(state.Instances) == state.InitialSize {
			// This might happen if someone increases the desired number before the clusterization id done
			return fmt.Errorf("number of instances is already the initial size, not adding instance %s to state instances list", newInstance)
		}
		state.Instances = append(state.Instances, newInstance)
		return nil
	})
	if err != nil {
		log.Error().Err(err).Send()
	}
	return state, err
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

func CreateBucket(bucketName string, tags map[string]string) (err error) {
	svc := connectors.GetAWSSession().S3
	_, err = svc.CreateBucket(&s3.CreateBucketInput{
		Bucket: aws.String(bucketName),
	})
	if err != nil {
		return
	}

	// Apply tags to the bucket
	if len(tags) > 0 {
		tagSet := make([]*s3.Tag, 0, len(tags))
		for k, v := range tags {
			tagSet = append(tagSet, &s3.Tag{
				Key:   aws.String(k),
				Value: aws.String(v),
			})
		}

		_, err = svc.PutBucketTagging(&s3.PutBucketTaggingInput{
			Bucket: aws.String(bucketName),
			Tagging: &s3.Tagging{
				TagSet: tagSet,
			},
		})
	}
	return
}

func GetSecret(secretId string) (secret string, err error) {
	svc := connectors.GetAWSSession().SecretsManager
	input := &secretsmanager.GetSecretValueInput{
		SecretId: aws.String(secretId),
	}

	result, err := svc.GetSecretValue(input)
	if err != nil {
		log.Debug().Err(err).Msg("Failed to get secret value")
		return
	}
	secret = *result.SecretString
	return
}

func SetSecret(secretId, secret string) (err error) {
	svc := connectors.GetAWSSession().SecretsManager
	input := &secretsmanager.PutSecretValueInput{
		SecretId:     aws.String(secretId),
		SecretString: aws.String(secret),
	}

	_, err = svc.PutSecretValue(input)
	return
}

func GetDeploymentOrAdminUsernameAndPassword(usernameId, passwordId, adminPasswordId string) (clusterCreds protocol.ClusterCreds, err error) {
	log.Info().Msgf("Fetching username %s and password %s", usernameId, passwordId)
	deploymentPassword, err := GetSecret(passwordId)
	// if deploymentPassword doesn't exist, try to get adminPassword
	if err != nil && err.(awserr.Error).Code() == secretsmanager.ErrCodeResourceNotFoundException {
		adminPassword, err := GetSecret(adminPasswordId)
		if err != nil {
			log.Error().Err(err).Send()
			return clusterCreds, err
		}
		clusterCreds.Password = adminPassword
		clusterCreds.Username = AdminUsername
		return clusterCreds, nil
	}
	if err != nil {
		log.Error().Err(err).Send()
		return clusterCreds, err
	}

	clusterCreds.Password = deploymentPassword
	clusterCreds.Username, err = GetSecret(usernameId)
	if err != nil {
		log.Error().Err(err).Send()
		return clusterCreds, err
	}

	return
}

func GetWekaAdminCredentials(adminPasswordId string) (clusterCreds protocol.ClusterCreds, err error) {
	log.Info().Msgf("Fetching admin password %s", adminPasswordId)
	clusterCreds.Password, err = GetSecret(adminPasswordId)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	clusterCreds.Username = AdminUsername
	return
}

func GetWekaDeploymentCredentials(usernameId, passwordId string) (clusterCreds protocol.ClusterCreds, err error) {
	log.Info().Msgf("Fetching weka deployment username %s and password %s", usernameId, passwordId)
	clusterCreds.Password, err = GetSecret(passwordId)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	clusterCreds.Username, err = GetSecret(usernameId)
	if err != nil {
		log.Error().Err(err).Send()
	}
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

func GetNfsClusterSecondaryIps(clusterName string, instanceIds []*string) (secondaryIps []string, err error) {
	svc := connectors.GetAWSSession().EC2
	log.Debug().Msgf("Fetching cluster %s nfs secondary ips for instances %v...", clusterName, instanceIds)

	describeOutput, err := svc.DescribeNetworkInterfaces(&ec2.DescribeNetworkInterfacesInput{
		Filters: []*ec2.Filter{
			{
				Name:   aws.String("tag:weka_cluster_name"),
				Values: []*string{&clusterName},
			},
			{
				Name:   aws.String("tag:weka_hostgroup_type"),
				Values: []*string{aws.String("gateways-protocol")},
			},
			{
				Name:   aws.String("attachment.instance-id"),
				Values: instanceIds,
			},
		},
	})
	if err != nil {
		return
	}

	for _, networkInterface := range describeOutput.NetworkInterfaces {
		for _, privateIp := range networkInterface.PrivateIpAddresses {
			if privateIp.Primary != nil && !*privateIp.Primary {
				secondaryIps = append(secondaryIps, *privateIp.PrivateIpAddress)
			}
		}
	}

	return
}

func InvokeLambdaFunction[T any](functionName string, payload interface{}) (*T, error) {
	svc := connectors.GetAWSSession().Lambda
	log.Debug().Msgf("Invoking lambda function %s...", functionName)

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	input := &lambda.InvokeInput{
		FunctionName: aws.String(functionName),
		Payload:      payloadBytes,
	}

	result, err := svc.Invoke(input)
	if err != nil {
		return nil, err
	}

	var response T
	if err := json.Unmarshal(result.Payload, &response); err != nil {
		return nil, err
	}
	return &response, nil
}
