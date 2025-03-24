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
  #### General Variables  #####
  SUSE_AI_NAMESPACE=suse-ai
  IMAGE_PULL_SECRET_NAME=application-collection
  STORAGE_CLASS_NAME=longhorn
  MILVUS_VERSION=
  MILVUS_CLUSTER_ENABLED=false
  MILVUS_LOGGING_LEVEL=info
  MILVUS_LOGGING_STORAGE=emptyDir
  
  MILVUS_STANDALONE_MESSAGE_QUEUE=rocksmq

  ####  Etcd Variables  #####
  MILVUS_ETCD_ENABLED=true
  MILVUS_ETCD_REPLICA_COUNT=1

  ####  Mineo Vairables  #####
  MILVUS_MINIO_ENABLED=true
  MILVUS_MINIO_ROOT_USER=admin
  MILVUS_MINIO_ROOT_USER_PASSWORD=adminminio
  MILVUS_MINIO_MODE=standalone
  MILVUS_MINIO_REPLICA_COUNT=1
  MILVUS_MINIO_VOLUME_SIZE=100Gi
  MILVUS_MINIO_MEMORY=4096Mi 
  
  ####  Kafka Vairables  #####
  MILVUS_KAFKA_ENABLED=false
  MILVUS_KAFKA_REPLICA_COUNT=3
  MILVUS_KAFKA_VOLUME_SIZE=8Gi
fi

LICENSES_FILE=authentication_and_licenses.cfg

CUSTOM_OVERRIDES_FILE=milvus_custom_overrides.yaml

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

create_milvus_custom_overrides_file() {
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} file ..."
  echo
  echo "
global:
  imagePullSecrets:
  - ${IMAGE_PULL_SECRET_NAME}
cluster:
  enabled: ${MILVUS_CLUSTER_ENABLED}
log:
  level: ${MILVUS_LOGGING_LEVEL}" > ${CUSTOM_OVERRIDES_FILE}

  #####  logging storage values  #####
  case ${MILVUS_LOGGING_STORAGE} in
    storageClass)
      echo "  persistence:
    enabled: true
    persistentVolumeClaim:
      storageClass: ${STORAGE_CLASS_NAME}" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
  esac

  #####  standalone mode values  #####
  echo "standalone:
  messageQueue: ${MILVUS_STANDALONE_MESSAGE_QUEUE}
  persistence:
    persistentVolumeClaim:
      storageClass: ${STORAGE_CLASS_NAME}" >> ${CUSTOM_OVERRIDES_FILE}

  #####  ectd values  #####
  case ${MILVUS_ETCD_ENABLED} in
    true)
      echo "etcd:
  enabled: ${MILVUS_ETCD_ENABLED}
  replicaCount: ${MILVUS_ETCD_REPLICA_COUNT}
  persistence:
    storageClassName: ${STORAGE_CLASS_NAME}" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
    false)
      echo "etcd:
  enabled: ${ETCD_ENABLED}" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
  esac

  #####  MinIO values  #####
  case ${MILVUS_MINIO_ENABLED} in
    true)
      echo "minio:
  enabled: ${MILVUS_MINIO_ENABLED}
  mode: ${MILVUS_MINIO_MODE}
  replicas: ${MILVUS_MINIO_REPLICA_COUNT}
  rootUser: ${MILVUS_MINIO_ROOT_USER}
  rootPassword: ${MILVUS_MINIO_ROOT_USER_PASSWORD}
  persistence:
    size: ${MILVUS_MINIO_VOLUME_SIZE}
    storageClass: ${STORAGE_CLASS_NAME}
  resources:
    requests:
      memory: ${MILVUS_MINIO_MEMORY}" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
    false)
      echo "minio:
  enabled: ${MILVUS_MINIO_ENABLED}" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
  esac

  #####  Kafka values  #####
  case ${MILVUS_KAFKA_ENABLED} in
    true)
      echo "kafka:
  enabled: ${MILVUS_KAFKA_ENABLED}
  name: kafka
  replicaCount: ${MILVUS_KAFKA_REPLICA_COUNT}
  broker:
    enabled: true
  cluster:
    listeners:
      client:
        protocol: 'PLAINTEXT'
      controller:
        protocol: 'PLAINTEXT'
  persistence:
    enabled: true
    annotations: {}
    labels: {}
    existingClaim: \"\"
    accessModes:
    - ReadWriteOnce
    resources:
      requests:
        storage: ${MILVUS_KAFKA_VOLUME_SIZE}
    storageClassName: ${STORAGE_CLASS_NAME}" >> ${CUSTOM_OVERRIDES_FILE}
    ;;
    false)
      echo "kafka:
  enabled: ${MILVUS_KAFKA_ENABLED} " >> ${CUSTOM_OVERRIDES_FILE}
    ;;
  esac
  echo
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

deploy_milvus() {
  if ! [ -z ${MILVUS_VERSION} ]
  then
    local MILVUS_VER_ARG="--version ${MILVUS_VERSION}"
  fi

  echo "COMMAND: helm upgrade --install milvus \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f ${CUSTOM_OVERRIDES_FILE} \
    oci://dp.apps.rancher.io/charts/milvus ${MILVUS_VER_ARG}"

  helm upgrade --install milvus \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f ${CUSTOM_OVERRIDES_FILE} \
    oci://dp.apps.rancher.io/charts/milvus ${MILVUS_VER_ARG}

  case ${MILVUS_CLUSTER_ENABLED} in
    false|False|FALSE)
      echo
      echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/milvus-minio"
      kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/milvus-minio
      echo
      echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/milvus-standalone"
      kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/milvus-standalone
    ;;
  esac

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
}

##############################################################################

case ${1} in
  custom_overrides_only)
    create_milvus_custom_overrides_file
    display_custom_overrides_file
  ;;
  install_only)
    check_for_kubectl
    check_for_helm
    log_into_app_collection
    display_custom_overrides_file
    deploy_milvus
  ;;
  help|-h|--help)
    usage
    exit
  ;;
  *)
    check_for_kubectl
    check_for_helm
    log_into_app_collection
    create_milvus_custom_overrides_file
    display_custom_overrides_file
    deploy_milvus
  ;;
esac

