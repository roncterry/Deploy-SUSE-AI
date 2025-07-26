#!/bin/bash

source deploy_suse_ai.cfg

echo
echo "Resetting the Cluster ..."
echo

if helm -n ${SUSE_AI_NAMESPACE} list | awk '{ print $1 }' | grep -q ${SUSE_AI_NAMESPACE}
then
  echo "COMMAND: helm -n ${SUSE_AI_NAMESPACE} uninstall ${SUSE_AI_NAMESPACE}"
  helm -n ${SUSE_AI_NAMESPACE} uninstall ${SUSE_AI_NAMESPACE}
  echo
else
  if helm -n ${SUSE_AI_NAMESPACE} | grep -q open-webui
  then
    echo "COMMAND: helm -n ${SUSE_AI_NAMESPACE} uninstall open-webui"
    helm -n ${SUSE_AI_NAMESPACE} uninstall open-webui
    echo
  fi

  if helm -n ${SUSE_AI_NAMESPACE} | grep -q ollama
  then
    echo "COMMAND: helm -n ${SUSE_AI_NAMESPACE} uninstall ollama"
    helm -n ${SUSE_AI_NAMESPACE} uninstall ollama
    echo
  fi

  if helm -n ${SUSE_AI_NAMESPACE} | grep -q milvus
  then
    echo "COMMAND: helm -n ${SUSE_AI_NAMESPACE} uninstall milvus"
    helm -n ${SUSE_AI_NAMESPACE} uninstall milvus
    echo
  fi

  if helm -n ${SUSE_AI_NAMESPACE} | grep -q pytorch
  then
    echo "COMMAND: helm -n ${SUSE_AI_NAMESPACE} uninstall pytorch"
    helm -n ${SUSE_AI_NAMESPACE} uninstall pytorch
    echo
  fi
fi

echo "COMMAND: kubectl delete namespace ${SUSE_AI_NAMESPACE}"
kubectl delete namespace ${SUSE_AI_NAMESPACE}
echo

echo "COMMAND: helm -n gpu-operator uninstall gpu-operator"
helm -n gpu-operator uninstall gpu-operator
echo

echo "COMMAND: kubectl delete namespace gpu-operator"
kubectl delete namespace gpu-operator
echo
