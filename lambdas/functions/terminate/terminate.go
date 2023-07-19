package terminate

import (
	"errors"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/autoscaling"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/go-cloud-lib/aws/connectors"
	"github.com/weka/go-cloud-lib/lib/strings"
	"github.com/weka/go-cloud-lib/lib/types"
	"github.com/weka/go-cloud-lib/protocol"
	"os"
	"time"
)

type instancesMap map[string]*ec2.Instance

func getInstancePrivateIpsSet(scaleResponse protocol.ScaleResponse) common.InstancePrivateIpsSet {
	instancePrivateIpsSet := make(common.InstancePrivateIpsSet)
	for _, instance := range scaleResponse.Hosts {
		instancePrivateIpsSet[instance.PrivateIp] = types.Nilv
	}
	return instancePrivateIpsSet
}

func instancesToMap(instances []*ec2.Instance) instancesMap {
	im := make(instancesMap)
	for _, instance := range instances {
		im[*instance.InstanceId] = instance
	}
	return im
}

func getDeltaInstancesIds(asgInstanceIds []*string, scaleResponse protocol.ScaleResponse) (deltaInstanceIDs []*string, err error) {
	asgInstances, err := common.GetInstances(asgInstanceIds)
	if err != nil {
		return
	}
	instancePrivateIpsSet := getInstancePrivateIpsSet(scaleResponse)

	for _, instance := range asgInstances {
		if instance.PrivateIpAddress == nil {
			continue
		}
		if _, ok := instancePrivateIpsSet[*instance.PrivateIpAddress]; !ok {
			deltaInstanceIDs = append(deltaInstanceIDs, instance.InstanceId)
		}
	}
	return
}

func removeAutoScalingProtection(asgName string, instanceIds []string) error {
	svc := connectors.GetAWSSession().ASG
	_, err := svc.SetInstanceProtection(&autoscaling.SetInstanceProtectionInput{
		AutoScalingGroupName: &asgName,
		InstanceIds:          strings.ListToRefList(instanceIds),
		ProtectedFromScaleIn: aws.Bool(false),
	})
	if err != nil {
		return err
	}
	return nil
}

func setForExplicitRemoval(instance *ec2.Instance, toRemove []protocol.HgInstance) bool {
	for _, i := range toRemove {
		if *instance.PrivateIpAddress == i.PrivateIp && *instance.InstanceId == i.Id {
			return true
		}
	}
	return false
}

func terminateInstances(instanceIds []string) (terminatingInstances []string, err error) {
	svc := connectors.GetAWSSession().EC2
	log.Info().Msgf("Terminating instances %s", instanceIds)
	res, err := svc.TerminateInstances(&ec2.TerminateInstancesInput{
		InstanceIds: strings.ListToRefList(instanceIds),
	})
	if err != nil {
		log.Error().Msgf("error terminating instances %s", err.Error())
		return
	}
	for _, terminatingInstance := range res.TerminatingInstances {
		terminatingInstances = append(terminatingInstances, *terminatingInstance.InstanceId)
	}
	return
}

func terminateUnneededInstances(asgName string, instances []*ec2.Instance, explicitRemoval []protocol.HgInstance) (terminated []*ec2.Instance, errs []error) {
	terminateInstanceIds := make([]string, 0, 0)
	imap := instancesToMap(instances)

	for _, instance := range instances {
		if !setForExplicitRemoval(instance, explicitRemoval) {
			if time.Now().Sub(*instance.LaunchTime) < time.Minute*30 {
				continue
			}
		}
		instanceState := *instance.State.Name
		if instanceState != ec2.InstanceStateNameShuttingDown && instanceState != ec2.InstanceStateNameTerminated {
			terminateInstanceIds = append(terminateInstanceIds, *instance.InstanceId)
		}
	}

	terminatedInstances, errs := terminateAsgInstances(asgName, terminateInstanceIds)

	for _, id := range terminatedInstances {
		terminated = append(terminated, imap[id])
	}
	return
}

