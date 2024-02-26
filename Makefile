SHELL:=/usr/bin/env bash
AWS_ACCOUNT_ID := $(shell pipenv run aws sts get-caller-identity --query "Account" --output text)
DEFAULT_AWS_REGION := us-east-2 # IAM resources and App's S3 bucket is deployed here
# APP_REGIONS := us-east-2 eu-west-1 # ap-southeast-4 # Current App supported regions
APP_REGIONS := us-east-2 eu-west-1
IAM_STACK_NAME := iam
S3_STACK_NAME := s3
WEBAPP_INFRA_STACK_NAME := web-app-infra
TAGS += repo="pd-app" service="pd"
DEV_TAGS += ${TAGS} environment="dev"
PROD_TAGS += ${TAGS} environment="prod"
CODE_BUCKET := ${AWS_ACCOUNT_ID}-code

deploy_all: install lint deploy_dev deploy_prod
.PHONY: deploy_all

install:
	@echo "Installing Python dependencies"
	pipenv sync --dev
	@echo
.PHONY: install

lint:
	@echo "Linting CloudFormation templates"
	pipenv run cfn-lint templates/*.yml
	@echo "Linting executed successful"
	@echo
.PHONY: lint

deploy_dev: $(dev)
	@echo "Deploying Dev stack in ${AWS_ACCOUNT_ID}, ${DEFAULT_AWS_REGION}..."
	@if [[ -d 'build' ]] ; then rm -rf build && echo "Removed old artefacts"; else echo "No old artefacts found"; fi

	@echo "Building CloudFormation artefact for ${IAM_STACK_NAME}..."
	pipenv run sam build \
		--base-dir . \
		--build-dir build \
		--template templates/${IAM_STACK_NAME}.yml \
		--region ${DEFAULT_AWS_REGION} \
		--parallel

	@echo "Packaging up CFN artefact and uploading to S3..."
	pipenv run sam package \
		--template build/template.yaml \
		--output-template-file build/_${IAM_STACK_NAME}-dev.yml \
		--profile ${AWS_DEFAULT_PROFILE} \
		--s3-prefix SAM/${IAM_STACK_NAME}-dev

	@echo "Deploying ${IAM_STACK_NAME}-dev template..."
	pipenv run sam deploy \
		--template-file build/_${IAM_STACK_NAME}-dev.yml \
		--stack-name ${IAM_STACK_NAME}-dev \
		--parameter-overrides Environment="dev" \
		--capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
		--tags '$(TAGS)' \
		--profile ${AWS_DEFAULT_PROFILE} \
		--region ${DEFAULT_AWS_REGION} \
		--no-fail-on-empty-changeset \
		--s3-prefix SAM/${IAM_STACK_NAME}-dev

	@echo "Stack ${IAM_STACK_NAME}-dev deployed successfully"
	@echo
	@echo
	@echo
	@echo "Building CloudFormation artefact for ${S3_STACK_NAME}-dev..."
	pipenv run sam build \
		--base-dir . \
		--build-dir build \
		--template templates/${S3_STACK_NAME}.yml \
		--region ${DEFAULT_AWS_REGION} \
		--parallel

	@echo "Packaging up CFN artefact and uploading to S3..."
	pipenv run sam package \
		--template build/template.yaml \
		--output-template-file build/_${S3_STACK_NAME}-dev.yml \
		--profile ${AWS_DEFAULT_PROFILE} \
		--s3-prefix SAM/${S3_STACK_NAME}-dev

	@echo "Deploying ${S3_STACK_NAME}-dev template..."
	pipenv run sam deploy \
		--template-file build/_${S3_STACK_NAME}-dev.yml \
		--stack-name ${S3_STACK_NAME}-dev \
		--parameter-overrides Environment="dev" \
		--capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
		--s3-prefix SAM/${S3_STACK_NAME}-dev \
		--tags '$(TAGS)' \
		--profile ${AWS_DEFAULT_PROFILE} \
		--region ${DEFAULT_AWS_REGION} \
		--no-fail-on-empty-changeset

	@echo "Stack ${S3_STACK_NAME}-dev deployed successfully"
	@echo
	@echo
	@echo

	@echo "Starting deployment of stack ${WEBAPP_INFRA_STACK_NAME}-dev..."
	@for aws_region in $(APP_REGIONS); do \
		echo "Building CloudFormation artefact for ${WEBAPP_INFRA_STACK_NAME}-dev..."; \
		pipenv run sam build \
			--base-dir . \
			--build-dir build \
			--template templates/${WEBAPP_INFRA_STACK_NAME}.yml \
			--region $$aws_region \
			--parallel; \
		echo "Packaging up CFN artefact and uploading to S3..."; \
		pipenv run sam package \
			--template build/template.yaml \
			--output-template-file build/_${WEBAPP_INFRA_STACK_NAME}-dev.yml \
			--s3-prefix SAM/${WEBAPP_INFRA_STACK_NAME}-dev \
			--profile ${AWS_DEFAULT_PROFILE}; \
		echo "Deploying ${WEBAPP_INFRA_STACK_NAME}-dev template in $$aws_region..."; \
		pipenv run sam deploy \
			--template-file build/_${WEBAPP_INFRA_STACK_NAME}-dev.yml \
			--stack-name ${WEBAPP_INFRA_STACK_NAME}-dev \
			--parameter-overrides Environment="dev" \
			--capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
			--s3-prefix SAM/${WEBAPP_INFRA_STACK_NAME}-dev \
			--tags '$(TAGS)' \
			--profile ${AWS_DEFAULT_PROFILE} \
			--region $$aws_region \
			--no-fail-on-empty-changeset; \
		echo "Stack ${WEBAPP_INFRA_STACK_NAME}-dev deployed successfully in $$aws_region"; \
	done
.PHONY: deploy_dev

deploy_prod: $(prod)
	@echo "Deploying Prod stack in ${AWS_ACCOUNT_ID}, ${DEFAULT_AWS_REGION}..."
	@if [[ -d 'build' ]] ; then rm -rf build && echo "Removed old artefacts"; else echo "No old artefacts found"; fi

	@echo "Building CloudFormation artefact for ${IAM_STACK_NAME}..."
	pipenv run sam build \
		--base-dir . \
		--build-dir build \
		--template templates/${IAM_STACK_NAME}.yml \
		--region ${DEFAULT_AWS_REGION} \
		--parallel

	@echo "Packaging up CFN artefact and uploading to S3..."
	pipenv run sam package \
		--template build/template.yaml \
		--output-template-file build/_${IAM_STACK_NAME}-prod.yml \
		--profile ${AWS_DEFAULT_PROFILE} \
		--s3-prefix SAM/${IAM_STACK_NAME}-prod

	@echo "Deploying ${IAM_STACK_NAME}-prod template..."
	pipenv run sam deploy \
		--template-file build/_${IAM_STACK_NAME}-prod.yml \
		--stack-name ${IAM_STACK_NAME}-prod \
		--parameter-overrides Environment="prod" \
		--capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
		--tags '$(TAGS)' \
		--profile ${AWS_DEFAULT_PROFILE} \
		--region ${DEFAULT_AWS_REGION} \
		--no-fail-on-empty-changeset \
		--s3-prefix SAM/${IAM_STACK_NAME}-prod

	@echo "Stack ${IAM_STACK_NAME}-prod deployed successfully"
	@echo
	@echo
	@echo
	@echo "Building CloudFormation artefact for ${S3_STACK_NAME}-prod..."
	pipenv run sam build \
		--base-dir . \
		--build-dir build \
		--template templates/${S3_STACK_NAME}.yml \
		--region ${DEFAULT_AWS_REGION} \
		--parallel

	@echo "Packaging up CFN artefact and uploading to S3..."
	pipenv run sam package \
		--template build/template.yaml \
		--output-template-file build/_${S3_STACK_NAME}-prod.yml \
		--profile ${AWS_DEFAULT_PROFILE} \
		--s3-prefix SAM/${S3_STACK_NAME}-prod

	@echo "Deploying ${S3_STACK_NAME}-prod template..."
	pipenv run sam deploy \
		--template-file build/_${S3_STACK_NAME}-prod.yml \
		--stack-name ${S3_STACK_NAME}-prod \
		--parameter-overrides Environment="prod" \
		--capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
		--s3-prefix SAM/${S3_STACK_NAME}-prod \
		--tags '$(TAGS)' \
		--profile ${AWS_DEFAULT_PROFILE} \
		--region ${DEFAULT_AWS_REGION} \
		--no-fail-on-empty-changeset

	@echo "Stack ${S3_STACK_NAME}-prod deployed successfully"
	@echo
	@echo
	@echo

	@echo "Starting deployment of stack ${WEBAPP_INFRA_STACK_NAME}-prod..."
	@for aws_region in $(APP_REGIONS); do \
		echo "Building CloudFormation artefact for ${WEBAPP_INFRA_STACK_NAME}-prod..."; \
		pipenv run sam build \
			--base-dir . \
			--build-dir build \
			--template templates/${WEBAPP_INFRA_STACK_NAME}.yml \
			--region $$aws_region \
			--parallel; \
		echo "Packaging up CFN artefact and uploading to S3..."; \
		pipenv run sam package \
			--template build/template.yaml \
			--output-template-file build/_${WEBAPP_INFRA_STACK_NAME}-prod.yml \
			--s3-prefix SAM/${WEBAPP_INFRA_STACK_NAME}-prod \
			--profile ${AWS_DEFAULT_PROFILE}; \
		echo "Deploying ${WEBAPP_INFRA_STACK_NAME}-prod template in $$aws_region..."; \
		pipenv run sam deploy \
			--template-file build/_${WEBAPP_INFRA_STACK_NAME}-prod.yml \
			--stack-name ${WEBAPP_INFRA_STACK_NAME}-prod \
			--parameter-overrides Environment="prod" \
			--capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
			--s3-prefix SAM/${WEBAPP_INFRA_STACK_NAME}-prod \
			--tags '$(TAGS)' \
			--profile ${AWS_DEFAULT_PROFILE} \
			--region $$aws_region \
			--no-fail-on-empty-changeset; \
		echo "Stack ${WEBAPP_INFRA_STACK_NAME}-prod deployed successfully in $$aws_region"; \
	done
.PHONY: deploy_prod

123456789010:	# any account specific variables go here
	$(eval AWS_ACCOUNT_ID := "123456789010")
	$(eval AWS_DEFAULT_PROFILE ?= "123456789010-sand")
.PHONY: 123456789010

123456789011:	# any account specific variables go here
	$(eval AWS_ACCOUNT_ID := "123456789011")
	$(eval AWS_DEFAULT_PROFILE ?= "123456789011-main")
.PHONY: 123456789011

dev:	# any DEV specific variables go here
	$(eval TAGS += repo="pd-app" service="pd" environment=dev)
.PHONY: dev

prod:	# any PROD specific variables go here
	$(eval TAGS += repo="pd-app" service="pd" environment=prod)
.PHONY: prod
