package report

import (
	"fmt"

	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/go-cloud-lib/protocol"
	reportLib "github.com/weka/go-cloud-lib/report"
)

func Report(report protocol.Report, stateTable, hashKey, stateKey string) (err error) {
	log.Info().Msgf("Updating state %s with %s", report.Type, report.Message)

	err = common.LockState(stateTable, hashKey, stateKey)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	state, err := common.GetClusterStateWithoutLock(stateTable, hashKey, stateKey)
	if err != nil {
		return
	}
	err = reportLib.UpdateReport(report, &state)
	if err != nil {
		return
	}
	err = common.UpdateClusterState(stateTable, hashKey, stateKey, state)

	unlockErr := common.UnlockState(stateTable, hashKey, stateKey)
	if unlockErr != nil {
		// expand existing error
		err = fmt.Errorf("%v; %v", err, unlockErr)
	}

	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	return
}
