#!/bin/sh -x

echo ADMIN_USER_NAME: ${ADMIN_USER_NAME}
echo REGISTRY_STORAGE_AZURE_ACCOUNTNAME: ${REGISTRY_STORAGE_AZURE_ACCOUNTNAME}
echo REGISTRY_STORAGE_AZURE_ACCOUNTKEY: ${REGISTRY_STORAGE_AZURE_ACCOUNTKEY}
echo REGISTRY_STORAGE_AZURE_CONTAINER: ${REGISTRY_STORAGE_AZURE_CONTAINER}
echo REGISTRY_STORAGE_AZURE_REALM: ${REGISTRY_STORAGE_AZURE_REALM}
echo CERT_FINGERPRINT: ${CERT_FINGERPRINT}

UBUNTU_RELEASE=$(lsb_release -r -s)

# install docker
apt update && apt install curl -y

curl https://packages.microsoft.com/config/ubuntu/${UBUNTU_RELEASE}/prod.list > /tmp/microsoft-prod.list
cp /tmp/microsoft-prod.list /etc/apt/sources.list.d/

curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
cp /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/

apt update && apt install moby-engine moby-cli --allow-downgrades -y

# docker post-install
usermod -aG docker ${ADMIN_USER_NAME}

# add azure stack certs to ca store
AZS_CERT_SRC_PATH="/var/lib/waagent/Certificates.pem"
AZS_CERT_DST_PATH="/usr/local/share/ca-certificates/azsCertificate.crt"
cp $AZS_CERT_SRC_PATH $AZS_CERT_DST_PATH
update-ca-certificates

# move key vault certs
CRT_FILE="${CERT_FINGERPRINT}.crt"
KEY_FILE="${CERT_FINGERPRINT}.prv"
STORE="/etc/ssl/certs/registry"

mkdir -p $STORE
mv /var/lib/waagent/$CRT_FILE /var/lib/waagent/$KEY_FILE $STORE

# start registry container
# https://docs.docker.com/registry/storage-drivers/azure/
docker run -d \
  --name registry \
  --restart=always \
  -p 443:5000 \
  -v /etc/ssl/certs:/etc/ssl/certs:ro \
  -e REGISTRY_STORAGE="azure" \
  -e REGISTRY_STORAGE_AZURE_ACCOUNTNAME=${REGISTRY_STORAGE_AZURE_ACCOUNTNAME} \
  -e REGISTRY_STORAGE_AZURE_ACCOUNTKEY=${REGISTRY_STORAGE_AZURE_ACCOUNTKEY} \
  -e REGISTRY_STORAGE_AZURE_CONTAINER=${REGISTRY_STORAGE_AZURE_CONTAINER} \
  -e REGISTRY_STORAGE_AZURE_REALM=${REGISTRY_STORAGE_AZURE_REALM} \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
  -e REGISTRY_HTTP_TLS_KEY=/etc/ssl/certs/registry/${KEY_FILE} \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/etc/ssl/certs/registry/${CRT_FILE} \
  registry:2
