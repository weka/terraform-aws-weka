package common

import (
	"cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
	"context"
	"fmt"
	session "github.com/aws/aws-sdk-go/aws/session"
	compute "github.com/aws/aws-sdk-go/service/ec2"
	secretmanager "github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/rs/zerolog/log"
	"google.golang.org/api/iterator"
)

type AwsObsParams struct {
	Name              string
	TieringSsdPercent string
}

type ClusterCreds struct {
	Username string
	Password string
}

type ClusterState struct {
	InitialSize int      `json:"initial_size"`
	DesiredSize int      `json:"desired_size"`
	Instances   []string `json:"instances"`
	Clusterized bool     `json:"clusterized"`
}

func GetASGInstances(asgName, region string) ([]*autoscaling.Instance, error) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region)},
	)
	svc := connectors.autoscaling.New(sess)
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

func GetUsernameAndPassword(ctx context.Context, usernameId, passwordId string) (clusterCreds ClusterCreds, err error) {
	client, err := secretmanager.New(session.New(ctx), aws.NewConfig().WithRegion(region))
	if err != nil {
		return
	}
	defer client.Close()

	res, err := client.AccessSecretVersion(ctx, &secretmanagerpb.AccessSecretVersionRequest{Name: usernameId})
	if err != nil {
		return
	}
	clusterCreds.Username = string(res.Payload.Data)
	res, err = client.AccessSecretVersion(ctx, &secretmanagerpb.AccessSecretVersionRequest{Name: passwordId})
	if err != nil {
		return
	}
	clusterCreds.Password = string(res.Payload.Data)
	return
}

func generateInstanceNamesFilter(instanceNames []string) (namesFilter string) {
	namesFilter = fmt.Sprintf("name=%s", instanceNames[0])
	for _, instanceName := range instanceNames[1:] {
		namesFilter = fmt.Sprintf("%s OR name=%s", namesFilter, instanceName)
	}
	log.Info().Msgf("%s", namesFilter)
	return
}

func GetInstances(ctx context.Context, region string, instanceNames []string) (instances []*computepb.Instance, err error) {
	if len(instanceNames) == 0 {
		log.Warn().Msg("Got empty instance names list")
		return
	}

	namesFilter := generateInstanceNamesFilter(instanceNames)

	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
	}
	defer instanceClient.Close()

	listInstanceRequest := &computepb.ListInstancesRequest{
		Region: region,
		Filter: &namesFilter,
	}

	listInstanceIter := instanceClient.List(ctx, listInstanceRequest)

	for {
		resp, err := listInstanceIter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Fatal().Err(err)
			break
		}
		log.Info().Msgf("%s %d %s", *resp.Name, resp.Id, *resp.NetworkInterfaces[0].NetworkIP)
		instances = append(instances, resp)

		_ = resp
	}
	return
}

func GetBackendsIps(ctx context.Context, region string, instancesNames []string) (backendsIps []string) {
	instances, err := GetInstances(ctx, region, instancesNames)
	if err != nil {
		return
	}
	for _, instance := range instances {
		// get one IP per instance
		backendsIps = append(backendsIps, *instance.NetworkInterfaces[0].NetworkIP)
	}
	return
}

func CreateBucket(ctx context.Context, region, obsName string) (err error) {
	log.Info().Msgf("Creating bucket %s", obsName)
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region)},
	)

	// Create S3 service client
	svc := s3.New(sess)

	// Creates a Bucket instance.
	if err = svc.GetObjectRequest(&s3.GetObjectInput{Bucket: aws.String(obsName), Key: aws.String("myKey")}); err != nil {
		log.Error().Err(err).Send()
		return
	}
	return
}
