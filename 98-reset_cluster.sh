#!/bin/bash

source deploy_suse_ai.cfg

echo
echo "Resetting the Cluster ..."
echo
echo "COMMAND: helm -n ${SUSE_AI_NAMESPACE} uninstall open-webui"
helm -n ${SUSE_AI_NAMESPACE} uninstall open-webui
echo

echo "COMMAND: helm -n ${SUSE_AI_NAMESPACE} uninstall ollama"
helm -n ${SUSE_AI_NAMESPACE} uninstall ollama
echo

echo "COMMAND: helm -n ${SUSE_AI_NAMESPACE} uninstall milvus"
helm -n ${SUSE_AI_NAMESPACE} uninstall milvus
echo

echo "COMMAND: kubectl delete namespace ${SUSE_AI_NAMESPACE}"
kubectl delete namespace ${SUSE_AI_NAMESPACE}
echo

echo "COMMAND: helm -n gpu-operator uninstall gpu-operator"
helm -n gpu-operator uninstall gpu-operator
echo

echo "COMMAND: kubectl delete namespace gpu-operator"
kubectl delete namespace gpu-operator
echo
