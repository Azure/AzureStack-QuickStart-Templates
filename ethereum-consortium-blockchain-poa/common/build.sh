# Build docker image and publish to DOCKER_REPOSITORY

#!/bin/bash

# Example ./build.sh "poadev.azurecr.io" "xxxyyy" "xxx1yyy1" "poa-etheradmin:latest" "poa-ethstat:latest"

DOCKER_REPOSITORY=$1
USERNAME=$2
PASSWORD=$3
IMAGE_NAME_ETHERADMIN=$4
IMAGE_NAME_ETHSTAT=$5
IMAGE_NAME_VALIDATOR=$6
IMAGE_NAME_ORCHESTRATOR=$7

echo ${USERNAME}@${DOCKER_REPOSITORY}
docker login $DOCKER_REPOSITORY -u $USERNAME -p $PASSWORD

# Build etheradmin
cd etheradmin
docker build -t "$DOCKER_REPOSITORY/$IMAGE_NAME_ETHERADMIN" .
docker push "$DOCKER_REPOSITORY/$IMAGE_NAME_ETHERADMIN"
cd ..

# Build ethstat
cd ethstat
docker build -t "$DOCKER_REPOSITORY/$IMAGE_NAME_ETHSTAT" .
docker push "$DOCKER_REPOSITORY/$IMAGE_NAME_ETHSTAT"
cd ..

# Build validator
cd validator
docker build -t "$DOCKER_REPOSITORY/$IMAGE_NAME_VALIDATOR" .
docker push "$DOCKER_REPOSITORY/$IMAGE_NAME_VALIDATOR"
cd ..


# Build orchestrator
cd ..
cd contracts/contracts
docker build -t "$DOCKER_REPOSITORY/$IMAGE_NAME_ORCHESTRATOR" .
docker push "$DOCKER_REPOSITORY/$IMAGE_NAME_ORCHESTRATOR"
