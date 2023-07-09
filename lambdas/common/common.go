package common

import (
	"bytes"
	"encoding/json"
	"fmt"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/connectors"
	"github.com/weka/go-cloud-lib/protocol"
	"io"
	"time"
)

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

func GetClusterState(bucket string) (state protocol.ClusterState, err error) {
	log.Info().Msgf("Fetching cluster state from bucket %s", bucket)
	client := connectors.GetAWSSession().S3
	result, err := client.GetObject(&s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String("state"),
	},
	)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	log.Info().Msg("Fetched cluster state successfully")

	defer result.Body.Close()
	body, err := io.ReadAll(result.Body)
	if err != nil {
		log.Error().Err(err).Send()
	}

	err = json.Unmarshal(body, &state)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	return
}

func UpdateClusterState(bucket string, state protocol.ClusterState) (err error) {
	client := connectors.GetAWSSession().S3

	_state, err := json.Marshal(state)
	if err != nil {
		log.Error().Err(err).Send()
		return err
	}

	_, err = client.PutObject(&s3.PutObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String("state"),
		Body:   aws.ReadSeekCloser(bytes.NewReader(_state)),
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

func LockState(bucket string) (err error) {
	svc := connectors.GetAWSSession().S3
	err = fmt.Errorf("failed to lock state")
	for start := time.Now(); time.Since(start) < time.Minute*5 && err != nil; {
		_, err = svc.PutObject(&s3.PutObjectInput{
			Bucket: aws.String(bucket),
			Key:    aws.String("lock"),
		})
	}
	return
}

func UnlockState(bucket string) (err error) {
	svc := connectors.GetAWSSession().S3
	_, err = svc.DeleteObject(&s3.DeleteObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String("lock"),
	})
	return
}

func AddInstanceToStateInstances(bucket, newInstance string) (instancesNames []string, err error) {
	err = LockState(bucket)
	if err != nil {
		log.Error().Err(err).Send()
	}
	state, err := GetClusterState(bucket)

	if len(state.Instances) == state.InitialSize {
		//This might happen if someone increases the desired number before the clusterization id done
		err = fmt.Errorf("number of instances is already the initial size, not adding instance %s to state instances list", newInstance)
		log.Error().Err(err).Send()
		return
	}
	state.Instances = append(state.Instances, newInstance)

	err = UpdateClusterState(bucket, state)
	if err == nil {
		instancesNames = state.Instances
	}

	err = UnlockState(bucket)
	if err != nil {
		log.Error().Err(err).Send()
	}
	return
}
