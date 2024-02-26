# pd - Simple Web-App

Tis repository deploys the following in your AWS account:
- S3 bucket with your assets deployed in a single region
- IAM instance profile for the Web-App EC2 instances so they can access your assets bucket
- 3-region WebApp infrastructure components

## Table of Contents

- [Design Overview](#design)
- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
- [ToDo](#todo)

## Design Overview

![Image Alt Text](design/web-app.jpg)

## Prerequisites

1. Ensure you install [sam-cli](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html) for the deployment to work

2. Ensure you have [aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed as you will need it in order to create EC2 keys if you want to debug any issues with your webservers

3. Currently the template deploys one EC2 key pair per region but this can't be done through the template. Run the followiing command to create EC2 keys for each region:
`aws ec2 create-key-pair --key-name webapp-${aws_region} --query 'KeyMaterial' --output text > webapp-${aws_region}.pem --region ${aws_region}`. Since the updated template has required SSM permissions, we could also remove the following line from the `web-app-infra.yml` template:
```
...
KeyName: !Sub webapp-${AWS::Region}
...
```
and rely on the new IAM policy with `Sid`: `SSMProfile` to connect to our instance through FleetManager or through the EC2 console, selecting SSM from the connection options.

## Deployment

**NOTE**
Before attempting to deploy, ensure you have loaded the correct AWS profile in `~/.aws/credentials`. You can either expand account mapping section on the `Makefile` or set (export) the `AWS_ACCOUNT_ID` variable appropriately and pass it as a parameter to `Make`.

We use a `Makefile` to install dependencies, lint CloudFormation templates for any issues and also deploy our Web-App to the AWS envronment.

Installing dependencies:
- `make install`

Linting:
- `make lint`

Deploy only Dev environment:
- `make deploy_dev`

Deploy only Prod environment:
- `make deploy_prod`

Deploy both Dev & Prod environments:
- `make deploy_all`

## ToDo

- Apply AWS WAF in front of the ALB
- Remove the EC2 keys and rely on SSM to connect to your instances
- Enable VPC Flows for all the VPC's
- Create a Patch Baseline through SSM Patch Manager to ensure the webservers are patched with teh latest patches
- Use Route53 to register a domain for the `Dev` and `Prod` stacks and ensure you create appropriate **Alias** records
- Adjust the AutoScaling `MinSize` and `MaxSize` through the Mapping section to ensure best cost savings for the `Dev` environment
- Adjust the instance type to ensure cost is kept at a minimum for `Dev` but performance is better for `Prod`
