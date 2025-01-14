#!/bin/bash

MILVUS_PVC_LIST=$(kubectl -n suse-ai get pvc | grep milvus | awk '{ print $1 }')

source deploy_suse_ai.cfg

for MILVUS_PVC in ${MILVUS_PVC_LIST}
do
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} delete pvc ${MILVUS_PVC}"
  kubectl -n ${SUSE_AI_NAMESPACE} delete pvc ${MILVUS_PVC}
  echo
done

