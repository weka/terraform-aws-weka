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
		functions_def.Clusterize:              os.Getenv("CLUSTERIZE_LAMBDA_NAME"),
		functions_def.ClusterizeFinalizaition: os.Getenv("CLUSTERIZE_FINALIZATION_LAMBDA_NAME"),
		functions_def.Deploy:                  os.Getenv("DEPLOY_LAMBDA_NAME"),
		functions_def.Report:                  os.Getenv("REPORT_LAMBDA_NAME"),
		functions_def.Join:                    os.Getenv("JOIN_LAMBDA_NAME"),
		functions_def.JoinFinalization:        os.Getenv("JOIN_FINALIZATION_LAMBDA_NAME"),
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
		funcDefTemplate := `
		function %s {
			local json_data=$1
			res=$(aws lambda invoke --region %s --function-name %s --payload "$json_data" output)
			printf "%%b" "$(cat output | sed 's/^"//' | sed 's/"$//' | sed 's/\\\"/"/g')"
		}
		`
		funcDef = fmt.Sprintf(funcDefTemplate, name, d.region, lambdaName)
	}
	return dedent.Dedent(funcDef)
}
