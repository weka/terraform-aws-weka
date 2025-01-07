package management

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/weka/go-cloud-lib/connectors"
	"github.com/weka/go-cloud-lib/lib/jrpc"
	"github.com/weka/go-cloud-lib/lib/weka"
	"github.com/weka/go-cloud-lib/logging"
)

type WekaApiRequest struct {
	Method weka.JrpcMethod   `json:"method"`
	Params map[string]string `json:"params"`
}

type ManagementRequest struct {
	WekaApiRequest

	Username          string   `json:"username"`
	Password          string   `json:"password"`
	BackendPrivateIps []string `json:"backend_private_ips"`
}

func CallJRPC(ctx context.Context, request ManagementRequest) (json.RawMessage, error) {
	logger := logging.LoggerFromCtx(ctx)
	logger.Debug().Msg("CallJRPC > Start")
	logger.Info().Msgf("CallJRPC > method %s", request.Method)

	var jrpcResponse json.RawMessage

	logger.Debug().Msgf("CallJRPC > Username: %s", request.Username)
	jrpcBuilder := func(ip string) *jrpc.BaseClient {
		return connectors.NewJrpcClient(ctx, ip, weka.ManagementJrpcPort, request.Username, request.Password)
	}

	ips := request.BackendPrivateIps
	if len(ips) == 0 {
		return nil, fmt.Errorf("CallJRPC - backend private ips are empty")
	}
	logger.Debug().Msgf("CallJRPC > BackendPrivateIps: %v", ips)

	var params interface{}
	if request.Params != nil {
		params = request.Params
	} else {
		params = struct{}{}
	}

	jpool := &jrpc.Pool{
		Ips:     ips,
		Clients: map[string]*jrpc.BaseClient{},
		Active:  "",
		Builder: jrpcBuilder,
		Ctx:     ctx,
	}

	if err := jpool.Call(request.Method, params, &jrpcResponse); err != nil {
		return nil, fmt.Errorf("CallJRPC - call [%s] failed > %w", request.Method, err)
	}
	return jrpcResponse, nil
}
