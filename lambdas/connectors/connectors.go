package connectors

import (
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials/stscreds"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/apigateway"
	"github.com/aws/aws-sdk-go/service/autoscaling"
	"github.com/aws/aws-sdk-go/service/cloudformation"
	"github.com/aws/aws-sdk-go/service/cloudwatchevents"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/elb"
	"github.com/aws/aws-sdk-go/service/elbv2"
	"github.com/aws/aws-sdk-go/service/iam"
	"github.com/aws/aws-sdk-go/service/kms"
	"github.com/aws/aws-sdk-go/service/lambda"
	"github.com/aws/aws-sdk-go/service/route53"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/aws/aws-sdk-go/service/sfn"
	"github.com/aws/aws-sdk-go/service/sts"
	"os"
	"sync"
)

type SAwsSession struct {
	sync.RWMutex
	Session          *session.Session
	CF               *cloudformation.CloudFormation
	EC2              *ec2.EC2
	ASG              *autoscaling.AutoScaling
	KMS              *kms.KMS
	DynamoDB         *dynamodb.DynamoDB
	IAM              *iam.IAM
	Lambda           *lambda.Lambda
	ApiGateway       *apigateway.APIGateway
	STS              *sts.STS
	SFN              *sfn.SFN
	CloudWatchEvents *cloudwatchevents.CloudWatchEvents
	ELB              *elb.ELB
	ELBV2            *elbv2.ELBV2
	Route53          *route53.Route53
	S3               *s3.S3
	SecretsManager   *secretsmanager.SecretsManager
}

var awsSession SAwsSession

func GetAWSSession() *SAwsSession {
	if awsSession.Session != nil {
		return &awsSession
	}
	awsSession.Lock()
	defer awsSession.Unlock()
	if awsSession.Session == nil {
		awsSession.Session = newSession(os.Getenv("REGION"))
		awsSession.CF = cloudformation.New(awsSession.Session)
		awsSession.EC2 = ec2.New(awsSession.Session)
		awsSession.ASG = autoscaling.New(awsSession.Session)
		awsSession.KMS = kms.New(awsSession.Session)
		awsSession.DynamoDB = dynamodb.New(awsSession.Session)
		awsSession.IAM = iam.New(awsSession.Session)
		awsSession.Lambda = lambda.New(awsSession.Session)
		awsSession.ApiGateway = apigateway.New(awsSession.Session)
		awsSession.STS = sts.New(awsSession.Session)
		awsSession.SFN = sfn.New(awsSession.Session)
		awsSession.CloudWatchEvents = cloudwatchevents.New(awsSession.Session)
		awsSession.ELB = elb.New(awsSession.Session)
		awsSession.ELBV2 = elbv2.New(awsSession.Session)
		awsSession.Route53 = route53.New(awsSession.Session)
		awsSession.S3 = s3.New(awsSession.Session)
		awsSession.SecretsManager = secretsmanager.New(awsSession.Session)
	}
	return &awsSession
}

func newSession(region string) *session.Session {
	// TODO: Double-check if works profile
	config := aws.NewConfig()
	config = config.WithRegion(region)
	config = config.WithCredentialsChainVerboseErrors(true)

	// Create the options for the Session
	opts := session.Options{
		Config:                  *config,
		SharedConfigState:       session.SharedConfigEnable,
		AssumeRoleTokenProvider: stscreds.StdinTokenProvider,
	}

	return session.Must(session.NewSessionWithOptions(opts))
}
