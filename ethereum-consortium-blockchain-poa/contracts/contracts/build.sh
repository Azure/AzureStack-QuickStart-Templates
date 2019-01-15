
# Build docker image and publish to DOCKER_REPOSITORY

#!/bin/bash

# Example ./build.sh "poadev.azurecr.io" "xxxyyy" "xxx1yyy1" "poa-orchestrator"

DOCKER_REPOSITORY=$1
USERNAME=$2
PASSWORD=$3
IMAGE_NAME=$4

echo ${USERNAME}@${DOCKER_REPOSITORY}
docker login $DOCKER_REPOSITORY -u $USERNAME -p $PASSWORD

docker build -t "$DOCKER_REPOSITORY/$IMAGE_NAME" .
docker push "$DOCKER_REPOSITORY/$IMAGE_NAME"

