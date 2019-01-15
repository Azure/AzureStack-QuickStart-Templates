FROM ubuntu:18.04

# Create app directory
WORKDIR /usr/src/app

ENV NodeCount ""
ENV MODE ""
ENV KEY_VAULT_BASE_URL ""
ENV STORAGE_ACCOUNT ""
ENV CONTAINER_NAME ""
ENV STORAGE_ACCOUNT_KEY ""
ENV ETH_NETWORK_ID ""
ENV VALIDATOR_ADMIN_ACCOUNT ""
ENV CONSORTIUM_DATA_URL ""
ENV ACCESS_TOKEN ""
ENV CONFIG_LOG_FILE_PATH ""
ENV TRANSACTION_PERMISSION_CONTRACT ""

# Update package utility
RUN apt-get -y update
RUN apt-get -y install npm jq curl wget sudo netcat-openbsd software-properties-common libssl1.0.0 

# Install parity
RUN curl https://get.parity.io -Lk > installParity.sh
RUN chmod +x installParity.sh
RUN ./installParity.sh -r v1.10.6

# Install nodejs
RUN apt-get install nodejs

# Install azure CLI
# TODO: Research how to execute statement AZ_REPO=$(lsb_release -cs) in docker image to replace hard coded value 'bionic' below
RUN echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ bionic main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
RUN curl -L https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
RUN sudo sed -i -e "\$aAZURE_CORE_COLLECT_TELEMETRY=\"false\"" /etc/environment
RUN sudo apt-get update && sudo apt-get install azure-cli


# Bundle app scripts and java script files
COPY orchestrator ./

# Bundle app smart contracts
COPY AdminValidatorSet.sol ./
COPY SimpleValidatorSet.sol ./
COPY Utils.sol ./
COPY Admin.sol ./
COPY SafeMath.sol ./

# Install app dependencies
#COPY package*.json ./
RUN npm install

# Set execution permission for bash scripts
RUN chmod +x bootstrap.sh
RUN chmod +x orchestrate-poa.sh

CMD ["sh", "-c", "bash bootstrap.sh ${NodeCount} ${MODE} ${KEY_VAULT_BASE_URL} ${STORAGE_ACCOUNT} ${CONTAINER_NAME} ${STORAGE_ACCOUNT_KEY} ${ETH_NETWORK_ID} ${VALIDATOR_ADMIN_ACCOUNT} ${CONSORTIUM_DATA_URL} ${ACCESS_TOKEN} ${CONFIG_LOG_FILE_PATH} ${TRANSACTION_PERMISSION_CONTRACT} ${AAD_TENANTID} ${SPN_KEY} ${SPN_APPID} ${RG_NAME} ${KV_NAME}"]


