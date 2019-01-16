REM Build docker image and publish to DOCKER_REPOSITORY

REM !/bin/bash

REM Example build.cmd poadev.azurecr.io xxxyyy "xxx1yyy1" poa-etheradmin:latest poa-ethstat:latest

set DOCKER_REPOSITORY=%1
set USERNAME=%2
set PASSWORD=%3
set IMAGE_NAME_ETHERADMIN=%4
set IMAGE_NAME_ETHSTAT=%5
set IMAGE_NAME_VALIDATOR=%6
set IMAGE_NAME_ORCHESTRATOR=%7

echo %{USERNAME}%@%{DOCKER_REPOSITORY}%
docker login %DOCKER_REPOSITORY% -u %USERNAME% -p %PASSWORD%

REM Build etheradmin
cd etheradmin
docker build -t "%DOCKER_REPOSITORY%/%IMAGE_NAME_ETHERADMIN%" .
docker push "%DOCKER_REPOSITORY%/%IMAGE_NAME_ETHERADMIN%"
cd ..

REM Build ethstat
cd ethstat
docker build -t "%DOCKER_REPOSITORY%/%IMAGE_NAME_ETHSTAT%" .
docker push "%DOCKER_REPOSITORY%/%IMAGE_NAME_ETHSTAT%"
cd ..

REM Build validator
cd validator
docker build -t "%DOCKER_REPOSITORY%/%IMAGE_NAME_VALIDATOR%" .
docker push "%DOCKER_REPOSITORY%/%IMAGE_NAME_VALIDATOR%"
cd ..

REM Build orchestrator
cd ..
cd contracts/contracts
docker build -t "%DOCKER_REPOSITORY%/%IMAGE_NAME_ORCHESTRATOR%" .
docker push "%DOCKER_REPOSITORY%/%IMAGE_NAME_ORCHESTRATOR%"
