Run tests on Windows:

npm install
npm install -g truffle
truffle.cmd develop
test


Build docker image of smart contract compiler and publish to DOCKER_REPOSITORY

$> cd contracts
$> ./build.sh "poadev.azurecr.io" "<docker_login>" "<docker_password>" "poadev.azurecr.io/poa-compile-contract:<version>"

