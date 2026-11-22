package report

import (
	"context"

	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/go-cloud-lib/protocol"
	reportLib "github.com/weka/go-cloud-lib/report"
)

func Report(ctx context.Context, report protocol.Report, stateTable, hashKey, stateKey string) (err error) {
	log.Info().Msgf("Updating state %s with %s", report.Type, report.Message)

	_, err = common.UpdateClusterState(ctx, stateTable, hashKey, stateKey, func(state *protocol.ClusterState) error {
		return reportLib.UpdateReport(report, state)
	})
	if err != nil {
		log.Error().Err(err).Send()
	}
	return
}
