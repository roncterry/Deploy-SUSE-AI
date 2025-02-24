#!/bin/bash

source deploy_suse_ai.cfg

helm -n ${SUSE_AI_NAMESPACE} uninstall open-webui
helm -n ${SUSE_AI_NAMESPACE} uninstall ollama
helm -n ${SUSE_AI_NAMESPACE} uninstall milvus
kubectl delete namespace ${SUSE_AI_NAMESPACE}

helm -n gpu-operator uninstall gpu-operator
kubectl delete namespace gpu-operator
