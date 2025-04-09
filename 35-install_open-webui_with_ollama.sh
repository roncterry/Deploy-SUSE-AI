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

  OWUI_OLLAMA_ENABLED=true
  WEBUI_INGRESS_HOST=webui.example.com
  OLLAMA_MODEL_0=llama3.2
  OLLAMA_MODEL_1=gemma:2b
  OLLAMA_MODEL_2=
  OLLAMA_MODEL_3=
  OLLAMA_MODEL_4=
fi

LICENSES_FILE=authentication_and_licenses.cfg

CUSTOM_OVERRIDES_FILE=owui_custom_overrides.yaml

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

#install_certmanager_crds() {
#  echo
#  echo "COMMAND: kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.6.2/cert-manager.crds.yaml"
#  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.6.2/cert-manager.crds.yaml
#  echo
#}

create_owui_base_custom_overrides_file() {
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} file ..."
  echo
  echo "
global:
  imagePullSecrets:
  - ${IMAGE_PULL_SECRET_NAME}" > ${CUSTOM_OVERRIDES_FILE}

  ######  TLS values  ######
  echo "  tls:
    source: ${OWUI_TLS_SOURCE}" >> ${CUSTOM_OVERRIDES_FILE}
  case ${OWUI_TLS_SOURCE} in
    letsEncrypt)
      echo "    letsEncrypt:
      email: ${OWUI_TLS_EMAIL}
      environment: ${OWUI_TLS_LETSENCRYPT_ENVIRONMENT}
      ingress:
        class: \"${OWUI_TLS_INGRESS_CLASS}\"" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
    secret)
      echo "    additionalTrustedCerts: ${OWUI_TLS_ADDITIONAL_TRUSTED_CERTS}" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
    *)
      echo "    additionalTrustedCerts: ${OWUI_TLS_ADDITIONAL_TRUSTED_CERTS}" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
  esac

  ######  persistent storage values  ######
  echo "persistence:
  enabled: true
  storageClass: ${STORAGE_CLASS_NAME}
ingress:
  class: nginx
  host: ${WEBUI_INGRESS_HOST}" >> ${CUSTOM_OVERRIDES_FILE}
}

add_ollama_config_to_custom_overrides_file() {
  echo "ollama:
  enabled: ${OWUI_OLLAMA_ENABLED}" >> ${CUSTOM_OVERRIDES_FILE}

  case ${OWUI_OLLAMA_ENABLED} in
    True|true|TRUE)
      echo "  defaultModel: ${OLLAMA_MODEL_0}
  ollama:
    models:
      pull:" >> ${CUSTOM_OVERRIDES_FILE}

      if ! [ -z ${OLLAMA_MODEL_0} ]
      then
        echo "      - \"${OLLAMA_MODEL_0}\" " >> ${CUSTOM_OVERRIDES_FILE}
      fi
  
      if ! [ -z ${OLLAMA_MODEL_1} ]
      then
        echo "      - \"${OLLAMA_MODEL_1}\" " >> ${CUSTOM_OVERRIDES_FILE}
      fi
  
      if ! [ -z ${OLLAMA_MODEL_2} ]
      then
        echo "      - \"${OLLAMA_MODEL_2}\" " >> ${CUSTOM_OVERRIDES_FILE}
      fi
  
      if ! [ -z ${OLLAMA_MODEL_3} ]
      then
        echo "      - \"${OLLAMA_MODEL_3}\" " >> ${CUSTOM_OVERRIDES_FILE}
      fi
  
      if ! [ -z ${OLLAMA_MODEL_4} ]
      then
        echo "      - \"${OLLAMA_MODEL_4}\" " >> ${CUSTOM_OVERRIDES_FILE}
      fi
    ;;
    False|false|FALSE)
      echo "ollamaURLSs:
  - http://ollama.${SUSE_AI_NAMESPACE}.svc.cluster.local:11434" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
  esac
}

add_nvidia_gpu_to_custom_overrides_file() {
  case ${OWUI_OLLAMA_ENABLED} in
    True|true|TRUE)
      echo "    gpu:
      enabled: true
      type: nvidia
      number: 1
    runtimeClassName: nvidia" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
  esac
}

add_extra_envvars_to_custom_overrides_file() {
  echo "extraEnvVars:" >> ${CUSTOM_OVERRIDES_FILE}
#- name: DEFAULT_MODELS
#  value: \"${OLLAMA_MODEL_0}\"
#- name: DEFAULT_USER_ROLE
#  value: \"user\"
#- name: \"WEBUI_NAME\"
#  value: \"SUSE AI\"
#- name: GLOBAL_LOG_LEVEL
#  value: \"INFO\"" >> ${CUSTOM_OVERRIDES_FILE}
}

