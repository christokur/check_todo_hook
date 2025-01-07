#!/usr/bin/env bash

#set -x
set -euo pipefail

realpath() {
  echo "$(readlink -f "$1")"
}

export ROOT_DIR=${ROOT_DIR:-$(dirname $0)}
export IS_TERRAGRUNT=${IS_TERRAGRUNT:-no}
export ENVIRONMENT_NAME=${ENVIRONMENT_NAME:-$(basename $PWD)}
export LAST_MAKEFILE=${LAST_MAKEFILE:-$PWD/Makefile} ; \

if [ "yes" == "${IS_TERRAGRUNT}" ] ; then
  export WORKING_DIR=$(terragrunt terragrunt-info | jq '.WorkingDir' | sed 's/"//g') ;
else
  export WORKING_DIR=$PWD ;
fi ;
export ROOT_DIR=$(realpath $(dirname ${LAST_MAKEFILE})/..) ;
echo "ROOT_DIR=$ROOT_DIR" ;
export DOCS_FILE=docs/$(echo $(realpath $PWD) | sed "s|$ROOT_DIR/||").md ;
echo "DOCS_FILE=$DOCS_FILE" ;
export DOCS_DIR=$ROOT_DIR/$(dirname $DOCS_FILE) ;
echo "DOCS_DIR=$DOCS_DIR" ;
pushd . ;
cd $WORKING_DIR ;
terraform-docs markdown table . >README.md ;
[ -d ${DOCS_DIR} ] || { echo "Create ${DOCS_DIR}"; mkdir -p ${DOCS_DIR}; } ;
echo "Create $(basename $DOCS_DIR).md in ${DOCS_DIR}" ;
printf "# ${ENVIRONMENT_NAME} #\n\n" >${ROOT_DIR}/$DOCS_FILE ;
cat README.md >>${ROOT_DIR}/$DOCS_FILE ;
[ ! -d $WORKING_DIR/docs ] || cp -r $WORKING_DIR/docs/* ${DOCS_DIR} ;
popd

#read x
#set +x
