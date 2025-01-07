#!/usr/bin/env bash

# [2022-02-23 Christo]
# This script is meant to make consuming private PyPi and NPM repositories hosted in CodeArtifact in the Cloud Services Prod AWS account easier.
# Usage:
# source bin/poetry-2-codeartifact.sh
# OR
# bash bin/poetry-2-codeartifact.sh
#
# Method 1 leaves the various functions in your shell environment so you can use them as needed.
#
# Overview of what this script does:
# 1. Gets or refreshes AWS STS credentials for the Cloud Services Prod AWS account using the cloud-services-prod profile.
# 2. Configures Pip and NPM to use the private PyPi and NPM repositories hosted in CodeArtifact (as opposed to the public repositories).
# 3. Configure Poetry to authenticate with and use CodeArtifact hosted private PyPi.
#
# A word on CodeArtifact:
# CodeArtifact is used as a private repository manager for NPM and PyPi packages.
# It hosts our Python packages like python-toolbag, SandsB2B-naming and other Python packages we develop internally.
# CodeArtifact will serve private packages BUT ALSO proxy to public repositories like pypi.org so it is not necessary to configure tooling
# to point to different repositories for different sets of packages.

# These environment variables are used to configure the script for the Cloud Services Prod AWS account and correct region:
export AWS_ACCOUNT_TOOLS_DEFAULT=433714148419
export AWS_ACCOUNT_TOOLS=$AWS_ACCOUNT_TOOLS_DEFAULT
export AWS_PROFILE_TOOLS_DEFAULT=cloud-services-prod
export AWS_PROFILE_TOOLS=$AWS_PROFILE_TOOLS_DEFAULT
export AWS_REGION_TOOLS_DEFAULT=us-east-2
export AWS_REGION_TOOLS=${AWS_REGION_TOOLS_DEFAULT}
export AWS_DEFAULT_REGION=us-east-2
export AWS_REGION=us-east-2

# Utility functions follow. These were created from Bash aliases with the same names and don't even pretend to be general purpose or well thought out ...
# In general the function names are literally the first letter of each word in some command line they execute. :)
# Examples:
# pcl == poetry config --list
# acgre = aws codeartifact get-repository-endpoint

# Get AWS STS caller identity for "tools" account.
asgcit ()
{
    aws sts get-caller-identity --profile ${AWS_PROFILE_TOOLS:-$AWS_PROFILE_TOOLS_DEFAULT}
}

# AWS CodeArtifact login to pip repository in the artifacts domain for the "tools" or given account, region and given or tools profile.
aclp ()
{
    local profile;
    test -z "$1" || profile=$1;
    local aws_account;
    if test -z "${2:-}"; then
        aws_account=${AWS_ACCOUNT_TOOLS:-$AWS_ACCOUNT_TOOLS_DEFAULT};
    else
        aws_account=$2;
    fi;
    PAGER='' aws codeartifact login --tool pip --repository pypi --domain artifacts --domain-owner $aws_account --profile=${profile:-$AWS_PROFILE} --region=${AWS_REGION_TOOLS:-$AWS_REGION_TOOLS_DEFAULT:-${AWS_REGION:-$AWS_REGION_DEFAULT}}
}

# AWS CodeArtifact login to npm repository in the artifacts domain for the "tools" or given account, region and given or tools profile.
acln ()
{
    local profile;
    test -z "$1" || profile=$1;
    if test -z "${2:-}"; then
        aws_account=${AWS_ACCOUNT_TOOLS:-$AWS_ACCOUNT_TOOLS_DEFAULT};
    else
        aws_account=$2;
    fi;
    PAGER='' aws codeartifact login --tool npm --repository npm --domain artifacts --domain-owner $aws_account --profile=${profile:-$AWS_PROFILE} --region=${AWS_REGION_TOOLS:-$AWS_REGION_TOOLS_DEFAULT:-${AWS_REGION:-$AWS_REGION_DEFAULT}}
}

# Use awssso if we have it otherwise use aws sso.
function do_awssso() {
  which pyenv 2>/dev/null 1>&2
  pyenv_rc=$?
  if [ 0 -eq $pyenv_rc ] ; then
    pyenv which awssso 2>/dev/null 1>&2
  else
    which awssso 2>/dev/null 1>&2
  fi
  awssso_rc=$?
  if [ 0 -eq $awssso_rc ] ; then
    awssso $*
  else
    aws sso $*
  fi
}

