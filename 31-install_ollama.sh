#!/bin/bash

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

CUSTOM_OVERRIDES_FILE=ollama_custom_overrides.yaml

##############################################################################

check_for_kubectl() {
  if ! echo $* | grep -q force
  then
   if ! which kubectl > /dev/null
   then
     echo
     echo "ERROR: This must be run on a machine with the kubectl command installed."
     echo "       Run this script on a control plane node or management machine."
     echo
     echo "       Exiting."
     echo
     exit
   fi
  fi
}

check_for_helm() {
  if ! echo $* | grep -q force
  then
   if ! which helm > /dev/null
   then
     echo
     echo "ERROR: This must be run on a machine with the helm command installed."
     echo "       Run this script on a control plane node or management machine."
     echo
     echo "       Exiting."
     echo
     exit
   fi
  fi
}

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
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} file ..."
  echo "
global:
  imagePullSecrets:
  - ${IMAGE_PULL_SECRET_NAME}
persistence:
  enabled: true
  storageClass: ${STORAGE_CLASS_NAME}
ollama:
  defaultModel: ${OLLAMA_MODEL_0}
  models:
    pull:" > ${CUSTOM_OVERRIDES_FILE}

  if ! [ -z ${OLLAMA_MODEL_0} ]
  then
    echo "    - \"${OLLAMA_MODEL_0}\" " >> ${CUSTOM_OVERRIDES_FILE}
  fi

  if ! [ -z ${OLLAMA_MODEL_1} ]
  then
    echo "    - \"${OLLAMA_MODEL_1}\" " >> ${CUSTOM_OVERRIDES_FILE}
  fi

  if ! [ -z ${OLLAMA_MODEL_2} ]
  then
    echo "    - \"${OLLAMA_MODEL_2}\" " >> ${CUSTOM_OVERRIDES_FILE}
  fi

  if ! [ -z ${OLLAMA_MODEL_3} ]
  then
    echo "    - \"${OLLAMA_MODEL_3}\" " >> ${CUSTOM_OVERRIDES_FILE}
  fi

  if ! [ -z ${OLLAMA_MODEL_4} ]
  then
    echo "    - \"${OLLAMA_MODEL_4}\" " >> ${CUSTOM_OVERRIDES_FILE}
  fi
}

with_nvidia_gpu() {
  echo "  gpu:
    enabled: true
    type: nvidia
    number: 1
  runtimeClassName: nvidia " >> ${CUSTOM_OVERRIDES_FILE}
}

with_ingress() {
  echo "ingress:
  enabled: true
  hosts:
  - host: ${OLLAMA_INGRESS_HOST}
    paths: 
    - path: /
      pathType: Prefix " >> ${CUSTOM_OVERRIDES_FILE}
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

install_ollama() {
  if ! [ -z ${OLLAMA_VERSION} ]
  then
    local OLLAMA_VER_ARG="--version ${OLLAMA_VERSION}"
  fi

  echo
  echo "COMMAND:
  helm upgrade --install ollama \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f ${CUSTOM_OVERRIDES_FILE} \
    oci://dp.apps.rancher.io/charts/ollama ${OLLAMA_VER_ARG}"

  helm upgrade --install ollama \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f ${CUSTOM_OVERRIDES_FILE} \
    oci://dp.apps.rancher.io/charts/ollama ${OLLAMA_VER_ARG}

  echo
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/ollama"
  kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/ollama

  echo
}

usage() {
  echo
  echo "USAGE: ${0} <option>"
  echo
  echo " You must supply one of the following options: "
  echo "   without_gpu           (install without GPU support enabled)"
  echo "   with_gpu              (install with GPU support enabled)"
  echo "   with_gpu_and_ingress  (install with GPU support enabled and configure an ingress to Ollama)"
  echo "   custom_overrides_only (only write out the ${CUSTOM_OVERRIDES_FILE} file)"
  echo "   install_only          (only run an install using an existing ${CUSTOM_OVERRIDES_FILE} file)"
  echo
  echo "Example: ${0} without_gpu"
  echo "         ${0} with_gpu"
  echo "         ${0} with_gpu_and_ingress"
  echo "         ${0} custom_overrides_only"
  echo "         ${0} install_only"
  echo
}

##############################################################################

case ${1} in
  custom_overrides_only)
    create_ollama_custom_overrides_file
    with_nvidia_gpu
    with_ingress
    display_custom_overrides_file
  ;;
  install_only)
    check_for_kubectl
    check_for_helm
    log_into_app_collection
    display_custom_overrides_file
    install_ollama
  ;;
  without_gpu)
    check_for_kubectl
    check_for_helm
    log_into_app_collection
    create_ollama_custom_overrides_file
    display_custom_overrides_file
    install_ollama
  ;;
  with_gpu)
    check_for_kubectl
    check_for_helm
    log_into_app_collection
    create_ollama_custom_overrides_file
    with_nvidia_gpu
    display_custom_overrides_file
    install_ollama
  ;;
  with_gpu_and_ingress)
    check_for_kubectl
    check_for_helm
    log_into_app_collection
    create_ollama_custom_overrides_file
    with_nvidia_gpu
    with_ingress
    display_custom_overrides_file
    install_ollama
  ;;
  *)
    usage
    exit
  ;;
esac

