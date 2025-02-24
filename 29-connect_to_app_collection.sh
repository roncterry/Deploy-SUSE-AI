#!/bin/bash

##############################################################################

if ! which kubectl > /dev/null
then
  echo
  echo "ERROR: This must be run on a machine with the kubectl and helm commands installed."
  echo "       Run this script on a control plane node."
  echo
  echo "       Exiting."
  echo
  exit
fi

if ! which helm > /dev/null
then
  echo
  echo "ERROR: This must be run on a machine with the kubectl and helm commands installed."
  echo "       Run this script on a control plane node."
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

create_app_collection_secret() {
  if [ -z ${APP_COLLECTION_USERNAME} ]
  then
    # The APP_COLLECTION_URI, APP_COLLECTION_USERNAME and APP_COLLECTION_PASSWORD
    # variables are set in an external file and are sourced in here:
    source ${LICENSES_FILE}
  fi

  if ! [ -z $_SUSE_AI_NAMESPACE} ]
  then
    if ! kubectl get namespace | grep -q ${SUSE_AI_NAMESPACE}
    then
      echo "COMMAND: kubectl create namespace ${SUSE_AI_NAMESPACE}"
      kubectl create namespace ${SUSE_AI_NAMESPACE}
      echo
    fi

    if ! kubectl -n ${SUSE_AI_NAMESPACE} get secrets | grep -v ^NAME | awk '{ print $1 }' | grep -q ${IMAGE_PULL_SECRET_NAME}
    then
      echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${SUSE_AI_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} get secrets"
      kubectl -n ${SUSE_AI_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${SUSE_AI_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    else
      echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${SUSE_AI_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}
      echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${SUSE_AI_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} get secrets"
      kubectl -n ${SUSE_AI_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${SUSE_AI_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    fi
  else
    if ! kubectl get secrets | grep -v ^NAME | awk '{ print $1 }' | grep -q ${IMAGE_PULL_SECRET_NAME}
    then
      echo "COMMAND: kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl get secrets"
      kubectl get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    else
      echo "COMMAND: kubectl delete secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl delete secret ${IMAGE_PULL_SECRET_NAME}
      echo "COMMAND: kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl get secrets"
      kubectl get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    fi
  fi
}

patch_serviceaccounts() {
  echo COMMAND: kubectl patch serviceaccount default -p \{\"imagePullSecrets\": \[\{\"name\": \"${IMAGE_PULL_SECRET_NAME}\"\}\]\}
  kubectl patch serviceaccount default -p \{\"imagePullSecrets\": \[\{\"name\": \"${IMAGE_PULL_SECRET_NAME}\"\}\]\}
  echo

  echo COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} patch serviceaccount default -p \{\"imagePullSecrets\": \[\{\"name\": \"${IMAGE_PULL_SECRET_NAME}\"\}\]\}
  kubectl -n ${SUSE_AI_NAMESPACE} patch serviceaccount default -p \{\"imagePullSecrets\": \[\{\"name\": \"${IMAGE_PULL_SECRET_NAME}\"\}\]\}
  echo
}

##############################################################################

log_into_app_collection
create_app_collection_secret
#patch_serviceaccounts
