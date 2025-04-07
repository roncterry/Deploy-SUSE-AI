#!/bin/bash

CONFIG_FILE=deploy_suse_observability.cfg

if [ -z ${1} ]
then
  echo
  echo "ERROR: You must supply the cluster FQDN."
  echo
  echo "       Example: ${0} observability.labdemos.org"
  echo
  echo "Exiting ..."
  echo
  exit
else
  if echo ${1} | grep -q ".*\..*".
  then
    CLUSTER_NAME=$(echo ${1} | cut -d . -f 1)
    DOMAIN=$(echo ${1} | sed s/${CLUSTER_NAME}.//)
    echo
    echo "+==========================================="
    echo "| Cluster name:  ${CLUSTER_NAME}"
    echo "| Domain Name=   ${DOMAIN}"
    echo "+==========================================="
    echo
  else
    echo
    echo "ERROR: ${1} does not appear to be an FQDN"
    echo
    echo "       You must supply the cluster FQDN."
    echo
    echo "       Example: ${0} observability.labdemos.org"
    echo
    echo "Exiting ..."
    echo
    exit
  fi
fi

echo "=============================================================================="
echo " Updating ${CONFIG_FILE} ..."
echo "=============================================================================="
echo

echo "COMMAND: sed -i \"s/export CLUSTER_NAME=.*/export CLUSTER_NAME=${CLUSTER_NAME}/g\" ${CONFIG_FILE}"
sed -i "s/export CLUSTER_NAME=.*/export CLUSTER_NAME=${CLUSTER_NAME}/g" ${CONFIG_FILE}
echo

echo "COMMAND: sed -i \"s/export DOMAIN_NAME=.*/export DOMAIN_NAME=${DOMAIN}/g\" ${CONFIG_FILE}"
sed -i "s/export DOMAIN_NAME=.*/export DOMAIN_NAME=${DOMAIN}/g" ${CONFIG_FILE}
echo

echo "COMMAND: sed -i \"s/export OBSERVABILITY_HOST=.*/export OBSERVABILITY_HOST=${CLUSTER_NAME}.${DOMAIN}/g\" ${CONFIG_FILE}"
sed -i "s/export OBSERVABILITY_HOST=.*/export OBSERVABILITY_HOST=${CLUSTER_NAME}.${DOMAIN}/g" ${CONFIG_FILE}
echo

echo "=============================================================================="
echo " Installing SUSE Observability ..."
echo "=============================================================================="
echo

echo "+----------------------------------------------------------------------------+"
echo "| 03a-install_first_rke2_server-observability_cluster.sh "
echo "+----------------------------------------------------------------------------+"
echo
bash 03a-install_first_rke2_server-observability_cluster.sh 
echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "+----------------------------------------------------------------------------+"
echo "| 04-install_longhorn-observability_cluster.sh " 
echo "+----------------------------------------------------------------------------+"
echo
bash 04-install_longhorn-observability_cluster.sh 
echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "+----------------------------------------------------------------------------+"
echo "| 05-install_cert-manager-observability_cluster.sh " 
echo "+----------------------------------------------------------------------------+"
echo
bash 05-install_cert-manager-observability_cluster.sh 
echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "+----------------------------------------------------------------------------+"
echo "| 06-install_observability.sh " 
echo "+----------------------------------------------------------------------------+"
echo
bash 06-install_observability.sh 
echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo

source ${CONFIG_FILE}

echo "##############################################################################"
echo
#watch kubectl -n ${OBSERVABILITY_NAMESPACE} get all
kubectl -n ${OBSERVABILITY_NAMESPACE} get all
echo
echo "##############################################################################"

echo
echo "=============================================================================="
echo "  You can access SUSE Observability at: https://${CLUSTER_NAME}.${DOMAIN}"
echo 
echo "  Log in using the following credentials: "
echo "    Admin Username: ${OBSERVABILITY_ADMIN_USERNAME}"
echo "    Admin Password: ${OBSERVABILITY_ADMIN_PASSWORD}"

if ! [ -z "${OBSERVABILITY_USERS_LIST}" ]
then
  for OBSV_USER in ${OBSERVABILITY_USERS_LIST}
  do
    OBSV_USER_NAME=$(echo ${OBSV_USER} | cut -d : -f 1)
    OBSV_USER_PASSWD=$(echo ${OBSV_USER} | cut -d : -f 2)
    OBSV_USER_ROLE=$(echo ${OBSV_USER} | cut -d : -f 3)
    echo 
    echo "    Username: ${OBSV_USER_NAME}"
    echo "    Password: ${OBSV_USER_PASSWD}"
    echo "    (User's role: ${OBSV_USER_ROLE})"
  done
fi

echo "=============================================================================="
echo

