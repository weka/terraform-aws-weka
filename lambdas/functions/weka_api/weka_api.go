package weka_api

import (
	"context"
	"fmt"
	"github.com/rs/zerolog/log"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/common"
	"github.com/weka/aws-tf/modules/deploy_weka/lambdas/functions/management"
	"github.com/weka/go-cloud-lib/logging"
	"os"
	"strconv"
)

func MakeWekaApiRequest[T any](ctx context.Context, wr *management.WekaApiRequest) (response *T, err error) {
	logger := logging.LoggerFromCtx(ctx)
	logger.Debug().Msg("MakeWekaApiRequest > Start")

	r, err := invokeManagementLambda[T](ctx, wr)
	if err != nil {
		return nil, fmt.Errorf("MakeWekaApiRequest > lambda invocation failed: %v", err)
	}
	return r, nil
}

func invokeManagementLambda[T any](ctx context.Context, wr *management.WekaApiRequest) (response *T, err error) {
	logger := logging.LoggerFromCtx(ctx)
	logger.Debug().Msg("invokeManagementLambda > Start")
	logger.Info().Msgf("invokeManagementLambda > Params: %s", wr.Params)

	managementLambdaName := os.Getenv("MANAGEMENT_LAMBDA")
	if managementLambdaName == "" {
		return nil, fmt.Errorf("MANAGEMENT_LAMBDA is not set")
	}
	if wr.Method == "" {
		return nil, fmt.Errorf("weka-api method is not set")
	}

	useSecretManagerEndpoint, err := strconv.ParseBool(os.Getenv("USE_SECRETMANAGER_ENDPOINT"))
	if err != nil {
		log.Warn().Msg("Failed to parse USE_SECRETMANAGER_ENDPOINT, assuming false")
	}
	var username, password string
	if !useSecretManagerEndpoint {
		log.Info().Msg("Secret manager endpoint not in use, sending credentials in body")
		usernameId := os.Getenv("USERNAME_ID")
		deploymentPasswordId := os.Getenv("DEPLOYMENT_PASSWORD_ID")
		adminPasswordId := os.Getenv("ADMIN_PASSWORD_ID")
		creds, err := common.GetDeploymentOrAdminUsernameAndPassword(usernameId, deploymentPasswordId, adminPasswordId)
		if err != nil {
			return nil, fmt.Errorf("invokeManagementLambda > GetDeploymentOrAdminUsernameAndPassword: %w", err)
		}

		username = creds.Username
		password = creds.Password
	}

	clusterName := os.Getenv("CLUSTER_NAME")
	if clusterName == "" {
		return nil, fmt.Errorf("CLUSTER_NAME is not set")
	}
	ips, err := common.GetBackendsPrivateIps(clusterName, "backend")
	if err != nil {
		return nil, fmt.Errorf("invokeManagementLambda > GetBackendsPrivateIps: %w", err)
	}
	log.Info().Msgf("invokeManagementLambda > Backend private IPs: %v", ips)

	logger.Debug().Msgf("invokeManagementLambda > Username: %s", username)

	managementRequest := management.ManagementRequest{
		WekaApiRequest: management.WekaApiRequest{
			Method: wr.Method,
			Params: wr.Params,
		},
		BackendPrivateIps: ips,
		Username:          username,
		Password:          password, // empty string is interpreted as no credentials
	}

	response, err = common.InvokeLambdaFunction[T](managementLambdaName, managementRequest)
	if err != nil {
		wrappedError := fmt.Errorf("invokeManagementLambda >: %w", err)
		log.Error().Err(wrappedError).Send()
	}

	return response, nil

}