# Do aws sso login for the given on environment AWS_PROFILE and then connect pip and npm to CodeArtifact.
asl ()
{
    local profile;
    profile=${1:-$AWS_PROFILE};
    if [ -z "${profile:-$AWS_PROFILE}" ]; then
        echo "No profile specified";
        return 1;
    fi;
    PAGER='' aws sts get-caller-identity || {
        do_awssso login --profile=${profile:-$AWS_PROFILE}
    };
    aclp ${profile:-$AWS_PROFILE};
    acln ${profile:-$AWS_PROFILE}
}

# asl for AWS_PROFILE_TOOLS
aslpt ()
{
    asl ${AWS_PROFILE_TOOLS:-$AWS_PROFILE_TOOLS_DEFAULT}
}

# aclp for AWS_PROFILE_TOOLS
aclpip ()
{
    aclp ${AWS_PROFILE_TOOLS:-$AWS_PROFILE_TOOLS_DEFAULT}
}

# acln for AWS_PROFILE_TOOLS
aclnpm ()
{
    acln ${AWS_PROFILE_TOOLS:-$AWS_PROFILE_TOOLS_DEFAULT}
}

# AWS STS get caller identity for the default profile (AWS_PROFILE or "default").
function asgci() {
  aws sts get-caller-identity --profile ${AWS_PROFILE:-default}
}

# AWS STS get caller identity for the AWS_PROFILE_TOOLS profile.
function asgcit() {
  aws sts get-caller-identity --profile ${AWS_PROFILE_TOOLS:-$AWS_PROFILE_TOOLS_DEFAULT}
}

unalias asltools 2>/dev/null || true
# asgcit and if that fails aslpt and asgcit and then aclpip and aclnpm.
# Ok, less tongue in cheek ..
# We check if our STS tokens are current and if not we login to AWS SSO and then connect pip and npm to CodeArtifact.
asltools()
{
    asgcit || { aslpt ; asgcit; }; aclpip ; aclnpm
}

# Configure Poetry to point to the CodeArtifact repository provided.
function pcr() {
  poetry config --unset repos.$1 2>/dev/null ;
  poetry config repositories.$1 $2
}

# Configure the HTTP-Basic authentication for the given repository using the provided repo name and token.
function pchb() {
  poetry config http-basic.$1 aws $2
}

# List the Poetry configuration.
function pcl() {
  set | egrep -e '^(POETRY|PYTHON|AWS)';
  poetry config --list
}

# Configure Poetry repositories and authentication and show the new config.
function pcrhb() {
  test ! -z "${3:-}" || { echo "ERROR: Need to know the poetry.source.name"; return 1; }
  pcr $3 $1
  pchb $3 $2
  pcl
}

# Get the CodeArtifact authentication token for basic authentication.
function acgat() {
  aws codeartifact get-authorization-token --domain artifacts --domain-owner ${AWS_ACCOUNT_TOOLS:-$AWS_ACCOUNT_TOOLS_DEFAULT} --profile ${AWS_PROFILE:-${AWS_PROFILE_TOOLS:-$AWS_PROFILE_TOOLS_DEFAULT}} --region ${AWS_REGION_TOOLS:-$AWS_REGION_TOOLS_DEFAULT:-${AWS_REGION}} --query @.authorizationToken --output text
}

# Get the CodeArtifact repository endpoint.
function acgre() {
  aws codeartifact get-repository-endpoint --domain artifacts --domain-owner ${AWS_ACCOUNT_TOOLS:-$AWS_ACCOUNT_TOOLS_DEFAULT} --profile ${AWS_PROFILE:-${AWS_PROFILE_TOOLS:-$AWS_PROFILE_TOOLS_DEFAULT}} --region ${AWS_REGION_TOOLS:-$AWS_REGION_TOOLS_DEFAULT:-${AWS_REGION}} --repository pypi --format pypi --query @.repositoryEndpoint --output text
}

# Configure Poetry for CodeArtifact for the provided source.
function pca() {
  pcrhb $(acgre) $(acgat) $1
}

# Configure Poetry for CodeArtifact for the source we call "codeartifact" in pyproject.toml and show the new config.
pcac ()
{
    pca codeartifact;
    pcl
}

# Configure Poetry to NOT use the keyring and then hook up our "codeartifact" source to our Codeartifact PyPi.
pcacnkr() {
  export PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring;
  pcac
}

# AWS SSO authentication check and full Poetry CodeArtifact configuration all in one.
cac ()
{
    asltools;
    pcacnkr
}

# Do it!
cac
