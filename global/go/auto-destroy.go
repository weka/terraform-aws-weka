package main

import (
    "context"
    "flag"
    "fmt"
    "log"
    "time"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/ec2"
    "github.com/aws/aws-sdk-go-v2/service/ec2/types"
)

func main() {
    // Define flags for tag key, tag value, and expiration time in hours
    tagKey := flag.String("tag-key", "AutoDestroy", "Tag key for identifying instances")
    tagValue := flag.String("tag-value", "true", "Tag value for identifying instances")
    expirationTime := flag.Int("expiration-time", 2, "Expiration time in hours")

    flag.Parse()

    // Load AWS config
    cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion("us-west-2"))
    if err != nil {
        log.Fatalf("unable to load AWS config, %v", err)
    }

    svc := ec2.NewFromConfig(cfg)

    // Describe instances with the specified tag
    instances, err := svc.DescribeInstances(context.TODO(), &ec2.DescribeInstancesInput{
        Filters: []types.Filter{
            {
                Name:   aws.String(fmt.Sprintf("tag:%s", *tagKey)),
                Values: []string{*tagValue},
            },
            {
                Name:   aws.String("instance-state-name"),
                Values: []string{"running"},
            },
        },
    })
    if err != nil {
        log.Fatalf("unable to describe instances, %v", err)
    }

    // Terminate instances that exceed the expiration time
    expirationDuration := time.Duration(*expirationTime) * time.Hour
    now := time.Now()

    for _, reservation := range instances.Reservations {
        for _, instance := range reservation.Instances {
            launchTime := *instance.LaunchTime
            if now.Sub(launchTime) > expirationDuration {
                _, err := svc.TerminateInstances(context.TODO(), &ec2.TerminateInstancesInput{
                    InstanceIds: []string{*instance.InstanceId},
                })
                if err != nil {
                    log.Printf("failed to terminate instance %s, %v", *instance.InstanceId, err)
                } else {
                    log.Printf("terminated instance %s", *instance.InstanceId)
                }
            }
        }
    }
}
