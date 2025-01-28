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
  
  WEBUI_INGRESS_HOST=webui.example.com
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

install_certmanager_crds() {
  echo
  echo "COMMAND: kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.6.2/cert-manager.crds.yaml"
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.6.2/cert-manager.crds.yaml
  echo
}

create_owui_custom_overrides_file() {
  echo "Writing out owui_custom_overrides.yaml file ..."
  echo
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
  ollama:
    models:" > owui_custom_overrides.yaml

  if ! [ -z ${OLLAMA_MODEL_0} ]
  then
    echo "      - \"${OLLAMA_MODEL_0}\" " >> owui_custom_overrides.yaml
  fi

  if ! [ -z ${OLLAMA_MODEL_1} ]
  then
    echo "      - \"${OLLAMA_MODEL_1}\" " >> owui_custom_overrides.yaml
  fi

  if ! [ -z ${OLLAMA_MODEL_2} ]
  then
    echo "      - \"${OLLAMA_MODEL_2}\" " >> owui_custom_overrides.yaml
  fi

  if ! [ -z ${OLLAMA_MODEL_3} ]
  then
    echo "      - \"${OLLAMA_MODEL_3}\" " >> owui_custom_overrides.yaml
  fi

  if ! [ -z ${OLLAMA_MODEL_4} ]
  then
    echo "      - \"${OLLAMA_MODEL_4}\" " >> owui_custom_overrides.yaml
  fi

}

#no_gpu() {
#  echo "COMMAND: 
#  helm install open-webui \
#    -n ${SUSE_AI_NAMESPACE} --create-namespace \
#    --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
#    --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
#    --set 'ingress.host'=${WEBUI_INGRESS_HOST} \
#    --set 'ollama.ollama.models[0]'=${OLLAMA_MODEL_0} \
#    --set 'ollama.ollama.models[1]'=${OLLAMA_MODEL_1} \
#    --set 'ollama.defaultModel'=${OLLAMA_MODEL_0} \
#    oci://dp.apps.rancher.io/charts/open-webui"
# 
#  helm install open-webui \
#    -n ${SUSE_AI_NAMESPACE} --create-namespace \
#    --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
#    --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
#    --set 'ingress.host'=${WEBUI_INGRESS_HOST} \
#    --set 'ollama.ollama.models[0]'=${OLLAMA_MODEL_0} \
#    --set 'ollama.ollama.models[1]'=${OLLAMA_MODEL_1} \
#    --set 'ollama.defaultModel'=${OLLAMA_MODEL_0} \
#    oci://dp.apps.rancher.io/charts/open-webui
# 
#  echo
#}

with_nvidia_gpu() {
  echo "    gpu:
      enabled: true
      type: nvidia
      number: 1
    runtimeClassName: nvidia
" >> owui_custom_overrides.yaml

  #echo "COMMAND:
  #helm install open-webui \
  #  -n ${SUSE_AI_NAMESPACE} --create-namespace \
  #  --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
  #  --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
  #  --set 'ingress.host'=${WEBUI_INGRESS_HOST} \
  #  --set 'ollama.ollama.gpu.enabled'=true \
  #  --set 'ollama.ollama.gpu.type'=nvidia \
  #  --set 'ollama.ollama.gpu.number'=1 \
  #  --set 'ollama.runtimeClassName'=nvidia \
  #  --set 'ollama.ollama.models[0]'=${OLLAMA_MODEL_0} \
  #  --set 'ollama.ollama.models[1]'=${OLLAMA_MODEL_1} \
  #  --set 'ollama.defaultModel'=${OLLAMA_MODEL_0} \
  #  oci://dp.apps.rancher.io/charts/open-webui"

  #helm install open-webui \
  #  -n ${SUSE_AI_NAMESPACE} --create-namespace \
  #  --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
  #  --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
  #  --set 'ingress.host'=${WEBUI_INGRESS_HOST} \
  #  --set 'ollama.ollama.gpu.enabled'=true \
  #  --set 'ollama.ollama.gpu.type'=nvidia \
  #  --set 'ollama.ollama.gpu.number'=1 \
  #  --set 'ollama.runtimeClassName'=nvidia \
  #  --set 'ollama.ollama.models[0]'=${OLLAMA_MODEL_0} \
  #  --set 'ollama.ollama.models[1]'=${OLLAMA_MODEL_1} \
  #  --set 'ollama.defaultModel'=${OLLAMA_MODEL_0} \
  #  oci://dp.apps.rancher.io/charts/open-webui
}

