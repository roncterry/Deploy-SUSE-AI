#!/bin/bash

##############################################################################

# You can either source in the variables from a common config file or
# set the them in this script.

CONFIG_FILE=deploy_suse_observability.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  SUSE_AI_NAMESPACE=suse-ai
  IMAGE_PULL_SECRET_NAME=application-collection
  CERTMANAGER_VERSION=
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
  echo
  echo "COMMAND: helm upgrade --install cert-manager oci://dp.apps.rancher.io/charts/cert-manager --namespace ${SUSE_AI_NAMESPACE} -f ${CUSTOM_OVERRIDES_FILE} --create-namespace --set crds.enabled=true ${CM_VER_ARG}"
  helm upgrade --install cert-manager oci://dp.apps.rancher.io/charts/cert-manager --namespace ${SUSE_AI_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} --set crds.enabled=true ${CM_VER_ARG}

  echo
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/cert-manager"
  kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/cert-manager

  echo
}

##############################################################################

check_for_kubectl
check_for_helm
log_into_app_collection
create_certmanager_base_custom_overrides_file
display_custom_overrides_file
install_certmanager

