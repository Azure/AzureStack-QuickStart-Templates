FROM ubuntu:18.04

# Create app directory
WORKDIR /usr/src/app

ENV AZUREUSER ""
ENV STORAGE_ACCOUNT ""
ENV CONTAINER_NAME ""
ENV STORAGE_ACCOUNT_KEY ""
ENV ADMINID ""
ENV NUM_BOOT_NODES ""
ENV RPC_PORT ""
ENV PASSPHRASE ""
ENV PASSPHRASE_FILE_NAME ""
ENV PASSPHRASE_URI ""
ENV MODE ""
ENV LEASE_ID ""
ENV CONSORTIUM_DATA_URL ""
ENV MUST_DEPLOY_GATEWAY ""
ENV CONFIG_LOG_FILE_PATH ""
ENV PARITY_LOG_FILE_PATH ""

# Update package utility
RUN apt-get -y update
RUN apt-get -y install npm jq curl wget sudo netcat-openbsd apt-utils software-properties-common apt-transport-https libssl1.0.0 

# Install parity
RUN curl https://get.parity.io -Lk > installParity.sh
RUN chmod +x installParity.sh
RUN ./installParity.sh -r v1.10.6

# TODO: Research how to execute statement AZ_REPO=$(lsb_release -cs) in docker image to replace hard coded value 'bionic' below
RUN echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ bionic main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
RUN curl -L https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
RUN sudo sed -i -e "\$aAZURE_CORE_COLLECT_TELEMETRY=\"false\"" /etc/environment
RUN sudo apt-get update && sudo apt-get install azure-cli

# Copy app dependencies
COPY none_authority.toml ./
COPY node.toml ./
COPY validator.sh ./
COPY bootstrap.sh ./
COPY parity_log_config ./


# Set execution permission for bash scripts
RUN chmod +x validator.sh
RUN chmod +x bootstrap.sh

CMD ["sh", "-c", "bash bootstrap.sh ${AZUREUSER} ${STORAGE_ACCOUNT} ${CONTAINER_NAME} ${STORAGE_ACCOUNT_KEY} ${ADMINID} ${NUM_BOOT_NODES} ${RPC_PORT} ${PASSPHRASE} ${PASSPHRASE_FILE_NAME} ${PASSPHRASE_URI} ${MODE} ${LEASE_ID} ${CONSORTIUM_DATA_URL} ${MUST_DEPLOY_GATEWAY} ${CONFIG_LOG_FILE_PATH} ${PARITY_LOG_FILE_PATH}"]
