FROM node:8.11.1

# Create app directory
WORKDIR /usr/src/app

ENV listenPort ""
ENV consortiumId ""
ENV azureStorageAccount ""
ENV azureStorageAccessKey ""
ENV containerName ""
ENV identityBlobPrefix ""
ENV ethRpcPort ""
ENV validatorListBlobName ""
ENV paritySpecBlobName ""
ENV valSetContractBlobName ""
ENV adminContractBlobName ""
ENV adminContractABIBlobName ""
ENV adminSiteLogFile ""

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available (npm@5+)
COPY package*.json ./

RUN npm install -g

# Bundle app source
COPY . .

CMD ["sh", "-c", "node etheradmin.js ${listenPort} ${consortiumId} ${azureStorageAccount} ${azureStorageAccessKey} ${containerName} ${identityBlobPrefix} ${ethRpcPort} ${validatorListBlobName} ${paritySpecBlobName} ${valSetContractBlobName} ${adminContractBlobName} ${adminContractABIBlobName} ${adminSiteLogFile}"]