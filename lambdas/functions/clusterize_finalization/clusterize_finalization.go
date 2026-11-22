package clusterize_finalization

import (
	"context"

	"github.com/weka/go-cloud-lib/protocol"

	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
)

func ClusterizeFinalization(ctx context.Context, table, hashKey, stateKey string) (err error) {
	_, err = common.UpdateClusterState(ctx, table, hashKey, stateKey, func(state *protocol.ClusterState) error {
		state.Instances = []protocol.Vm{}
		state.Clusterized = true
		return nil
	})
	if err != nil {
		log.Error().Err(err).Send()
	}
	return
}
