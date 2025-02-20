#!/bin/bash

<< 'DOCS'
  Generate protobuf files from internal_api definitions.
DOCS

# When DEBUG env is set - print output of the scripts.
if [[ -e $DEBUG ]];
then
  set -x
fi

INTERNAL_API_REPO=git@github.com:renderedtext/internal_api.git
INTERNAL_API_OUT=pkg/protos
INTERNAL_API_IN=/tmp/internal_api
MODULE_NAME=github.com/semaphoreio/semaphore/velocity
MODULES=(${1//,/ })
INTERNAL_API_BRANCH=${2:-master}


generate_proto_definition()
{
  MODULE=$1
  FILE=$2

  mkdir -p pkg/protos/$MODULE
	protoc --proto_path /tmp/internal_api/ \
         --proto_path /tmp/internal_api/include/ \
         --proto_path /tmp/internal_api/include/internal_api \
				 --go-grpc_out=pkg/protos/$MODULE \
				 --go-grpc_opt=paths=source_relative \
         --go-grpc_opt=require_unimplemented_servers=false \
				 --go_out=pkg/protos/$MODULE \
         --go_opt=M$FILE=internal_api/$MODULE \
				 --go_opt=paths=source_relative  \
				 $FILE
}


set_go_packages()
{
  echo "$(bold "Generating proto definitions")"
  echo "MODULES := (${MODULES[@]})"
  _set_go_package response_status /tmp/internal_api/include/internal_api/response_status.proto
  _set_go_package status /tmp/internal_api/include/internal_api/status.proto
  for MODULE in ${MODULES[@]};
  do
    _set_go_package $MODULE /tmp/internal_api/$MODULE.proto
  done
}
_set_go_package()
{
  MODULE=$1
  FILE=$2

  echo "$(bold "Processing $FILE")"
  echo "Removing current go_package"
	sed --in-place '/go_package/d' $FILE
  GO_PACKAGE="option go_package = \"github.com/semaphoreio/semaphore/velocity/pkg/protos/$MODULE\";"
  echo "Setting new go_package"
  echo $GO_PACKAGE >> $FILE
  echo "New go_package set: $GO_PACKAGE"
}

generate_proto_files()
{
  echo "$(bold "Generating proto files")"
  for MODULE in ${MODULES[@]};
  do
    generate_proto_definition $MODULE /tmp/internal_api/$MODULE.proto
  done

  generate_proto_definition response_status /tmp/internal_api/include/internal_api/response_status.proto
  mv pkg/protos/response_status/include/internal_api/response_status.pb.go pkg/protos/response_status/response_status.pb.go
  rm -rf pkg/protos/response_status/include

  generate_proto_definition status /tmp/internal_api/include/internal_api/status.proto
  mv pkg/protos/status/include/internal_api/status.pb.go pkg/protos/status/status.pb.go
  rm -rf pkg/protos/status/include

  echo "Files generated in $INTERNAL_API_OUT"
}

bold() {
  bold_text=$(tput bold)
  normal_text=$(tput sgr0)
  echo -n "${bold_text}$@${normal_text}"
}

set_go_packages && \
generate_proto_files
