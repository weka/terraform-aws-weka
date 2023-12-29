package status

import (
	"context"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/go-cloud-lib/logging"

	"github.com/weka/go-cloud-lib/protocol"
)

func GetReports(ctx context.Context, stateTable, hashKey, stateKey string) (reports protocol.Reports, err error) {
	logger := logging.LoggerFromCtx(ctx)
	logger.Info().Msg("fetching cluster progress status...")

	state, err := common.GetClusterStateWithoutLock(stateTable, hashKey, stateKey)
	if err != nil {
		return
	}
	reports.ReadyForClusterization = common.GetInstancesNames(state.Instances)
	reports.Progress = state.Progress
	reports.Errors = state.Errors

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
