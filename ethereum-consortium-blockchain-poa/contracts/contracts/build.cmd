REM Build docker image and publish to DOCKER_REPOSITORY

REM !/bin/bash

REM Example build.cmd poadev.azurecr.io xxxyyy "xxx1yyy1" compiler:latest

set DOCKER_REPOSITORY=%1
set USERNAME=%2
set PASSWORD=%3
set IMAGE_NAME=%4

echo %{USERNAME}%@%{DOCKER_REPOSITORY}%
docker login %DOCKER_REPOSITORY% -u %USERNAME% -p %PASSWORD%

docker build -t "%DOCKER_REPOSITORY%/%IMAGE_NAME%" .
docker push "%DOCKER_REPOSITORY%/%IMAGE_NAME%"
