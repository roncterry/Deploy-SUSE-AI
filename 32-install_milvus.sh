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
  MILVUS_CLUSTER_ENABLED=False

  ####  Mineo Vairables  #####
  MINIO_ROOT_USER=admin
  MINIO_ROOT_USER_PASSWORD=adminminio
  
  #MINIO_MODE=standalone
  #MINIO_REPLICA_COUNT=1
  
  MINIO_MODE=distributed
  #Default Value: MINIO_REPLICA_COUNT=4
  MINIO_REPLICA_COUNT=3
  
  #Default Value: MINIO_VOLUME_SIZE=500Gi
  MINIO_VOLUME_SIZE=100Gi
  
  #Default Value: MINIO_MEMORY=1024Mi 
  MINIO_MEMORY=4096Mi 
  
  ####  Kafka Vairables  #####
  #Default Value: KAFKA_ENABLED=true
  KAFKA_ENABLED=false
  #Default Value: KAFKA_REPLICA_COUNT=3
  KAFKA_REPLICA_COUNT=3
  
  #Default Value: KAFKA_VOLUME_SIZE=8Gi
  KAFKA_VOLUME_SIZE=8Gi
  
  ####  Etcd Variables  #####
  #Default Value: ETCD_REPLICA_COUNT=3
  ETCD_REPLICA_COUNT=3
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
standalone:
  persistence:
    persistentVolumeClaim:
      storageClass: ${STORAGE_CLASS_NAME}
etcd:
  replicaCount: ${ETCD_REPLICA_COUNT}
  persistence:
    storageClassName: ${STORAGE_CLASS_NAME}
minio:
  mode: ${MINIO_MODE}
  replicas: ${MINIO_REPLICA_COUNT}
  rootUser: ${MINIO_ROOT_USER}
  rootPassword: ${MINIO_ROOT_USER_PASSWORD}
  persistence:
    size: ${MINIO_VOLUME_SIZE}
    storageClass: ${STORAGE_CLASS_NAME}
  resources:
    requests:
      memory: ${MINIO_MEMORY}
kafka:
  enabled: ${KAFKA_ENABLED}
  name: kafka
  replicaCount: ${KAFKA_REPLICA_COUNT}
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
        storage: ${KAFKA_VOLUME_SIZE}
    storageClassName: ${STORAGE_CLASS_NAME}
" > ${CUSTOM_OVERRIDES_FILE}
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
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

