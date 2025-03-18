#!/bin/bash

CONFIG_FILE=deploy_rancher.cfg

if [ -z ${1} ]
then
  echo
  echo "ERROR: You must supply the cluster FQDN."
  echo
  echo "       Example: ${0} rancher.labdemos.org"
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
    echo "       Example: ${0} rancher.labdemos.org"
    echo
    echo "Exiting ..."
    echo
    exit
  fi
fi

echo "------------------------------------------------------------------------------"
echo " Updating ${CONFIG_FILE} ..."
echo "------------------------------------------------------------------------------"
echo

echo "COMMAND: sed -i \"s/export CLUSTER_NAME=.*/export CLUSTER_NAME=${CLUSTER_NAME}/g\" ${CONFIG_FILE}"
sed -i "s/export CLUSTER_NAME=.*/export CLUSTER_NAME=${CLUSTER_NAME}/g" ${CONFIG_FILE}
echo

echo "COMMAND: sed -i \"s/export DOMAIN_NAME=.*/export DOMAIN_NAME=${DOMAIN}/g\" ${CONFIG_FILE}"
sed -i "s/export DOMAIN_NAME=.*/export DOMAIN_NAME=${DOMAIN}/g" ${CONFIG_FILE}
echo

echo "COMMAND: sed -i \"s/export RANCHER_HOSTNAME=.*/export RANCHER_HOSTNAME=${CLUSTER_NAME}.${DOMAIN}/g\" ${CONFIG_FILE}"
sed -i "s/export RANCHER_HOSTNAME=.*/export RANCHER_HOSTNAME=${CLUSTER_NAME}.${DOMAIN}/g" ${CONFIG_FILE}
echo

echo "------------------------------------------------------------------------------"
echo " Installing Rancher Manager ..."
echo "------------------------------------------------------------------------------"
echo

echo "[01a-install_first_rke2_server-rancher_cluster.sh]"
bash 01a-install_first_rke2_server-rancher_cluster.sh 
echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "[02-install_rancher_with_helm.sh]" 
bash 02-install_rancher_with_helm.sh 
echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo
echo "=============================================================================="
echo "  You can access Rancher Manager at: https://${CLUSTER_NAME}.${DOMAIN}"
echo 
echo "  Log in using the following credentials: "
echo "    Admin Username: admin"
echo "    Admin Password: ${RANCHER_ADMIN_PW}"
echo "=============================================================================="
echo

source ${CONFIG_FILE}

echo "##############################################################################"
echo
#watch kubectl -n cattle-system get all
kubectl -n cattle-system get all
echo
echo "##############################################################################"
echo

