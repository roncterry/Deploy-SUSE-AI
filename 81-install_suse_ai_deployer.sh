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
  SUSE_AI_NAMESPACE=suse-private-ai
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

CUSTOM_OVERRIDES_FILE=suse_ai_deployer_custom_overrides.yaml

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

create_suse_ai_deployer_base_custom_overrides_file() {
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
}

add_owui_config_to_custom_overrides_file() {
  ######  Open WebUI persistent storage values  ######
  echo "open-webui:
  persistence:
    enabled: true
    storageClass: ${STORAGE_CLASS_NAME}" >> ${CUSTOM_OVERRIDES_FILE}

  ######  Open WebUI ingress values  ######
  echo "  ingress:
    class: nginx
    host: ${WEBUI_INGRESS_HOST}" >> ${CUSTOM_OVERRIDES_FILE}

  ######  Open WebUI extra env vars values  ######
  echo "  extraEnvVars:" >> ${CUSTOM_OVERRIDES_FILE}
#    - name: DEFAULT_MODELS
#      value: \"${OLLAMA_MODEL_0}\"
#    - name: DEFAULT_USER_ROLE
#      value: \"user\"
#    - name: GLOBAL_LOG_LEVEL
#      value: \"INFO\"" >> ${CUSTOM_OVERRIDES_FILE}

  ######  Open WebUI Milvus integration values  ######
  case ${SUSE_PRIVATE_AI_MILVUS_ENABLED} in
    true)
    echo "  - name: VECTOR_DB
    value: \"milvus\"
  - name: MILVUS_URI
    value:  \"http://milvus.${SUSE_AI_NAMESPACE}.svc.cluster.local:19530\"
  - name: RAG_EMBEDDING_MODEL
    value: \"sentence-transformers/all-MiniLM-L6-v2\"" >> ${CUSTOM_OVERRIDES_FILE}
#  - name: INSTALL_NLTK_DATASETS
#    value: \"true\"" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
  esac
}   
    
add_ollama_config_to_custom_overrides_file() {
  echo "ollama:
  ollama:
    models:
      pull:" >> ${CUSTOM_OVERRIDES_FILE}

  if ! [ -z ${OLLAMA_MODEL_0} ]
  then
    echo "        - \"${OLLAMA_MODEL_0}\" " >> ${CUSTOM_OVERRIDES_FILE}
  fi

  if ! [ -z ${OLLAMA_MODEL_1} ]
  then
    echo "        - \"${OLLAMA_MODEL_1}\" " >> ${CUSTOM_OVERRIDES_FILE}
  fi

  if ! [ -z ${OLLAMA_MODEL_2} ]
  then
    echo "        - \"${OLLAMA_MODEL_2}\" " >> ${CUSTOM_OVERRIDES_FILE}
  fi

  if ! [ -z ${OLLAMA_MODEL_3} ]
  then
    echo "        - \"${OLLAMA_MODEL_3}\" " >> ${CUSTOM_OVERRIDES_FILE}
  fi

  if ! [ -z ${OLLAMA_MODEL_4} ]
  then
    echo "        - \"${OLLAMA_MODEL_4}\" " >> ${CUSTOM_OVERRIDES_FILE}
  fi

  echo "    gpu:
      enabled: ${OLLAMA_GPU_ENABLED}
      type: ${OLLAMA_GPU_TYPE}
      number: ${OLLAMA_GPU_NUMBER}
      nvidiaResource: ${OLLAMA_GPU_NVIDIA_RESOURCE}
  runtimeClassName: ${OLLAMA_RUNTIMECLASSNAME}" >> ${CUSTOM_OVERRIDES_FILE}
}

add_milvus_config_to_custom_overrides_file() {
  echo "milvus:
  enabled: ${SUSE_PRIVATE_AI_MILVUS_ENABLED}
  cluster:
    enabled: ${MILVUS_CLUSTER_ENABLED}" >> ${CUSTOM_OVERRIDES_FILE}

  #####  Milvus ectd values  #####
  echo "  etcd:
    enabled: ${MILVUS_ETCD_ENABLED}
    replicaCount: ${MILVUS_ETCD_REPLICA_COUNT}
    persistence:
      size: ${MILVUS_MINIO_VOLUME_SIZE}
      storageClassName: ${STORAGE_CLASS_NAME}
    resources:
      requests:
        memory: ${MILVUS_MINIO_MEMORY}" >> ${CUSTOM_OVERRIDES_FILE}


  #####  Milvus MinIO values  #####
  echo "  minio:
    mode: ${MILVUS_MINIO_MODE}
    replicas: ${MILVUS_MINIO_REPLICA_COUNT}
    rootUser: ${MILVUS_MINIO_ROOT_USER}
    rootPassword: ${MILVUS_MINIO_ROOT_USER_PASSWORD}
    persistence:
      storageClass: ${STORAGE_CLASS_NAME}" >> ${CUSTOM_OVERRIDES_FILE}

  #####  Milvus Kafka values  #####
  echo "  kafka:
    enabled: ${MILVUS_KAFKA_ENABLED}
    persistence:
      storageClassName: ${STORAGE_CLASS_NAME}" >> ${CUSTOM_OVERRIDES_FILE}
}