add_milvus_to_custom_overrides_file() {
  echo "- name: VECTOR_DB
  value: \"milvus\"
- name: MILVUS_URI
  value:  \"http://milvus.${SUSE_AI_NAMESPACE}.svc.cluster.local:19530\"
- name: RAG_EMBEDDING_MODEL
  value: \"sentence-transformers/all-MiniLM-L6-v2\"" >> ${CUSTOM_OVERRIDES_FILE}
#- name: INSTALL_NLTK_DATASETS
#  value: \"true\"" >> ${CUSTOM_OVERRIDES_FILE}
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

install_open_webui() {
  if ! [ -z ${OWUI_VERSION} ]
  then
    local OWUI_VER_ARG="--version ${OWUI_VERSION}"
  fi

  echo
  echo "COMMAND:
  helm upgrade --install open-webui \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f ${CUSTOM_OVERRIDES_FILE} \
    oci://dp.apps.rancher.io/charts/open-webui ${OWUI_VER_ARG}"

  helm upgrade --install open-webui \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f ${CUSTOM_OVERRIDES_FILE} \
    oci://dp.apps.rancher.io/charts/open-webui ${OWUI_VER_ARG}

  case ${OWUI_OLLAMA_ENABLED} in
    true|True|TRUE)
      echo
      echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/open-webui-ollama"
      kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/open-webui-ollama
    ;;
  esac

  echo
}

usage() {
  echo
  echo "USAGE: ${0} <option>"
  echo
  echo " You must supply one of the following options: "
  echo "   without_gpu                      (install without GPU support enabled)"
  echo "   with_gpu                         (install with GPU support enabled)"
  echo "   with_gpu_and_milvus              (install with GPU support and Milvus enabled)"
  echo "   with_external_ollama_and_milvus  (install using external Ollama and Milvus enabled)"
  echo "   custom_overrides_only            (only write out the ${CUSTOM_OVERRIDES_FILE} file)"
  echo "   install_only                     (only run an install using an existing ${CUSTOM_OVERRIDES_FILE} file)"
  echo
  echo "Example: ${0} without_gpu"
  echo "         ${0} with_gpu"
  echo "         ${0} with_gpu_and_milvus"
  echo "         ${0} with_external_ollama_and_milvus"
  echo "         ${0} custom_overrides_only"
  echo "         ${0} install_only"
  echo
}

##############################################################################


case ${1} in
  custom_overrides_only)
    create_owui_base_custom_overrides_file
    add_ollama_config_to_custom_overrides_file
    add_nvidia_gpu_to_custom_overrides_file
    add_extra_envvars_to_custom_overrides_file
    add_milvus_to_custom_overrides_file
    display_custom_overrides_file
  ;;
  install_only)
    check_for_kubectl
    check_for_helm
    #install_certmanager_crds
    log_into_app_collection
    display_custom_overrides_file
    install_open_webui
  ;;
  without_gpu)
    check_for_kubectl
    check_for_helm
    #install_certmanager_crds
    log_into_app_collection
    create_owui_base_custom_overrides_file
    add_ollama_config_to_custom_overrides_file
    add_extra_envvars_to_custom_overrides_file
    display_custom_overrides_file
    install_open_webui
  ;;
  with_gpu)
    check_for_kubectl
    check_for_helm
    #install_certmanager_crds
    log_into_app_collection
    create_owui_base_custom_overrides_file
    add_ollama_config_to_custom_overrides_file
    add_nvidia_gpu_to_custom_overrides_file
    display_custom_overrides_file
    install_open_webui
  ;;
  with_gpu_and_milvus)
    check_for_kubectl
    check_for_helm
    #install_certmanager_crds
    log_into_app_collection
    create_owui_base_custom_overrides_file
    add_ollama_config_to_custom_overrides_file
    add_nvidia_gpu_to_custom_overrides_file
    add_extra_envvars_to_custom_overrides_file
    add_milvus_to_custom_overrides_file
    display_custom_overrides_file
    install_open_webui
  ;;
  with_external_ollama_and_milvus)
    check_for_kubectl
    check_for_helm
    #install_certmanager_crds
    log_into_app_collection
    create_owui_base_custom_overrides_file
    add_ollama_config_to_custom_overrides_file
    add_extra_envvars_to_custom_overrides_file
    add_milvus_to_custom_overrides_file
    display_custom_overrides_file
    install_open_webui
  ;;
  *)
    usage
    exit
  ;;
esac

