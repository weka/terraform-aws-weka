package clusterize_finalization

import (
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
)

func ClusterizeFinalization(table, hashKey string) (err error) {
	err = common.LockState(table, hashKey)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	state, err := common.GetClusterStateWithoutLock(table, hashKey)
	if err != nil {
		return
	}
	state.Instances = []string{}
	state.Clusterized = true
	err = common.UpdateClusterState(table, hashKey, state)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	err = common.UnlockState(table, hashKey)
	if err != nil {
		log.Error().Err(err).Send()
	}
	return
}
