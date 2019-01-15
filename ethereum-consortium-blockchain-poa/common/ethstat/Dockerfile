FROM node:8.11.1

# Create app directory
WORKDIR /usr/src/app

ENV ipaddr ""
ENV rpcPort ""
ENV sharedKey ""
ENV customerId ""
ENV logFile ""

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available (npm@5+)
COPY package*.json ./

RUN npm install -g

# Bundle app source
COPY . .

CMD ["sh", "-c", "node ethstat.js ${ipaddr} ${rpcPort} ${sharedKey} ${customerId} ${logFile}"]