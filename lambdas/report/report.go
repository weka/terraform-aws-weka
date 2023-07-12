package report

import (
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/go-cloud-lib/protocol"
	reportLib "github.com/weka/go-cloud-lib/report"
)

func Report(report protocol.Report, bucket string) (err error) {
	log.Info().Msgf("Updating state %s with %s", report.Type, report.Message)
	state, err := common.GetClusterState(bucket)
	if err != nil {
		return
	}
	err = reportLib.UpdateReport(report, &state)
	if err != nil {
		return
	}
	err = common.UpdateClusterState(bucket, state)
	return
}
