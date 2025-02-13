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
  echo "Writing out milvus_custom_verrrides.yaml file ..."
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
" > milvus_custom_overrides.yaml
  echo
  cat milvus_custom_overrides.yaml
  echo
}

deploy_milvus() {
  echo "COMMAND: helm upgrade --install milvus \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f milvus_custom_overrides.yaml \
    oci://dp.apps.rancher.io/charts/milvus"

  helm upgrade --install milvus \
    -n ${SUSE_AI_NAMESPACE} --create-namespace \
    -f milvus_custom_overrides.yaml \
    oci://dp.apps.rancher.io/charts/milvus

  echo
}

##############################################################################

log_into_app_collection
create_milvus_custom_overrides_file
deploy_milvus