func terminateAsgInstances(asgName string, terminateInstanceIds []string) (terminatedInstances []string, errs []error) {
	if len(terminateInstanceIds) == 0 {
		return
	}
	setToTerminate, errs := common.SetDisableInstancesApiTermination(
		terminateInstanceIds[:common.Min(len(terminateInstanceIds), 50)],
		false,
	)

	err := removeAutoScalingProtection(asgName, setToTerminate)
	if err != nil {
		// WARNING: This is debatable if error here is transient or not
		//	Specifically now we can return empty list of what we were able to terminate because this API call failed
		//   But in future with adding more lambdas into state machine this might become wrong decision
		log.Error().Err(err)
		setToTerminate = setToTerminate[:0]
		errs = append(errs, err)
	}

	terminatedInstances, err = terminateInstances(setToTerminate)
	if err != nil {
		log.Error().Err(err)
		errs = append(errs, err)
		return
	}
	return
}

func Handler(scaleResponse protocol.ScaleResponse) (response protocol.TerminatedInstancesResponse, err error) {
	response.Version = protocol.Version

	if scaleResponse.Version != protocol.Version {
		err = errors.New("incompatible scale response version")
		return
	}

	asgName := os.Getenv("ASG_NAME")
	if asgName == "" {
		err = errors.New("ASG_NAME env var is mandatory")
		return
	}
	response.TransientErrors = scaleResponse.TransientErrors[0:len(scaleResponse.TransientErrors):len(scaleResponse.TransientErrors)]

	asgInstances, err := common.GetASGInstances(asgName)
	asgInstanceIds := common.UnpackASGInstanceIds(asgInstances)
	log.Info().Msgf("Found %d instances on ASG", len(asgInstanceIds))
	if err != nil {
		return
	}

	errs := detachUnhealthyInstances(asgInstances, asgName)
	if len(errs) != 0 {
		response.AddTransientErrors(errs)
	}

	deltaInstanceIds, err := getDeltaInstancesIds(asgInstanceIds, scaleResponse)
	if err != nil {
		return
	}

	if len(deltaInstanceIds) == 0 {
		log.Info().Msgf("No delta instances ids")
		return
	} else {
		log.Info().Msgf("Delta instances: %s", strings.RefListToList(deltaInstanceIds))
	}

	candidatesToTerminate, err := common.GetInstances(deltaInstanceIds)
	if err != nil {
		return
	}

	terminatedInstances, errs := terminateUnneededInstances(asgName, candidatesToTerminate, scaleResponse.ToTerminate)
	response.AddTransientErrors(errs)

	//detachTerminated(asgName)

	for _, instance := range terminatedInstances {
		response.Instances = append(response.Instances, protocol.TerminatedInstance{
			InstanceId: *instance.InstanceId,
			Creation:   *instance.LaunchTime,
		})
	}

	return
}

func detachUnhealthyInstances(instances []*autoscaling.Instance, asgName string) (errs []error) {
	toDetach := []string{}
	toTerminate := []string{}
	for _, instance := range instances {
		if *instance.HealthStatus == "Unhealthy" {
			log.Info().Msgf("handling unhealthy instance %s", *instance.InstanceId)
			toDelete := false
			if !*instance.ProtectedFromScaleIn {
				toDelete = true
			}

			if !toDelete {
				instances, ec2err := common.GetInstances([]*string{instance.InstanceId})
				if ec2err != nil {
					errs = append(errs, ec2err)
					continue
				}
				if len(instances) == 0 {
					log.Debug().Msgf("didn't find instance %s, assuming it is terminated", *instance.InstanceId)
					toDelete = true
				} else {
					inst := instances[0]
					log.Debug().Msgf("instance state: %s", *inst.State.Name)
					if *inst.State.Name == ec2.InstanceStateNameStopped {
						toTerminate = append(toTerminate, *inst.InstanceId)
					}
					if *inst.State.Name == ec2.InstanceStateNameTerminated {
						toDelete = true
					}
				}

			}
			if toDelete {
				if *instance.LifecycleState == autoscaling.LifecycleStateStandby ||
					*instance.LifecycleState == autoscaling.LifecycleStateInService {
					log.Info().Msgf("detaching %s", *instance.InstanceId)
					toDetach = append(toDetach, *instance.InstanceId)
				}

			}
		}
	}

	log.Debug().Msgf("found %d stopped instances", len(toTerminate))
	terminatedInstances, terminateErrors := terminateAsgInstances(asgName, toTerminate)
	errs = append(errs, terminateErrors...)
	for _, inst := range terminatedInstances {
		log.Info().Msgf("detaching %s", inst)
		toDetach = append(toDetach, inst)
	}

	if len(toDetach) == 0 {
		return nil
	}

	err := common.DetachInstancesFromASG(toDetach, asgName)
	if err != nil {
		errs = append(errs, err)
	}
	return
}