with_milvus() {
  echo "extraEnvVars:
- name: VECTOR_DB
  value: milvus
- name: MILVUS_URI
  value:  http://milvus.${SUSE_AI_NAMESPACE}.svc.cluster.local:19530
" >> owui_custom_overrides.yaml

  #echo "COMMAND:
  #helm install open-webui \
  #  -n ${SUSE_AI_NAMESPACE} --create-namespace \
  #  --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
  #  --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
  #  --set 'ingress.host'=${WEBUI_INGRESS_HOST} \
  #  --set 'ollama.ollama.gpu.enabled'=true \
  #  --set 'ollama.ollama.gpu.type'=nvidia \
  #  --set 'ollama.ollama.gpu.number'=1 \
  #  --set 'ollama.runtimeClassName'=nvidia \
  #  --set 'ollama.ollama.models[0]'=${OLLAMA_MODEL_0} \
  #  --set 'ollama.ollama.models[1]'=${OLLAMA_MODEL_1} \
  #  --set 'ollama.defaultModel'=${OLLAMA_MODEL_0} \
  #  --set 'extraEnvVars[0].name'=VECTOR_DB --set 'extraEnvVars[0].value'=milvus \
  #  --set 'extraEnvVars[1].name'=MILVUS_URI \
  #  --set-string 'extraEnvVars[1].value'=http://${MILVUS_HOST} \
  #  oci://dp.apps.rancher.io/charts/open-webui"

  #helm install open-webui \
  #  -n ${SUSE_AI_NAMESPACE} --create-namespace \
  #  --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} \
  #  --set 'persistence.storageClass'=${STORAGE_CLASS_NAME} \
  #  --set 'ingress.host'=${WEBUI_INGRESS_HOST} \
  #  --set 'ollama.ollama.gpu.enabled'=true \
  #  --set 'ollama.ollama.gpu.type'=nvidia \
  #  --set 'ollama.ollama.gpu.number'=1 \
  #  --set 'ollama.runtimeClassName'=nvidia \
  #  --set 'ollama.ollama.models[0]'=${OLLAMA_MODEL_0} \
  #  --set 'ollama.ollama.models[1]'=${OLLAMA_MODEL_1} \
  #  --set 'ollama.defaultModel'=${OLLAMA_MODEL_0} \
  #  --set 'extraEnvVars[0].name'=VECTOR_DB --set 'extraEnvVars[0].value'=milvus \
  #  --set 'extraEnvVars[1].name'=MILVUS_URI \
  #  --set-string 'extraEnvVars[1].value'=http://${MILVUS_HOST} \
  #  oci://dp.apps.rancher.io/charts/open-webui
}

install_open_webui() {
  cat owui_custom_overrides.yaml
  echo
  echo "COMMAND:
  helm install open-webui \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f owui_custom_overrides.yaml \
    oci://dp.apps.rancher.io/charts/open-webui"

  helm install open-webui \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f owui_custom_overrides.yaml \
    oci://dp.apps.rancher.io/charts/open-webui

  echo
}

##############################################################################


case ${1} in
  custom_overrides_only)
    log_into_app_collection
    create_owui_custom_overrides_file
    with_nvidia_gpu
    with_milvus
    cat owui_custom_overrides.yaml
  ;;
  without_gpu)
    install_certmanager_crds
    log_into_app_collection
    create_owui_custom_overrides_file
    install_open_webui
  ;;
  with_gpu)
    install_certmanager_crds
    log_into_app_collection
    create_owui_custom_overrides_file
    with_nvidia_gpu
    install_open_webui
  ;;
  with_gpu_and_milvus)
    install_certmanager_crds
    log_into_app_collection
    create_owui_custom_overrides_file
    with_nvidia_gpu
    with_milvus
    install_open_webui
  ;;
  *)
    echo "ERROR:  Must supply one of the following: "
    echo "          without_gpu            (install without GPU support enabled)"
    echo "          with_gpu               (install with GPU support enabled)"
    echo "          with_gpu_and_milvus    (install with GPU support and Milvus enabled)"
    echo "          custom_overrides_only  (only write out the owui_custom_overrides.yaml file)"
    echo
    echo "Example: ${0} without_gpu"
    echo "         ${0} with_gpu"
    echo "         ${0} with_gpu_and_milvus"
    echo "         ${0} custom_overrides_only"
    echo
    exit
  ;;
esac

