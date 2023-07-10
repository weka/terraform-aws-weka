package common

import (
	"fmt"
	"os"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
	"github.com/aws/aws-sdk-go/service/dynamodb/expression"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/connectors"
	"github.com/weka/go-cloud-lib/protocol"
)

var (
	StateKey           = getStateKey()
	WaitForLockTimeout = time.Minute * 5
)

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
	if err != nil {
		log.Error().Err(err).Send()
		return state, err
	}

	err = UnlockState(table, hashKey)
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

func getSecret(secretId string) (secret string, err error) {
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

func GetWekaIoToken(tokenId string) (token string, err error) {
	log.Info().Msgf("Fetching token %s", tokenId)
	return getSecret(tokenId)
}

func GetUsernameAndPassword(usernameId, passwordId string) (clusterCreds protocol.ClusterCreds, err error) {
	log.Info().Msgf("Fetching username %s and password %s", usernameId, passwordId)
	clusterCreds.Username, err = getSecret(usernameId)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	clusterCreds.Password, err = getSecret(passwordId)
	return
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

func AddInstanceToStateInstances(table, hashKey, newInstance string) (instancesNames []string, err error) {
	err = LockState(table, hashKey)
	if err != nil {
		return
	}

	state, err := GetClusterStateWithoutLock(table, hashKey)
	if err != nil {
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

	err = UnlockState(table, hashKey)
	if err != nil {
		log.Error().Err(err).Send()
	}
	return
}
