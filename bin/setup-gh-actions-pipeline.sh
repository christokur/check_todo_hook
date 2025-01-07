#!/usr/bin/env bash

if op item get "github-terraform-pipelines GithubActions User credentials" --vault b2b-cloud-infra --fields AWS_ACCESS_KEY_ID ; then
  AWS_ACCESS_KEY_ID=$(op item get "github-terraform-pipelines GithubActions User credentials" --vault b2b-cloud-infra --fields AWS_ACCESS_KEY_ID)
  AWS_SECRET_ACCESS_KEY=$(op item get "github-terraform-pipelines GithubActions User credentials" --vault b2b-cloud-infra --fields AWS_SECRET_ACCESS_KEY)

  if [ -z "$GITHUB_REPO_CREDENTIALS" ] ; then
    echo "We are switching to using ORG secrets for AWS credentials"
    gh secret delete AWS_ACCESS_KEY_ID || true
    gh secret delete AWS_SECRET_ACCESS_KEY || true
  else
    echo "Using REPO secrets for AWS credentials"
    gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID"
    gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"
  fi

  gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/SandsB2B/$(basename $PWD)/pages && gh api --method DELETE -H "X-GitHub-Api-Version: 2022-11-28" /repos/SandsB2B/$(basename $PWD)/pages || true
  gh api --method POST -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/SandsB2B/$(basename $PWD)/pages -f build_type='workflow'
  gh api --method PUT -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/SandsB2B/$(basename $PWD)/pages -f cname="$(basename $PWD).docs.infra-area2.com"
  cat - <<EOF | gh api --method PUT -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/SandsB2B/$(basename $PWD)/pages --input  -
{ "https_enforced": true }
EOF
  gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/SandsB2B/$(basename $PWD)/pages

  gh api --method POST -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/SandsB2B/$(basename $PWD)/environments/github-pages/deployment-branch-policies -f name='master'
  gh api --method POST -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/SandsB2B/$(basename $PWD)/environments/github-pages/deployment-branch-policies -f name='main'
  gh api --method POST -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/SandsB2B/$(basename $PWD)/environments/github-pages/deployment-branch-policies -f name='develop'

  aws sts get-caller-identity --profile=cloud-services-prod

  cp -f bin/change-rr-set.tpl.json bin/change-rr-set.json
  sed -i '' -e "s/REPO_NAME/$(basename $PWD)/g" bin/change-rr-set.json

  [ ! -z "$(aws route53 list-resource-record-sets --hosted-zone-id=Z0827901K2W3PZV3XWL1  --profile=cloud-services-prod  --query="@.ResourceRecordSets[?Name == \`$(basename $PWD).docs.infra-area2.com.\`]" --output text)" ] || {
    aws route53 change-resource-record-sets --profile=cloud-services-prod --cli-input-json file://bin/change-rr-set.json;
  }
else
  echo "You need to install the 1Password CLI and login to the b2b-cloud-infra vault"
fi
