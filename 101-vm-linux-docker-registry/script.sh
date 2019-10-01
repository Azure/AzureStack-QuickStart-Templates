#!/bin/bash
#
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license.

# ===
# NOTE: the CSE script is embedded in azuredeploy.json (base64 encoding)
# Update the VM resource (.properties.osPrifile.customData) to alter the CSE script.
# ===

ERR_APT_INSTALL_TIMEOUT=9           # Timeout installing required apt packages
ERR_MISSING_CRT_FILE=10             # Bad cert thumbprint OR pfx not in key vault OR template misconfigured VM secrets section
ERR_MISSING_KEY_FILE=11             # Bad cert thumbprint OR pfx not in key vault OR template misconfigured VM secrets section
ERR_MISSING_USER_CREDENTIALS=12     # No user credentials secret found on given key vault
ERR_REGISTRY_NOT_RUNNING=13         # The container registry failed to start successfully
ERR_MOBY_APT_LIST_TIMEOUT=25        # Timeout waiting for moby apt sources
ERR_MS_GPG_KEY_DOWNLOAD_TIMEOUT=26  # Timeout waiting for MS GPG key download
ERR_MOBY_INSTALL_TIMEOUT=27         # Timeout waiting for moby install
ERR_METADATA=30                     # Error querying metadata
ERR_MS_PROD_DEB_DOWNLOAD_TIMEOUT=42 # Timeout waiting for https://packages.microsoft.com/config/ubuntu/16.04/packages-microsoft-prod.deb
ERR_MS_PROD_DEB_PKG_ADD_FAIL=43     # Failed to add repo pkg file
ERR_APT_UPDATE_TIMEOUT=99           # Timeout waiting for apt-get update to complete

