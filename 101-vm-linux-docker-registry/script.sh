#!/bin/bash -x

ERR_APT_INSTALL_TIMEOUT=9 # Timeout installing required apt packages
ERR_MISSING_CRT_FILE=10 # Bad cert thumbprint OR pfx not in key vault OR template misconfigured VM secrets section
ERR_MISSING_KEY_FILE=11 # Bad cert thumbprint OR pfx not in key vault OR template misconfigured VM secrets section
ERR_REGISTRY_NOT_RUNNING=13 # the container registry failed to start successfully
ERR_MOBY_APT_LIST_TIMEOUT=25 # Timeout waiting for moby apt sources
ERR_MS_GPG_KEY_DOWNLOAD_TIMEOUT=26 # Timeout waiting for MS GPG key download
ERR_MOBY_INSTALL_TIMEOUT=27 # Timeout waiting for moby install
ERR_MS_PROD_DEB_DOWNLOAD_TIMEOUT=42 # Timeout waiting for https://packages.microsoft.com/config/ubuntu/16.04/packages-microsoft-prod.deb
ERR_MS_PROD_DEB_PKG_ADD_FAIL=43 # Failed to add repo pkg file
ERR_APT_UPDATE_TIMEOUT=99 # Timeout waiting for apt-get update to complete

UBUNTU_RELEASE=$(lsb_release -r -s)
MOBY_VERSION="3.0.6"

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
    retrycmd_if_failure 120 5 25 curl https://packages.microsoft.com/config/ubuntu/${UBUNTU_RELEASE}/prod.list > /tmp/microsoft-prod.list || exit $ERR_MOBY_APT_LIST_TIMEOUT
    retrycmd_if_failure 10  5 10 cp /tmp/microsoft-prod.list /etc/apt/sources.list.d/ || exit $ERR_MOBY_APT_LIST_TIMEOUT
    retrycmd_if_failure 120 5 25 curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg || exit $ERR_MS_GPG_KEY_DOWNLOAD_TIMEOUT
    retrycmd_if_failure 10  5 10 cp /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/ || exit $ERR_MS_GPG_KEY_DOWNLOAD_TIMEOUT
    apt_get_update || exit $ERR_APT_UPDATE_TIMEOUT
    
    apt_get_install 20 30 120 moby-engine=${MOBY_VERSION} moby-cli=${MOBY_VERSION} --allow-downgrades || exit $ERR_MOBY_INSTALL_TIMEOUT
    usermod -aG docker ${ADMIN_USER_NAME}
    
    for apt_package in curl jq; do
      if ! apt_get_install 30 1 600 $apt_package; then
        journalctl --no-pager -u $apt_package
        exit $ERR_APT_INSTALL_TIMEOUT
      fi
    done
}

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

if [ -f /var/log.vhd/azure/golden-image-install.complete ]; then
    echo "golden image; skipping dependencies installation"
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
awk '{ sub("\r$", ""); print }' .htpasswd > .htpasswd.tmp
cp .htpasswd.tmp $HTPASSWD_DIR/.htpasswd

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
