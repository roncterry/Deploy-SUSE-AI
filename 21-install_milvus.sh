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

#MINIO_ROOT_USER=admin
#MINIO_ROOT_USER_PASSWORD=adminminio
##MINIO_REPLICA_COUNT=4
#MINIO_REPLICA_COUNT=3

##KAFKA_REPLICA_COUNT=3
#KAFKA_REPLICA_COUNT=3

##ETCD_REPLICA_COUNT=3
#ETCD_REPLICA_COUNT=3

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

deploy_milvus() {
  echo "
global:
  imagePullSecrets:
  - ${IMAGE_PULL_SECRET_NAME}
cluster:
  enabled: True
standalone:
  persistence:
    persistentVolumeClaim:
      storageClass: ${STORAGE_CLASS_NAME}
etcd:
  replicaCount: ${ETCD_REPLICA_COUNT}
  persistence:
    storageClassName: ${STORAGE_CLASS_NAME}
minio:
  mode: distributed
  replicas: ${MINIO_REPLICA_COUNT}
  rootUser: ${MINIO_ROOT_USER}
  rootPassword: ${MINIO_ROOT_USER_PASSWORD}
  persistence:
    storageClass: ${STORAGE_CLASS_NAME}
  resources:
    requests:
      memory: 1024Mi
kafka:
  enabled: true
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
        storage: 8Gi
    storageClassName: ${STORAGE_CLASS_NAME}
" > milvus_custom_overrides.yaml

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
deploy_milvus

