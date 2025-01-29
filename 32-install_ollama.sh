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
# set the them in this script.

CONFIG_FILE=deploy_suse_ai.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  SUSE_AI_NAMESPACE=suse-ai
  IMAGE_PULL_SECRET_NAME=application-collection
  STORAGE_CLASS_NAME=longhorn
  
  OLLAMA_INGRESS_HOST=ollama.example.com
  OLLAMA_MODEL_0=llama3.2
  OLLAMA_MODEL_1=gemma:2b
  OLLAMA_MODEL_2=
  OLLAMA_MODEL_3=
  OLLAMA_MODEL_4=
  MILVUS_URI=milvus.example.com
fi

LICENSES_FILE=authentication_and_licenses.cfg

##############################################################################

log_into_app_collection() {
  if [ -z ${APP_COLLECTION_USERNAME} ]
  then
    # The APP_COLLECTION_URI, APP_COLLECTION_USERNAME and APP_COLLECTION_PASSWORD
    # variables are set in an external file and are sourced in here:
    source ${LICENSES_FILE}
  fi

  echo "Logging into the Application Collection ..."
  echo "COMMAND: helm registry login dp.apps.rancher.io/charts -u ${APP_COLLECTION_USERNAME} -p ${APP_COLLECTION_PASSWORD}"
  helm registry login dp.apps.rancher.io/charts -u ${APP_COLLECTION_USERNAME} -p ${APP_COLLECTION_PASSWORD}
  echo
}

create_ollama_custom_overrides_file() {
  echo "Writing out ollama_custom_overrides.yaml file ..."
  echo "
global:
  imagePullSecrets:
  - ${IMAGE_PULL_SECRET_NAME}
persistence:
  enabled: true
  storageClass: ${STORAGE_CLASS_NAME}
ingress:
  host: ${WEBUI_INGRESS_HOST}
ollama:
  defaultModel: ${OLLAMA_MODEL_0}
  models:" > ollama_custom_overrides.yaml

  if ! [ -z ${OLLAMA_MODEL_0} ]
  then
    echo "    - \"${OLLAMA_MODEL_0}\" " >> ollama_custom_overrides.yaml
  fi

  if ! [ -z ${OLLAMA_MODEL_1} ]
  then
    echo "    - \"${OLLAMA_MODEL_1}\" " >> ollama_custom_overrides.yaml
  fi

  if ! [ -z ${OLLAMA_MODEL_2} ]
  then
    echo "    - \"${OLLAMA_MODEL_2}\" " >> ollama_custom_overrides.yaml
  fi

  if ! [ -z ${OLLAMA_MODEL_3} ]
  then
    echo "    - \"${OLLAMA_MODEL_3}\" " >> ollama_custom_overrides.yaml
  fi

  if ! [ -z ${OLLAMA_MODEL_4} ]
  then
    echo "    - \"${OLLAMA_MODEL_4}\" " >> ollama_custom_overrides.yaml
  fi
}


#no_gpu() {
#  echo "COMMAND: 
#  helm install ollama \
#    -n ${SUSE_AI_NAMESPACE} --create-namespace \
#    --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
#    --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
#    --set 'ingress.host'=${INGRESS_HOST} \
#    --set 'ollama.models[0]'=${OLLAMA_MODEL_0} \
#    oci://dp.apps.rancher.io/charts/ollama"
# 
#  helm install ollama \
#    -n ${SUSE_AI_NAMESPACE} --create-namespace \
#    --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
#    --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
#    --set 'ingress.host'=${INGRESS_HOST} \
#    --set 'ollama.models[0]'=${OLLAMA_MODEL_0} \
#    oci://dp.apps.rancher.io/charts/ollama
# 
#  echo
#}

