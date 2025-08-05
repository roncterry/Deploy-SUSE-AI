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
  IMAGE_PULL_SECRET_NAME=application-collection

  CERTMANAGER_HELM_REPO="https://charts.jetstack.io"
  CERTMANAGER_HELM_CHART="oci://dp.apps.rancher.io/charts/cert-manager"
  CERTMANAGER_VERSION=
  CERTMANAGER_NAMESPACE=cert-manager
fi

LICENSES_FILE=authentication_and_licenses.cfg

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

CUSTOM_OVERRIDES_FILE=cm_custom_overrides.yaml

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

  if ! [ -z ${CERTMANAGER_NAMESPACE} ]
  then
    if ! kubectl get namespace | grep -q ${CERTMANAGER_NAMESPACE}
    then
      echo "COMMAND: kubectl create namespace ${CERTMANAGER_NAMESPACE}"
      kubectl create namespace ${CERTMANAGER_NAMESPACE}
      echo
    fi

    if ! kubectl -n ${CERTMANAGER_NAMESPACE} get secrets | grep -v ^NAME | awk '{ print $1 }' | grep -q ${IMAGE_PULL_SECRET_NAME}
    then
      echo "COMMAND: kubectl -n ${CERTMANAGER_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${CERTMANAGER_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${CERTMANAGER_NAMESPACE} get secrets"
      kubectl -n ${CERTMANAGER_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${CERTMANAGER_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${CERTMANAGER_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    else
      echo "COMMAND: kubectl -n ${CERTMANAGER_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${CERTMANAGER_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}
      echo "COMMAND: kubectl -n ${CERTMANAGER_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${CERTMANAGER_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${CERTMANAGER_NAMESPACE} get secrets"
      kubectl -n ${CERTMANAGER_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${CERTMANAGER_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${CERTMANAGER_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
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
  #echo COMMAND: kubectl patch serviceaccount default -p \{\"imagePullSecrets\": \[\{\"name\": \"${IMAGE_PULL_SECRET_NAME}\"\}\]\}
  #kubectl patch serviceaccount default -p {"imagePullSecrets": [{"name": "${IMAGE_PULL_SECRET_NAME}"}]}
  #echo

  echo COMMAND: kubectl -n ${CERTMANAGER_NAMESPACE} patch serviceaccount default -p \{\"imagePullSecrets\": \[\{\"name\": \"${IMAGE_PULL_SECRET_NAME}\"\}\]\}
  kubectl -n ${CERTMANAGER_NAMESPACE} patch serviceaccount default -p {"imagePullSecrets": [{"name": "${IMAGE_PULL_SECRET_NAME}"}]}
  echo
}

#install_certmanager_crds() {
#  echo
#  echo "COMMAND: kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.6.2/cert-manager.crds.yaml"
#  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.6.2/cert-manager.crds.yaml
#  echo
#}

create_certmanager_base_custom_overrides_file() {
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} file ..."
  echo
  echo "
global:
  imagePullSecrets:
  - ${IMAGE_PULL_SECRET_NAME}" > ${CUSTOM_OVERRIDES_FILE}
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

install_certmanager() {
  if ! [ -z ${CERTMANAGER_VERSION} ]
  then
    local CM_VER_ARG="--version ${CERTMANAGER_VERSION}"
  fi

  echo "Installing Cert-Manager ..."
  echo "------------------------------------------------------------"
  if [ -z ${CERTMANAGER_HELM_CHART} ]
  then
    echo "COMMAND: 
    helm repo add cert-manager ${CERTMANAGER_HELM_REPO}
    helm repo update"
 
    helm repo add cert-manager ${CERTMANAGER_HELM_REPO}
    helm repo update
 
    echo
    echo "COMMAND: helm upgrade --install cert-manager cert-manager/cert-manager --namespace ${CERTMANAGER_NAMESPACE} --create-namespace --set crds.enabled=true ${CERTMANAGER_VER_ARG}"
    helm upgrade --install cert-manager cert-manager/cert-manager --namespace ${CERTMANAGER_NAMESPACE} --create-namespace --set crds.enabled=true ${CERTMANAGER_VER_ARG}
  else
    log_into_app_collection
    create_app_collection_secret
    #patch_serviceaccounts
    create_certmanager_base_custom_overrides_file
    display_custom_overrides_file

    echo "COMMAND: helm upgrade --install cert-manager ${CERTMANAGER_HELM_CHART} --namespace ${CERTMANAGER_NAMESPACE} --create-namespace --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} --set crds.enabled=true ${CERTMANAGER_VER_ARG}"
    helm upgrade --install cert-manager ${CERTMANAGER_HELM_CHART} --namespace ${CERTMANAGER_NAMESPACE} --create-namespace --set 'global.imagePullSecrets[0].name'=${IMAGE_PULL_SECRET_NAME} --set crds.enabled=true ${CERTMANAGER_VER_ARG}
  fi

  #echo
  #echo "COMMAND: helm upgrade --install cert-manager oci://dp.apps.rancher.io/charts/cert-manager --namespace ${CERTMANAGER_NAMESPACE} -f ${CUSTOM_OVERRIDES_FILE} --create-namespace --set crds.enabled=true ${CM_VER_ARG}"
  #helm upgrade --install cert-manager oci://dp.apps.rancher.io/charts/cert-manager --namespace ${CERTMANAGER_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} --set crds.enabled=true ${CM_VER_ARG}

  echo
  echo "COMMAND: kubectl -n ${CERTMANAGER_NAMESPACE} rollout status deploy/cert-manager"
  kubectl -n ${CERTMANAGER_NAMESPACE} rollout status deploy/cert-manager

  echo
}

##############################################################################

check_for_kubectl
check_for_helm
if helm list -n ${CERTMANAGER_NAMESPACE} | grep -q cert-manager
then
  echo
  echo "Cert-Manager is already installed. Exiting."
  echo
else
  install_certmanager
fi