retrycmd_if_failure() {
    retries=$1; wait_sleep=$2; timeout=$3; 
    shift && shift && shift
    for i in $(seq 1 $retries); do
        timeout $timeout ${@} && break || \
        if [ $i -eq $retries ]; then
            return 1
        else
            sleep $wait_sleep
        fi
    done
}
wait_for_apt_locks() {
    while fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
        echo 'Waiting for release of apt locks'
        sleep 3
    done
}
apt_get_update() {
    retries=10
    apt_update_output=/tmp/apt-get-update.out
    for i in $(seq 1 $retries); do
        wait_for_apt_locks
        dpkg --configure -a
        apt-get -f -y install
        ! (apt-get update 2>&1 | tee $apt_update_output | grep -E "^([WE]:.*)|([eE]rr.*)$") && \
        cat $apt_update_output && break || \
        cat $apt_update_output
        if [ $i -eq $retries ]; then
            return 1
        else sleep 5
        fi
    done
    wait_for_apt_locks
}
apt_get_install() {
    retries=$1; wait_sleep=$2; timeout=$3; 
    shift && shift && shift
    for i in $(seq 1 $retries); do
        wait_for_apt_locks
        dpkg --configure -a
        apt-get install -o Dpkg::Options::="--force-confold" --no-install-recommends -y ${@} && break || \
        if [ $i -eq $retries ]; then
            return 1
        else
            sleep $wait_sleep
            apt_get_update
        fi
    done
    wait_for_apt_locks
}
installDeps() {
    UBUNTU_RELEASE=$(lsb_release -r -s)
    MOBY_VERSION="3.0.6"

    retrycmd_if_failure 120 5 25 curl https://packages.microsoft.com/config/ubuntu/${UBUNTU_RELEASE}/prod.list > /tmp/microsoft-prod.list || exit $ERR_MOBY_APT_LIST_TIMEOUT
    retrycmd_if_failure 10  5 10 cp /tmp/microsoft-prod.list /etc/apt/sources.list.d/ || exit $ERR_MOBY_APT_LIST_TIMEOUT
    retrycmd_if_failure 120 5 25 curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg || exit $ERR_MS_GPG_KEY_DOWNLOAD_TIMEOUT
    retrycmd_if_failure 10  5 10 cp /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/ || exit $ERR_MS_GPG_KEY_DOWNLOAD_TIMEOUT
    apt_get_update || exit $ERR_APT_UPDATE_TIMEOUT
    
    apt_get_install 20 30 120 apache2-utils moby-engine=${MOBY_VERSION} moby-cli=${MOBY_VERSION} --allow-downgrades || exit $ERR_MOBY_INSTALL_TIMEOUT
    usermod -aG docker ${ADMIN_USER_NAME}
    
    for apt_package in curl jq; do
      if ! apt_get_install 30 1 600 $apt_package; then
        journalctl --no-pager -u $apt_package
        exit $ERR_APT_INSTALL_TIMEOUT
      fi
    done
}
fetchOAuth() {
    ENDPOINTS=$(mktemp)
    curl -s --retry 5 --retry-delay 10 --max-time 60 -f \
        https://management.${FQDN}/metadata/endpoints?api-version=2015-01-01 > ${ENDPOINTS}

    if [ $? -ne 0 ]; then
        exit $ERR_METADATA
    fi
    
    OAUTH=$(jq -r .authentication.loginEndpoint ${ENDPOINTS})
    echo ${OAUTH} | grep -e "/adfs$"

    if [ $? -eq 0 ]; then
        TOKEN_URL="${OAUTH}/oauth2/token"
    else
        TOKEN_URL="${OAUTH}${TENANT_ID}/oauth2/token"
    fi
}
fetchCredentials() {
    RESOURCE=$(jq -r .authentication.audiences[0] ${ENDPOINTS} | sed "s|https://management.|https://vault.|")

    TOKEN=$(curl -s --retry 5 --retry-delay 10 --max-time 60 -f -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials" \
        -d "client_id=${SPN_CLIENT_ID}" \
        --data-urlencode "client_secret=${SPN_CLIENT_SECRET}" \
        --data-urlencode "resource=${RESOURCE}" \
        ${TOKEN_URL} | jq -r '.access_token')

    KV_URL="https://${KV_NAME}.vault.${FQDN}/secrets"
    SECRETS=$(curl -s --retry 5 --retry-delay 10 --max-time 60 -f \
        "${KV_URL}?api-version=2016-10-01" -H "Authorization: Bearer ${TOKEN}" | jq -r .value[].id)

    rm .htpasswd
    touch .htpasswd
    for secret in ${SECRETS}
    do 
        SECRET_NAME_VERSION="${secret//$KV_URL}"
        SECRET_NAME=$(echo ${SECRET_NAME_VERSION} | cut -d '/' -f 2)
        SECRET_VALUE=$(curl -s --retry 5 --retry-delay 10 --max-time 60 -f \
            "${secret}?api-version=2016-10-01" -H "Authorization: Bearer ${TOKEN}" | jq -r .value)
        htpasswd -Bb .htpasswd ${SECRET_NAME} ${SECRET_VALUE}
    done

    if [ ! -s .htpasswd ]; then
        echo "file .htpasswd is empty, credentials were not created or there was an error fetching credentials from keyvault"
        exit $ERR_MISSING_USER_CREDENTIALS
    fi
}
fetchStorageKeys() {
    RESOURCE=$(jq -r .authentication.audiences[0] ${ENDPOINTS})

    TOKEN=$(curl -s --retry 5 --retry-delay 10 --max-time 60 -f -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials" \
        -d "client_id=${SPN_CLIENT_ID}" \
        --data-urlencode "client_secret=${SPN_CLIENT_SECRET}" \
        --data-urlencode "resource=${RESOURCE}" \
        ${TOKEN_URL} | jq -r '.access_token')

    SA_URL="https://management.${FQDN}/${SA_RESOURCE_ID}/listKeys?api-version=2017-10-01"
    SA_KEY=$(curl -s --retry 5 --retry-delay 10 --max-time 60 -f -X POST \
        "${SA_URL}" -H "Authorization: Bearer ${TOKEN}" -H "Content-Length: 0" | jq -r ".keys[0].value")
}

echo LOCATION:          ${LOCATION}
echo TENANT_ID:         ${TENANT_ID}
echo ADMIN_USER_NAME:   ${ADMIN_USER_NAME}
echo SA_RESOURCE_ID:    ${SA_RESOURCE_ID}
echo SA_CONTAINER:      ${SA_CONTAINER}
echo KV_RESOURCE_ID:    ${KV_RESOURCE_ID}
echo CERT_THUMBPRINT:   ${CERT_THUMBPRINT}
echo PIP_FQDN:          ${PIP_FQDN}
echo PIP_LABEL:         ${PIP_LABEL}
echo REGISTRY_TAG:      ${REGISTRY_TAG}
echo REGISTRY_REPLICAS: ${REGISTRY_REPLICAS}
echo SPN_CLIENT_ID:     ${SPN_CLIENT_ID}
echo SPN_CLIENT_SECRET: ***

SA_NAME=$(echo ${SA_RESOURCE_ID} | grep -oh -e '[[:alnum:]]*$')
KV_NAME=$(echo ${KV_RESOURCE_ID} | grep -oh -e '[[:alnum:]]*$')

EXT_DOMAIN_NAME="${PIP_FQDN//$PIP_LABEL.$LOCATION.cloudapp.}"
FQDN=${LOCATION}.${EXT_DOMAIN_NAME}

CRT_FILE="${CERT_THUMBPRINT}.crt"
KEY_FILE="${CERT_THUMBPRINT}.prv"
SECRET=$(openssl rand -base64 32)

if [ -f /opt/azure/vhd-install.complete ]; then
    echo "aks base image; skipping dependencies installation"
    rm -rf /home/packer
    deluser packer
    groupdel packer
else
    installDeps
fi

echo validating dependencies
if [ ! -f "/var/lib/waagent/${CRT_FILE}" ]; then
    exit $ERR_MISSING_CRT_FILE
fi

if [ ! -f "/var/lib/waagent/${KEY_FILE}" ]; then
    exit $ERR_MISSING_KEY_FILE
fi

echo adding certs to the ca-store
cp "/var/lib/waagent/Certificates.pem" "/usr/local/share/ca-certificates/azsCertificate.crt"
update-ca-certificates

echo copy user cert to mount point
STORE="/etc/ssl/certs/registry"
mkdir -p $STORE
cp "/var/lib/waagent/${CRT_FILE}" "${STORE}/${CRT_FILE}"
cp "/var/lib/waagent/${KEY_FILE}" "${STORE}/${KEY_FILE}"

echo getting management endpoints
fetchOAuth

echo fetching storage key
fetchStorageKeys

echo fetching user credentials
HTPASSWD_DIR="/root/auth"
mkdir -p $HTPASSWD_DIR
fetchCredentials
cp .htpasswd $HTPASSWD_DIR/.htpasswd

echo starting registry container
cat <<EOF >> docker-compose.yml
version: '3'
services:
  registry:
    image: registry:${REGISTRY_TAG}
    deploy:
      mode: replicated
      replicas: ${REGISTRY_REPLICAS}
      restart_policy:
        condition: on-failure
        delay: 5s
    ports:
      - "443:5000"
    volumes:
      - /etc/ssl/certs:/etc/ssl/certs:ro
      - /root/auth:/auth
    environment:
      - REGISTRY_LOG_ACCESSLOG_DISABLED=false
      - REGISTRY_STORAGE=azure
      - REGISTRY_STORAGE_AZURE_ACCOUNTNAME=${SA_NAME}
      - REGISTRY_STORAGE_AZURE_ACCOUNTKEY=${SA_KEY}
      - REGISTRY_STORAGE_AZURE_CONTAINER=${SA_CONTAINER}
      - REGISTRY_STORAGE_AZURE_REALM=${FQDN}
      - REGISTRY_AUTH=htpasswd
      - REGISTRY_AUTH_HTPASSWD_PATH=/auth/.htpasswd
      - REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm"
      - REGISTRY_HTTP_ADDR=0.0.0.0:5000
      - REGISTRY_HTTP_SECRET=${SECRET}
      - REGISTRY_HTTP_TLS_KEY=/etc/ssl/certs/registry/${KEY_FILE}
      - REGISTRY_HTTP_TLS_CERTIFICATE=/etc/ssl/certs/registry/${CRT_FILE}
EOF

docker swarm init
docker stack deploy registry -c docker-compose.yml

sleep 30
sudo docker system prune -a -f &

echo validationg container status
CID=$(docker ps | grep "registry_registry.1\." | head -c 12)
STATUS=$(docker inspect ${CID} | jq ".[0].State.Status" | xargs)
if [[ ! $STATUS == "running" ]]; then 
    exit $ERR_REGISTRY_NOT_RUNNING
fi
