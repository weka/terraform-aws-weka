package report

import (
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/go-cloud-lib/protocol"
	reportLib "github.com/weka/go-cloud-lib/report"
)

func Report(report protocol.Report, stateTable, hashKey string) (err error) {
	log.Info().Msgf("Updating state %s with %s", report.Type, report.Message)

	err = common.LockState(stateTable, hashKey)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	state, err := common.GetClusterStateWithoutLock(stateTable, hashKey)
	if err != nil {
		return
	}
	err = reportLib.UpdateReport(report, &state)
	if err != nil {
		return
	}
	err = common.UpdateClusterState(stateTable, hashKey, state)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	err = common.UnlockState(stateTable, hashKey)
	if err != nil {
		log.Error().Err(err).Send()
	}
	return
}
