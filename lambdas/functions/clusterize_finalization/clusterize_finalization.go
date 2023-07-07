package clusterize_finalization

import (
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/cloud-functions/common"
)

func ClusterizeFinalization(bucket string) (err error) {
	err = common.LockState(bucket)
	if err != nil {
		log.Error().Err(err).Send()
	}

	state, err := common.GetClusterState(bucket)
	if err != nil {
		return
	}
	state.Instances = []string{}
	state.Clusterized = true
	err = common.UpdateClusterState(bucket, state)

	err = common.UnlockState(bucket)
	if err != nil {
		log.Error().Err(err).Send()
	}
	return
}
