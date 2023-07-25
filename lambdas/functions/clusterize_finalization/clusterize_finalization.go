package clusterize_finalization

import (
	"fmt"

	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
)

func ClusterizeFinalization(table, hashKey string) (err error) {
	err = common.LockState(table, hashKey)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	err = doClusterizeFinalization(table, hashKey)

	unlockErr := common.UnlockState(table, hashKey)
	if unlockErr != nil {
		// expand existing error
		err = fmt.Errorf("%v; %v", err, unlockErr)
	}

	if err != nil {
		log.Error().Err(err).Send()
	}
	return
}

func doClusterizeFinalization(table, hashKey string) (err error) {
	state, err := common.GetClusterStateWithoutLock(table, hashKey)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	state.Instances = []string{}
	state.Clusterized = true
	err = common.UpdateClusterState(table, hashKey, state)
	return
}
