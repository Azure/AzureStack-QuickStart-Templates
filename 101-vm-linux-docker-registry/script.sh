#!/bin/bash -x

ERR_MISSING_CRT_FILE=10 # Bad cert thumbprint OR pfx not in key vault OR template misconfigured VM secrets section
ERR_MISSING_KEY_FILE=11 # Bad cert thumbprint OR pfx not in key vault OR template misconfigured VM secrets section
ERR_REGISTRY_NOT_RUNNING=13 # the container registry failed to start successfully

echo ADMIN_USER_NAME:                    ${ADMIN_USER_NAME}
echo REGISTRY_STORAGE_AZURE_ACCOUNTNAME: ${REGISTRY_STORAGE_AZURE_ACCOUNTNAME}
echo REGISTRY_STORAGE_AZURE_ACCOUNTKEY:  ${REGISTRY_STORAGE_AZURE_ACCOUNTKEY}
echo REGISTRY_STORAGE_AZURE_CONTAINER:   ${REGISTRY_STORAGE_AZURE_CONTAINER}
echo CERT_THUMBPRINT:                    ${CERT_THUMBPRINT}
echo FQDN:                               ${FQDN}
echo LOCATION:                           ${LOCATION}
echo PIP_LABEL:                          ${PIP_LABEL}

EXTERNAL_FQDN="${FQDN//$PIP_LABEL.$LOCATION.cloudapp.}"
REGISTRY_STORAGE_AZURE_REALM=${LOCATION}.${EXTERNAL_FQDN}
CRT_FILE="${CERT_THUMBPRINT}.crt"
KEY_FILE="${CERT_THUMBPRINT}.prv"

# TODO remove when VHD ready
echo installing dependencies
apt update && apt install curl jq -y

# TODO remove when VHD ready
echo adding ms docker sources
UBUNTU_RELEASE=$(lsb_release -r -s)
curl https://packages.microsoft.com/config/ubuntu/${UBUNTU_RELEASE}/prod.list > /tmp/microsoft-prod.list
cp /tmp/microsoft-prod.list /etc/apt/sources.list.d/
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
cp /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/

# TODO remove when VHD ready
echo installing ms docker
apt update && apt install moby-engine moby-cli --allow-downgrades -y
usermod -aG docker ${ADMIN_USER_NAME}

echo validating dependencies
if [ ! -f "/var/lib/waagent/${CRT_FILE}" ]; then
    exit $ERR_MISSING_CRT_FILE
fi

if [ ! -f "/var/lib/waagent/${KEY_FILE}" ]; then
    exit $ERR_MISSING_KEY_FILE
fi

echo adding certs to the ca-store
CRT_DST_PATH="/usr/local/share/ca-certificates"
cp "/var/lib/waagent/Certificates.pem" "${CRT_DST_PATH}/azsCertificate.crt"
update-ca-certificates

echo copy user cert to mount point
STORE="/etc/ssl/certs/registry"
mkdir -p $STORE
cp "/var/lib/waagent/${CRT_FILE}" "${STORE}/${CRT_FILE}"
cp "/var/lib/waagent/${KEY_FILE}" "${STORE}/${KEY_FILE}"

echo moving .htpasswd to mount point
HTPASSWD_DIR="/root/auth"
mkdir -p $HTPASSWD_DIR
mv .htpasswd $HTPASSWD_DIR

echo starting registry container
docker run -d \
  --name registry \
  --restart=always \
  -p 443:5000 \
  -v /etc/ssl/certs:/etc/ssl/certs:ro \
  -v /root/auth:/auth \
  -e REGISTRY_STORAGE="azure" \
  -e REGISTRY_STORAGE_AZURE_ACCOUNTNAME=${REGISTRY_STORAGE_AZURE_ACCOUNTNAME} \
  -e REGISTRY_STORAGE_AZURE_ACCOUNTKEY=${REGISTRY_STORAGE_AZURE_ACCOUNTKEY} \
  -e REGISTRY_STORAGE_AZURE_CONTAINER=${REGISTRY_STORAGE_AZURE_CONTAINER} \
  -e REGISTRY_STORAGE_AZURE_REALM=${REGISTRY_STORAGE_AZURE_REALM} \
  -e REGISTRY_AUTH="htpasswd" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/.htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
  -e REGISTRY_HTTP_TLS_KEY=/etc/ssl/certs/registry/${KEY_FILE} \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/etc/ssl/certs/registry/${CRT_FILE} \
  registry:2.7.1

echo waiting for container to start
sleep 10

echo validationg container status
STATUS=$(docker inspect registry | jq ".[0].State.Status" | xargs)
if [[ ! $STATUS == "running" ]]; then 
    exit $ERR_REGISTRY_NOT_RUNNING
fi
