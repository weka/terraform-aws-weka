package aws_functions_def

import (
	"fmt"
	"os"

	"github.com/lithammer/dedent"
	"github.com/weka/go-cloud-lib/functions_def"
)

type AWSFuncDef struct {
	region             string
	lambdaNamesMapping map[functions_def.FunctionName]string
}

func NewFuncDef() functions_def.FunctionDef {
	region := os.Getenv("REGION")
	mapping := map[functions_def.FunctionName]string{
		functions_def.Clusterize:             os.Getenv("CLUSTERIZE_LAMBDA_NAME"),
		functions_def.ClusterizeFinalization: os.Getenv("CLUSTERIZE_FINALIZATION_LAMBDA_NAME"),
		functions_def.Deploy:                 os.Getenv("DEPLOY_LAMBDA_NAME"),
		functions_def.Report:                 os.Getenv("REPORT_LAMBDA_NAME"),
		functions_def.Join:                   os.Getenv("JOIN_LAMBDA_NAME"),
		functions_def.JoinFinalization:       os.Getenv("JOIN_FINALIZATION_LAMBDA_NAME"),
		functions_def.JoinNfsFinalization:    os.Getenv("JOIN_NFS_FINALIZATION_LAMBDA_NAME"),
		functions_def.Fetch:                  os.Getenv("FETCH_LAMBDA_NAME"),
		functions_def.Status:                 os.Getenv("STATUS_LAMBDA_NAME"),
	}
	return &AWSFuncDef{lambdaNamesMapping: mapping, region: region}
}

// each function takes json payload as an argument
// e.g. "{\"hostname\": \"$HOSTNAME\", \"type\": \"$message_type\", \"message\": \"$message\"}"
func (d *AWSFuncDef) GetFunctionCmdDefinition(name functions_def.FunctionName) string {
	lambdaName, ok := d.lambdaNamesMapping[name]
	var funcDef string
	if !ok {
		funcDefTemplate := `
		function %s {
			echo "%s function is not supported"
		}
		`
		funcDef = fmt.Sprintf(funcDefTemplate, name, name)
	} else if lambdaName == "" {
		funcDefTemplate := `
		function %s {
			echo "%s function is not implemented"
		}
		`
		funcDef = fmt.Sprintf(funcDefTemplate, name, name)
	} else {
		// NOTE: here we have kind of a hack to clean the output from the lambda invoke command
		//
		// The invoke is retried on a flat interval because amazon-ec2-net-utils reconfigures
		// the primary NIC whenever the ENI's IP set changes (e.g. when WEKA assigns
		// interface-group floating IPs). That briefly drops the route to 169.254.169.254, and
		// the AWS CLI then exits 253 with "Unable to locate credentials". The observed gap is
		// ~1-2s, so a flat 3s retry clears it on the first attempt. Each IP add is its own
		// reconfigure and the IPs are assigned incrementally, so several gaps can land back
		// to back -- the ~1min ceiling is sized for a burst of them, not for a single gap.
		//
		// Only rc 253 (credentials/config could not be resolved -- exactly the IMDS route gap)
		// and rc 255 (catch-all, covers a connection error to the lambda endpoint during the
		// same gap) are retried. 252 (bad syntax) and 254 (service returned an error) are
		// deterministic, so they surface immediately rather than burning the full ~1min
		// re-issuing a call that cannot succeed.
		funcDefTemplate := `
		function %s {
			local json_data=$1
			aws_version=$(aws --version)
			cli_binary_format=""
			if [[ "$aws_version" == aws-cli/2* ]]; then
				cli_binary_format="--cli-binary-format raw-in-base64-out"
			fi
			local attempt=1 max_attempts=20 retry_delay=3 rc=0
			until aws lambda invoke --region %s --function-name %s $cli_binary_format --payload "$json_data" output >/dev/null; do
				rc=$?
				if [ "$rc" -ne 253 ] && [ "$rc" -ne 255 ]; then
					echo "$FUNCNAME: lambda invoke failed with rc=$rc, not a transient credential/connection error - not retrying" >&2
					return $rc
				fi
				if [ "$attempt" -ge "$max_attempts" ]; then
					echo "$FUNCNAME: lambda invoke failed after $max_attempts attempts (rc=$rc)" >&2
					return $rc
				fi
				echo "$FUNCNAME: lambda invoke failed (rc=$rc), retrying in $retry_delay seconds (attempt $attempt/$max_attempts)" >&2
				sleep "$retry_delay"
				attempt=$(( attempt + 1 ))
			done
			printf "%%b" "$(cat output | sed 's/^"//' | sed 's/"$//' | sed 's/\\\"/"/g')"
		}
		`
		funcDef = fmt.Sprintf(funcDefTemplate, name, d.region, lambdaName)
	}
	return dedent.Dedent(funcDef)
}