add_pytorch_config_to_custom_overrides_file() {
  echo "pytorch:
  enabled: ${SUSE_PRIVATE_AI_PYTORCH_ENABLED}
  gpu: 
    enabled: ${PYTORCH_GPU_ENABLED}
    type: ${PYTORCH_GPU_TYPE}
    number: ${PYTORCH_GPU_NUMBER}
  runtimeClassName: ${PYTORCH_RUNTIMECLASSNAME}
  persistence:
    enabled: true
    size: ${PYTORCH_VOLUME_SIZE}
    storageClassName: ${STORAGE_CLASS_NAME}" >> ${CUSTOM_OVERRIDES_FILE}
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

install_suse_ai_deployer() {
  if ! [ -z ${SUSE_AI_DEPLOYER_VERSION} ]
  then
    local SUSE_AI_DEPLOYER_VER_ARG="--version ${SUSE_AI_DEPLOYER_VERSION}"
  fi

  echo
  echo "COMMAND:
  helm upgrade --install ${SUSE_AI_NAMESPACE} \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f ${CUSTOM_OVERRIDES_FILE} \
    oci://dp.apps.rancher.io/charts/suse-ai-deployer ${OWUI_VER_ARG}"

  helm upgrade --install suse-private-ai \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f ${CUSTOM_OVERRIDES_FILE} \
    oci://dp.apps.rancher.io/charts/suse-ai-deployer ${OWUI_VER_ARG}

  case ${SUSE_PRIVATE_AI_MILVUS_ENABLED} in
    true)
      echo
      echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/${SUSE_AI_NAMESPACE}-milvus-standalone"
      kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/${SUSE_AI_NAMESPACE}-milvus-standalone
      echo
      echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/${SUSE_AI_NAMESPACE}-minio"
      kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/${SUSE_AI_NAMESPACE}-minio
    ;;
  esac

  echo
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/${SUSE_AI_NAMESPACE}-ollama"
  kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/${SUSE_AI_NAMESPACE}-ollama

  echo
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/open-webui-redis"
  kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/open-webui-redis

  echo
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/pytorch"
  kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/pytorch

  echo
}

usage() {
  echo
  echo "USAGE: ${0} [custom_overrides_only|install_only]"
  echo
  echo "Options: "
  echo "    custom_overrides_only  (only write out the ${CUSTOM_OVERRIDES_FILE} file)"
  echo "    install_only           (only run an install using an existing ${CUSTOM_OVERRIDES_FILE} file)"
  echo
  echo "If no option is supplied the ${CUSTOM_OVERRIDES_FILE} file is created and"
  echo "is used to perform an installation using 'helm upgrade --install'."
  echo
  echo "Example: ${0}"
  echo "         ${0} custom_overrides_only"
  echo "         ${0} install_only"
  echo

  echo
}

##############################################################################


case ${1} in
  custom_overrides_only)
    create_suse_ai_deployer_base_custom_overrides_file
    add_owui_config_to_custom_overrides_file
    add_ollama_config_to_custom_overrides_file
    add_milvus_config_to_custom_overrides_file
    add_pytorch_config_to_custom_overrides_file
    display_custom_overrides_file
  ;;
  install_only)
    check_for_kubectl
    check_for_helm
    log_into_app_collection
    display_custom_overrides_file
    install_suse_ai_deployer
  ;;
  help|-h|--help)
    usage
    exit
  ;;
  *)
    check_for_kubectl
    check_for_helm
    log_into_app_collection
    create_suse_ai_deployer_base_custom_overrides_file
    add_owui_config_to_custom_overrides_file
    add_ollama_config_to_custom_overrides_file
    add_milvus_config_to_custom_overrides_file
    add_pytorch_config_to_custom_overrides_file
    display_custom_overrides_file
    install_suse_ai_deployer
  ;;
esac