with_nvidia_gpu() {
  echo "  gpu:
    enabled: true
    type: nvidia
    number: 1
  runtimeClassName: nvidia
" >> ollama_custom_overrides.yaml

  #echo "COMMAND:
  #helm install ollama \
  #  -n ${SUSE_AI_NAMESPACE} --create-namespace \
  #  --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
  #  --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
  #  --set 'ollama.gpu.enabled'=true \
  #  --set 'ollama.gpu.type'=nvidia \
  #  --set 'ollama.gpu.number'=1 \
  #  --set 'ollama.runtimeClassName'=nvidia \
  #  --set 'ollama.models[0]'=${OLLAMA_MODEL_0} \
  #  oci://dp.apps.rancher.io/charts/ollama"

  #helm install ollama \
  #  -n ${SUSE_AI_NAMESPACE} --create-namespace \
  #  --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
  #  --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
  #  --set 'ollama.gpu.enabled'=true \
  #  --set 'ollama.gpu.type'=nvidia \
  #  --set 'ollama.gpu.number'=1 \
  #  --set 'ollama.runtimeClassName'=nvidia \
  #  --set 'ollama.models[0]'=${OLLAMA_MODEL_0} \
  #  oci://dp.apps.rancher.io/charts/ollama
}

with_ingress() {
  echo "  ingress:
    enabled: true
    hosts:
      - host: ${OLLAMA_INGRESS_HOST}
        paths: 
          - path: /
            pathType: Prefix
" >> ollama_custom_overrides.yaml

  #echo "COMMAND:
  #helm install ollama \
  #  -n ${SUSE_AI_NAMESPACE} --create-namespace \
  #  --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
  #  --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
  #  --set 'ingress.enabled'=true \
  #  --set 'ingress.hosts[0].host'=${OLLAMA_INGRESS_HOST} \
  #  --set 'ingress.hosts[0].host.paths[0].path'=/ \
  #  --set 'ingress.hosts[0].host.paths[0].pathType'=Prefix \
  #  --set 'ollama.gpu.enabled'=true \
  #  --set 'ollama.gpu.type'=nvidia \
  #  --set 'ollama.gpu.number'=1 \
  #  --set 'ollama.runtimeClassName'=nvidia \
  #  --set 'ollama.models[0]'=${OLLAMA_MODEL_0} \
  #  oci://dp.apps.rancher.io/charts/ollama"

  #helm install ollama \
  #  -n ${SUSE_AI_NAMESPACE} --create-namespace \
  #  --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
  #  --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
  #  --set 'ingress.enabled'=true \
  #  --set 'ingress.hosts[0].host'=${OLLAMA_INGRESS_HOST} \
  #  --set 'ingress.hosts[0].host.paths[0].path'=/ \
  #  --set 'ingress.hosts[0].host.paths[0].pathType'=Prefix \
  #  --set 'ollama.gpu.enabled'=true \
  #  --set 'ollama.gpu.type'=nvidia \
  #  --set 'ollama.gpu.number'=1 \
  #  --set 'ollama.runtimeClassName'=nvidia \
  #  --set 'ollama.models[0]'=${OLLAMA_MODEL_0} \
  #  oci://dp.apps.rancher.io/charts/ollama
}

install_ollama() {
  cat ollama_custom_overrides.yaml
  echo
  echo "COMMAND:
  helm install ollama \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f ollama_custom_overrides.yam \
    oci://dp.apps.rancher.io/charts/ollama"

  helm install ollama \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f ollama_custom_overrides.yaml \
    oci://dp.apps.rancher.io/charts/ollama

  echo
}

##############################################################################

case ${1} in
  custom_overrides_only)
    log_into_app_collection
    create_ollama_custom_overrides_file
    with_nvidia_gpu
    with_ingress
  ;;
  without_gpu)
    log_into_app_collection
    create_ollama_custom_overrides_file
    install_ollama
  ;;
  with_gpu)
    log_into_app_collection
    with_nvidia_gpu
    install_ollama
  ;;
  with_gpu_and_ingress)
    log_into_app_collection
    with_nvidia_gpu
    with_ingress
    install_ollama
  ;;
  *)
    echo "ERROR:  Must supply one of the following: "
    echo
    echo "          without_gpu           (install without GPU support enabled)"
    echo "          with_gpu              (install with GPU support enabled)"
    echo "          with_gpu_and_ingress  (install with GPU support enabled and configure an ingress to Ollama)"
    echo "          custom_overrides_only (only write out the ollama_custom_overrides.yaml file)"
    echo
    echo "Example: ${0} without_gpu"
    echo "         ${0} with_gpu"
    echo "         ${0} with_gpu_and_ingress"
    echo "         ${0} custom_overrides_only"
    echo
    exit
  ;;
esac

