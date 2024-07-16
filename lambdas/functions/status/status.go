package status

import (
	"context"
	"encoding/json"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	cloudLibCommon "github.com/weka/go-cloud-lib/common"
	"github.com/weka/go-cloud-lib/connectors"
	"github.com/weka/go-cloud-lib/lib/jrpc"
	strgins2 "github.com/weka/go-cloud-lib/lib/strings"
	"github.com/weka/go-cloud-lib/lib/weka"
	"github.com/weka/go-cloud-lib/logging"
	"github.com/weka/go-cloud-lib/protocol"
	"math/rand"
	"strings"
	"time"
)

func hostnameToIp(hostname string) string {
	return strings.Replace(strings.TrimLeft(strings.Split(hostname, ".")[0], "ip-"), "-", ".", -1)
}

func GetReports(ctx context.Context, stateTable, hashKey, stateKey, clusterName, hostGroup string) (reports protocol.Reports, err error) {
	logger := logging.LoggerFromCtx(ctx)
	logger.Info().Msg("fetching cluster progress status...")

	state, err := common.GetClusterStateWithoutLock(stateTable, hashKey, stateKey)
	if err != nil {
		return
	}
	reports.ReadyForClusterization = common.GetInstancesNames(state.Instances)
	reports.Progress = state.Progress
	reports.Errors = state.Errors

	clusterizationInstance := ""
	if state.ClusterizationTarget > 0 && len(state.Instances) >= state.ClusterizationTarget {
		clusterizationInstance = state.Instances[state.ClusterizationTarget-1].Name
	}

	var inProgress []string

	if !state.Clusterized {
		ips, err2 := common.GetBackendsPrivateIps(clusterName, hostGroup)
		if err2 != nil {
			err = err2
			return
		}

		var readyForClusterizationIps []string
		if len(reports.ReadyForClusterization) > 0 {
			instances, err2 := common.GetInstances(strgins2.ListToRefList(reports.ReadyForClusterization))
			if err2 != nil {
				err = err2
				return
			}

			for _, instance := range instances {
				if instance.PrivateIpAddress != nil {
					readyForClusterizationIps = append(readyForClusterizationIps, *instance.PrivateIpAddress)
				}
			}
		}

		for instance := range state.Progress {
			if !cloudLibCommon.IsItemInList(hostnameToIp(instance), readyForClusterizationIps) && cloudLibCommon.IsItemInList(hostnameToIp(instance), ips) {
				inProgress = append(inProgress, instance)
			}
		}
	}

	reports.InProgress = inProgress

	summary := protocol.ClusterizationStatusSummary{
		ReadyForClusterization: len(state.Instances),
		InProgress:             len(inProgress),
		ClusterizationInstance: clusterizationInstance,
		ClusterizationTarget:   state.ClusterizationTarget,
		Clusterized:            state.Clusterized,
	}

	reports.Summary = summary

	return
}

func GetClusterStatus(ctx context.Context, stateTableName, tableHashKey, stateKey, clusterName, passwordId string) (clusterStatus protocol.ClusterStatus, err error) {
	logger := logging.LoggerFromCtx(ctx)
	logger.Info().Msg("fetching cluster status...")

	state, err := common.GetClusterStateWithoutLock(stateTableName, tableHashKey, stateKey)
	if err != nil {
		return
	}
	clusterStatus.InitialSize = state.InitialSize
	clusterStatus.DesiredSize = state.DesiredSize
	clusterStatus.Clusterized = state.Clusterized

	if !state.Clusterized {
		return
	}

	creds, err := common.GetWekaAdminCredentials(passwordId)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	log.Info().Msgf("Fetched weka cluster creds successfully")

	jrpcBuilder := func(ip string) *jrpc.BaseClient {
		return connectors.NewJrpcClient(ctx, ip, weka.ManagementJrpcPort, creds.Username, creds.Password)
	}

	ips, err := common.GetBackendsPrivateIps(clusterName, "backend")
	if err != nil {
		return
	}

	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	r.Shuffle(len(ips), func(i, j int) { ips[i], ips[j] = ips[j], ips[i] })
	logger.Info().Msgf("ips: %s", ips)
	jpool := &jrpc.Pool{
		Ips:     ips,
		Clients: map[string]*jrpc.BaseClient{},
		Active:  "",
		Builder: jrpcBuilder,
		Ctx:     ctx,
	}

	var rawWekaStatus json.RawMessage

	err = jpool.Call(weka.JrpcStatus, struct{}{}, &rawWekaStatus)
	if err != nil {
		return
	}

	wekaStatus := protocol.WekaStatus{}
	if err = json.Unmarshal(rawWekaStatus, &wekaStatus); err != nil {
		return
	}
	clusterStatus.WekaStatus = wekaStatus

	return
}
