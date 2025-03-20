#!/bin/bash

CONFIG_FILE=deploy_suse_ai.cfg

if [ -z ${1} ]
then
  echo
  echo "ERROR: You must supply the cluster FQDN."
  echo
  echo "       Example: ${0} aicluster01.labdemos.org"
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
    echo "       Example: ${0} aicluster0.labdemos.org"
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

echo "=============================================================================="
echo " Installing Ollama on SUSE AI ..."
echo "=============================================================================="
echo

echo "+----------------------------------------------------------------------------+"
echo "| 11a-install_first_rke2_server.sh "
echo "+----------------------------------------------------------------------------+"
echo
bash 11a-install_first_rke2_server.sh 
echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "+----------------------------------------------------------------------------+"
echo "| 21-install_nvidia_gpu_operator.sh " 
echo "+----------------------------------------------------------------------------+"
echo
bash 21-install_nvidia_gpu_operator.sh 
echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "+----------------------------------------------------------------------------+"
echo "| 22-install_longhorn.sh " 
echo "+----------------------------------------------------------------------------+"
echo
bash 22-install_longhorn.sh 
echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "+----------------------------------------------------------------------------+"
echo "| 29-connect_to_app_collection.sh " 
echo "+----------------------------------------------------------------------------+"
echo
bash 29-connect_to_app_collection.sh 
echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo

echo "+----------------------------------------------------------------------------+"
echo "| 31-install_ollama.sh with_gpu "
echo "+----------------------------------------------------------------------------+"
echo
bash 31-install_ollama.sh with_gpu.sh
echo
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo

source ${CONFIG_FILE}

echo "##############################################################################"
echo
#watch kubectl -n ${SUSE_AI_NAMESPACE} get all
kubectl -n ${SUSE_AI_NAMESPACE} get all
echo
echo "##############################################################################"

echo
#echo "=============================================================================="
#echo "  You can access Ollama at: https://${CLUSTER_NAME}.${DOMAIN}"
#echo "=============================================================================="
#echo

