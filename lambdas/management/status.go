package management

import (
	"context"
	"fmt"

	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/go-cloud-lib/connectors"
	"github.com/weka/go-cloud-lib/lib/jrpc"
	"github.com/weka/go-cloud-lib/lib/weka"
	"github.com/weka/go-cloud-lib/logging"
	"github.com/weka/go-cloud-lib/protocol"
)

type StatusRequest struct {
	DeploymentUsernameId string   `json:"username_id"`
	DeploymentPasswordId string   `json:"password_id"`
	AdminPasswordId      string   `json:"admin_password_id"`
	BackendPrivateIps    []string `json:"backend_private_ips"`
}

// ManagementRequest is the request object for the management lambda
// The operation to be performed is specified in the Type field.  The specific
// operation payload is in the StatusRequest field. The convention here is that
// each type value should have a corresponding embedded struct that contains
// the payload for that specific operation.
//
// At this time, the only operation supported is "status"
type ManagementRequest struct {
	Type string `json:"type"`

	StatusRequest
}

func GetWekaStatus(ctx context.Context, request StatusRequest) (protocol.WekaStatus, error) {
	logger := logging.LoggerFromCtx(ctx)
	logger.Debug().Msg("GetWekaStatus > Start")

	usernameId := request.DeploymentUsernameId
	if usernameId == "" {
		return protocol.WekaStatus{}, fmt.Errorf("management.Status - username id is empty")
	}
	passwordId := request.DeploymentPasswordId
	if passwordId == "" {
		return protocol.WekaStatus{}, fmt.Errorf("management.Status - password id is empty")
	}
	adminPasswordId := request.AdminPasswordId
	if adminPasswordId == "" {
		return protocol.WekaStatus{}, fmt.Errorf("management.Status - admin password id is empty")
	}
	credentials, err := common.GetDeploymentOrAdminUsernameAndPassword(usernameId, passwordId, adminPasswordId)
	if err != nil {
		return protocol.WekaStatus{}, fmt.Errorf("management.Status - get username and password > %w", err)
	}
	username := credentials.Username
	password := credentials.Password
	logger.Debug().Msgf("GetWekaStatus > Username: %s", username)
	jrpcBuilder := func(ip string) *jrpc.BaseClient {
		return connectors.NewJrpcClient(ctx, ip, weka.ManagementJrpcPort, username, password)
	}

	ips := request.BackendPrivateIps
	if len(ips) == 0 {
		return protocol.WekaStatus{}, fmt.Errorf("management.Status - backend private ips are empty")
	}
	logger.Debug().Msgf("GetWekaStatus > BackendPrivateIps: %v", ips)
	jpool := &jrpc.Pool{
		Ips:     ips,
		Clients: map[string]*jrpc.BaseClient{},
		Active:  "",
		Builder: jrpcBuilder,
		Ctx:     ctx,
	}

	systemStatus := protocol.WekaStatus{}
	err = jpool.Call(weka.JrpcStatus, struct{}{}, &systemStatus)
	if err != nil {
		return protocol.WekaStatus{}, fmt.Errorf("management.Status - call SystemStatus > %w", err)
	}
	return systemStatus, nil
}
