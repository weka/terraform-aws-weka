package status

import (
	"context"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	cloudLibCommon "github.com/weka/go-cloud-lib/common"
	strgins2 "github.com/weka/go-cloud-lib/lib/strings"
	"github.com/weka/go-cloud-lib/logging"
	"github.com/weka/go-cloud-lib/protocol"
	"strings"
)

func hostnameToIp(hostname string) string {
	return strings.Replace(strings.TrimLeft(strings.Split(hostname, ".")[0], "ip-"), "-", ".", -1)
}

func GetReports(ctx context.Context, stateTable, hashKey, stateKey, clusterName, hostGroup string) (reports protocol.Reports, err error) {
	logger := logging.LoggerFromCtx(ctx)
	logger.Info().Msg("fetching cluster progress status...")

	state, err := common.GetClusterStateWithoutLock(stateTable, hashKey, stateKey)
	if err != nil {
		return
	}
	reports.ReadyForClusterization = common.GetInstancesNames(state.Instances)
	reports.Progress = state.Progress
	reports.Errors = state.Errors

	clusterizationInstance := ""
	if state.ClusterizationTarget > 0 && len(state.Instances) >= state.ClusterizationTarget {
		clusterizationInstance = state.Instances[state.ClusterizationTarget-1].Name
	}

	var inProgress []string

	if !state.Clusterized {
		ips, err2 := common.GetBackendsPrivateIps(clusterName, hostGroup)
		if err2 != nil {
			err = err2
			return
		}

		var readyForClusterizationIps []string
		if len(reports.ReadyForClusterization) > 0 {
			instances, err2 := common.GetInstances(strgins2.ListToRefList(reports.ReadyForClusterization))
			if err2 != nil {
				err = err2
				return
			}

			for _, instance := range instances {
				if instance.PrivateIpAddress != nil {
					readyForClusterizationIps = append(readyForClusterizationIps, *instance.PrivateIpAddress)
				}
			}
		}

		for instance := range state.Progress {
			if !cloudLibCommon.IsItemInList(hostnameToIp(instance), readyForClusterizationIps) && cloudLibCommon.IsItemInList(hostnameToIp(instance), ips) {
				inProgress = append(inProgress, instance)
			}
		}
	}

	reports.InProgress = inProgress

	summary := protocol.ClusterizationStatusSummary{
		ReadyForClusterization: len(state.Instances),
		InProgress:             len(inProgress),
		ClusterizationInstance: clusterizationInstance,
		ClusterizationTarget:   state.ClusterizationTarget,
		Clusterized:            state.Clusterized,
	}

	reports.Summary = summary

	return
}

func GetClusterStatus(ctx context.Context, stateTableName, tableHashKey, stateKey string) (clusterStatus protocol.ClusterStatus, err error) {
	logger := logging.LoggerFromCtx(ctx)
	logger.Info().Msg("fetching cluster status...")

	state, err := common.GetClusterStateWithoutLock(stateTableName, tableHashKey, stateKey)
	if err != nil {
		return
	}
	clusterStatus.InitialSize = state.InitialSize
	clusterStatus.DesiredSize = state.DesiredSize
	clusterStatus.Clusterized = state.Clusterized

	return
}
