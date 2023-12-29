package clusterize_finalization

import (
	"fmt"
	"github.com/weka/go-cloud-lib/protocol"

	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
)

func ClusterizeFinalization(table, hashKey, stateKey string) (err error) {
	err = common.LockState(table, hashKey, stateKey)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	err = doClusterizeFinalization(table, hashKey, stateKey)

	unlockErr := common.UnlockState(table, hashKey, stateKey)
	if unlockErr != nil {
		// expand existing error
		err = fmt.Errorf("%v; %v", err, unlockErr)
	}

	if err != nil {
		log.Error().Err(err).Send()
	}
	return
}

func doClusterizeFinalization(table, hashKey, stateKey string) (err error) {
	state, err := common.GetClusterStateWithoutLock(table, hashKey, stateKey)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	state.Instances = []protocol.Vm{}
	state.Clusterized = true
	err = common.UpdateClusterState(table, hashKey, stateKey, state)
	return
}
