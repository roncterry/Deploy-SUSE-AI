#!/bin/bash

##############################################################################

if ! which kubectl > /dev/null
then
  echo
  echo "ERROR: This must be run on a machine with the kubectl and helm commands installed."
  echo "       Run this script on a control plane node or management machine."
  echo
  echo "       Exiting."
  echo
  exit
fi

if ! which helm > /dev/null
then
  echo
  echo "ERROR: This must be run on a machine with the kubectl and helm commands installed."
  echo "       Run this script on a control plane node or management machine."
  echo
  echo "       Exiting."
  echo
  exit
fi

##############################################################################

# You can either source in the variables from a common config file or
# uncomment the following variables to set them in this script.

source deploy_suse_ai.cfg

#SUSE_AI_NAMESPACE=suse-ai
#IMAGE_PULL_SECRET_NAME=application-collection
#STORAGE_CLASS_NAME=longhorn

#OLLAMA_INGRESS_HOST=ollama.example.com
#OLLAMA_MODEL_0=llama3.2
#MILVUS_URI=milvus.example.com

##############################################################################

log_into_app_collection() {
  if [ -z ${APP_COLLECTION_USERNAME} ]
  then
    # The APP_COLLECTION_URI, APP_COLLECTION_USERNAME and APP_COLLECTION_PASSWORD
    # variables are set in an external file and are sourced in here:
    source authentication_and_licenses.cfg
  fi

  echo "COMMAND: helm registry login dp.apps.rancher.io/charts -u ${APP_COLLECTION_USERNAME} -p ${APP_COLLECTION_PASSWORD}"
  helm registry login dp.apps.rancher.io/charts -u ${APP_COLLECTION_USERNAME} -p ${APP_COLLECTION_PASSWORD}
  echo
}


no_gpu() {
  echo "COMMAND: 
  helm install ollama \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
    --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
    --set 'ingress.host'=${INGRESS_HOST} \
    --set 'ollama.models[0]'=${OLLAMA_MODEL_0} \
    oci://dp.apps.rancher.io/charts/ollama"

  helm install ollama \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
    --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
    --set 'ingress.host'=${INGRESS_HOST} \
    --set 'ollama.models[0]'=${OLLAMA_MODEL_0} \
    oci://dp.apps.rancher.io/charts/ollama

  echo
}

with_nvidia_gpu() {
  echo "COMMAND:
  helm install ollama \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
    --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
    --set 'ollama.gpu.enabled'=true \
    --set 'ollama.gpu.type'=nvidia \
    --set 'ollama.gpu.number'=1 \
    --set 'ollama.runtimeClassName'=nvidia \
    --set 'ollama.models[0]'=${OLLAMA_MODEL_0} \
    oci://dp.apps.rancher.io/charts/ollama"

  helm install ollama \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
    --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
    --set 'ollama.gpu.enabled'=true \
    --set 'ollama.gpu.type'=nvidia \
    --set 'ollama.gpu.number'=1 \
    --set 'ollama.runtimeClassName'=nvidia \
    --set 'ollama.models[0]'=${OLLAMA_MODEL_0} \
    oci://dp.apps.rancher.io/charts/ollama

  echo
}

with_gpu_and_ingress() {
  echo "COMMAND:
  helm install ollama \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
    --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
    --set 'ingress.enabled'=true \
    --set 'ingress.hosts[0].host'=${OLLAMA_INGRESS_HOST} \
    --set 'ingress.hosts[0].host.paths[0].path'=/ \
    --set 'ingress.hosts[0].host.paths[0].pathType'=Prefix \
    --set 'ollama.gpu.enabled'=true \
    --set 'ollama.gpu.type'=nvidia \
    --set 'ollama.gpu.number'=1 \
    --set 'ollama.runtimeClassName'=nvidia \
    --set 'ollama.models[0]'=${OLLAMA_MODEL_0} \
    oci://dp.apps.rancher.io/charts/ollama"

  helm install ollama \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
    --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
    --set 'ingress.enabled'=true \
    --set 'ingress.hosts[0].host'=${OLLAMA_INGRESS_HOST} \
    --set 'ingress.hosts[0].host.paths[0].path'=/ \
    --set 'ingress.hosts[0].host.paths[0].pathType'=Prefix \
    --set 'ollama.gpu.enabled'=true \
    --set 'ollama.gpu.type'=nvidia \
    --set 'ollama.gpu.number'=1 \
    --set 'ollama.runtimeClassName'=nvidia \
    --set 'ollama.models[0]'=${OLLAMA_MODEL_0} \
    oci://dp.apps.rancher.io/charts/ollama

  echo
}

##############################################################################

case ${1} in
  without_gpu)
    no_gpu
  ;;
  with_gpu)
    with_nvidia_gpu
  ;;
  with_gpu_and_ingress)
    with_gpu_and_ingress
  ;;
  *)
    echo "ERROR:  Must supply one of the following: without_gpu, with_gpu or with_gpu_and_ingress"
    echo
    echo "Example: ${0} without_gpu"
    echo "         ${0} with_gpu"
    echo "         ${0} with_gpu_and_ingress"
    echo
    exit
  ;;
esac

