ifeq ("$(AWS_REGION)","")
  AWS_REGION := $${AWS_DEFAULT_REGION:-us-east-2}
endif

.PHONY: aws_sso sts_check

aws_sso: # Authenticate the SSO profile
	aws sso login --profile cloud-services-prod
	[ "$(AWS_PROFILE)" == "cloud-services-prod" ] || aws sso login --profile $(AWS_PROFILE)

sts_check: # Authenticate the SSO profile
	aws sts get-caller-identity --profile cloud-services-prod
	[ "$(AWS_PROFILE)" == "cloud-services-prod" ] || aws sts get-caller-identity --profile $(AWS_PROFILE)

aws_profile_github_terraform_pipelines:  # Create AWS_PROFILE for github-terraform-pipelines
	export AWS_PROFILE=$${AWS_PROFILE:-$(AWS_PROFILE)} ; \
	if [ ! -z "$$AWS_PROFILE" ] ; then \
	  if [ "yes" == "$$AWS_PROFILE_OVERWRITE" -o -z "$$(aws configure list-profiles 2>/dev/null | egrep -e ^$$AWS_PROFILE$$ 2>/dev/null )" ] ; then \
		export AWS_ACCOUNT_ID=$${AWS_ACCOUNT_ID:-$(AWS_ACCOUNT_ID)} ; \
		[ ! -z "$${AWS_ACCOUNT_ID}" ] || { \
		  export AWS_ACCOUNT_ID=$$(egrep -A 1 -e allowed_account_ids providers.tf 2>/dev/null | tail -1 2>/dev/null | sed -e 's/[ "]*//g' 2>/dev/null); \
		} ; \
		[ ! -z "$${AWS_ACCOUNT_ID}" ] || { echo "AWS_ACCOUNT_ID='$$AWS_ACCOUNT_ID'"; exit 1; } ; \
        echo "Create config for AWS_PROFILE=$$AWS_PROFILE,AWS_ACCOUNT_ID=$$AWS_ACCOUNT_ID" ; \
		aws configure set output json --profile=$$AWS_PROFILE 2>&1 ; \
		aws configure set region $${AWS_REGION_TOOLS:-us-east-2} --profile=$$AWS_PROFILE 2>&1 ; \
		aws configure set role_arn arn:aws:iam::$$AWS_ACCOUNT_ID:role/github-terraform-pipelines --profile=$$AWS_PROFILE 2>&1 ; \
		aws configure set source_profile $${AWS_PROFILE_PARENT:-b2b-master} --profile=$$AWS_PROFILE 2>&1 ; \
		aws sts get-caller-identity --profile=$$AWS_PROFILE 2>&1 ; \
	  else \
        echo "Existing config for AWS_PROFILE=$$AWS_PROFILE" ; \
	  fi ; \
	else \
        echo "No AWS_PROFILE!" ; \
	fi
