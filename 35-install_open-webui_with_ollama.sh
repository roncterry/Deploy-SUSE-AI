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

  OWUI_OLLAMA_ENABLED=True
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

create_owui_base_custom_overrides_file() {
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
  host: ${WEBUI_INGRESS_HOST}" > owui_custom_overrides.yaml
}

add_ollama_config_to_custom_overrides_file() {
  echo "ollama:
  enabled: ${OWUI_OLLAMA_ENABLED}" >> owui_custom_overrides.yaml

  case ${OWUI_OLLAMA_ENABLED} in
    True|true|TRUE)
      echo "  defaultModel: ${OLLAMA_MODEL_0}
  ollama:
    models:" >> owui_custom_overrides.yaml

      if ! [ -z ${OLLAMA_MODEL_0} ]
      then
        echo "    - \"${OLLAMA_MODEL_0}\" " >> owui_custom_overrides.yaml
      fi
  
      if ! [ -z ${OLLAMA_MODEL_1} ]
      then
        echo "    - \"${OLLAMA_MODEL_1}\" " >> owui_custom_overrides.yaml
      fi
  
      if ! [ -z ${OLLAMA_MODEL_2} ]
      then
        echo "    - \"${OLLAMA_MODEL_2}\" " >> owui_custom_overrides.yaml
      fi
  
      if ! [ -z ${OLLAMA_MODEL_3} ]
      then
        echo "    - \"${OLLAMA_MODEL_3}\" " >> owui_custom_overrides.yaml
      fi
  
      if ! [ -z ${OLLAMA_MODEL_4} ]
      then
        echo "    - \"${OLLAMA_MODEL_4}\" " >> owui_custom_overrides.yaml
      fi
    ;;
    False|false|FALSE)
      echo "ollamaURLSs:
  - http://ollama.${SUSE_AI_NAMESPACE}.svc.cluster.local:11434" >> owui_custom_overrides.yaml
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
    runtimeClassName: nvidia" >> owui_custom_overrides.yaml
    ;;
  esac
}

add_extra_envvars_to_custom_overrides_file() {
  echo "extraEnvVars:" >> owui_custom_overrides.yaml
#- name: DEFAULT_MODELS
#  value: \"${OLLAMA_MODEL_0}\"
#- name: DEFAULT_USER_ROLE
#  value: \"user\"
#- name: \"WEBUI_NAME\"
#  value: \"SUSE AI\"
#- name: GLOBAL_LOG_LEVEL
#  value: \"INFO\"" >> owui_custom_overrides.yaml
}

add_milvus_to_custom_overrides_file() {
  echo "- name: VECTOR_DB
  value: \"milvus\"
- name: MILVUS_URI
  value:  \"http://milvus.${SUSE_AI_NAMESPACE}.svc.cluster.local:19530\"" >> owui_custom_overrides.yaml
#- name: RAG_EMBEDDING_MODEL
#  value: \"sentence-transformers/all-MiniLM-L6-v2\"
#- name: INSTALL_NLTK_DATASETS
#  value: \"true\"" >> owui_custom_overrides.yaml
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
    create_owui_base_custom_overrides_file
    add_ollama_config_to_custom_overrides_file
    add_nvidia_gpu_to_custom_overrides_file
    add_extra_envvars_to_custom_overrides_file
    add_milvus_to_custom_overrides_file
  ;;
  without_gpu)
    install_certmanager_crds
    log_into_app_collection
    create_owui_base_custom_overrides_file
    add_ollama_config_to_custom_overrides_file
    add_extra_envvars_to_custom_overrides_file
    install_open_webui
  ;;
  with_gpu)
    install_certmanager_crds
    log_into_app_collection
    create_owui_base_custom_overrides_file
    add_ollama_config_to_custom_overrides_file
    add_nvidia_gpu_to_custom_overrides_file
    add_extra_envvars_to_custom_overrides_file
    install_open_webui
  ;;
  with_gpu_and_milvus)
    install_certmanager_crds
    log_into_app_collection
    create_owui_base_custom_overrides_file
    add_ollama_config_to_custom_overrides_file
    add_nvidia_gpu_to_custom_overrides_file
    add_extra_envvars_to_custom_overrides_file
    add_milvus_to_custom_overrides_file
    install_open_webui
  ;;
  with_external_ollama_and_milvus)
    install_certmanager_crds
    log_into_app_collection
    create_owui_base_custom_overrides_file
    add_ollama_config_to_custom_overrides_file
    add_extra_envvars_to_custom_overrides_file
    add_milvus_to_custom_overrides_file
    install_open_webui
  ;;
  *)
    echo "ERROR:  Must supply one of the following: "
    echo "          without_gpu                      (install without GPU support enabled)"
    echo "          with_gpu                         (install with GPU support enabled)"
    echo "          with_gpu_and_milvus              (install with GPU support and Milvus enabled)"
    echo "          with_external_ollama_and_milvus  (install using external Ollama and Milvus enabled)"
    echo "          custom_overrides_only            (only write out the owui_custom_overrides.yaml file)"
    echo
    echo "Example: ${0} without_gpu"
    echo "         ${0} with_gpu"
    echo "         ${0} with_gpu_and_milvus"
    echo "         ${0} with_external_ollama_and_milvus"
    echo "         ${0} custom_overrides_only"
    echo
    exit
  ;;
esac

