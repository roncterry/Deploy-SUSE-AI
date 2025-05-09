#!/bin/bash

##############################################################################

# You can either source in the variables from a common config file or
# set the them in this script.

CONFIG_FILE=deploy_suse_observability_ai_extension.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
fi
else
  OBSERVABILITY_NAMESPACE=suse-observability
  OBSERVABILITY_HOST=observability.example.com
  OBSERVABILITY_BASEURL=http://${OBSERVABILITY_HOST}
  OBSERVABILITY_API_KEY=
  OBSERVABILITY_API_CLI_TOKEN=
  OBSERVABILITY_OBSERVED_CLUSTER_NAME=aicluster01
fi

LICENSES_FILE=authentication_and_licenses.cfg

CUSTOM_OVERRIDES_FILE=ai_ext_custom_overrides.yaml

##############################################################################

case $(whoami) in
  root)
    SUDO_CMD=""
  ;;
  *)
    SUDO_CMD="sudo"
  ;;
esac

##############################################################################
#   Functions
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

create_app_collection_secret() {
  if [ -z ${APP_COLLECTION_USERNAME} ]
  then
    # The APP_COLLECTION_URI, APP_COLLECTION_USERNAME and APP_COLLECTION_PASSWORD
    # variables are set in an external file and are sourced in here:
    source ${LICENSES_FILE}
  fi

  if ! [ -z ${OBSERVABILITY_NAMESPACE} ]
  then
    if ! kubectl get namespace | grep -q ${OBSERVABILITY_NAMESPACE}
    then
      echo "COMMAND: kubectl create namespace ${OBSERVABILITY_NAMESPACE}"
      kubectl create namespace ${OBSERVABILITY_NAMESPACE}
      echo
    fi

    if ! kubectl -n ${OBSERVABILITY_NAMESPACE} get secrets | grep -v ^NAME | awk '{ print $1 }' | grep -q ${IMAGE_PULL_SECRET_NAME}
    then
      echo "COMMAND: kubectl -n ${OBSERVABILITY_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${OBSERVABILITY_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OBSERVABILITY_NAMESPACE} get secrets"
      kubectl -n ${OBSERVABILITY_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OBSERVABILITY_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${OBSERVABILITY_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
    else
      echo "COMMAND: kubectl -n ${OBSERVABILITY_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${OBSERVABILITY_NAMESPACE} delete secret ${IMAGE_PULL_SECRET_NAME}
      echo "COMMAND: kubectl -n ${OBSERVABILITY_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}"
      kubectl -n ${OBSERVABILITY_NAMESPACE} create secret docker-registry ${IMAGE_PULL_SECRET_NAME} --docker-server=dp.apps.rancher.io --docker-username=${APP_COLLECTION_USERNAME} --docker-password=${APP_COLLECTION_PASSWORD}
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OBSERVABILITY_NAMESPACE} get secrets"
      kubectl -n ${OBSERVABILITY_NAMESPACE} get secrets
      echo
      echo "-----------------------------------------------------------------------------"
      echo
      echo "COMMAND: kubectl -n ${OBSERVABILITY_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}"
      kubectl -n ${OBSERVABILITY_NAMESPACE} describe secret ${IMAGE_PULL_SECRET_NAME}
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

create_ai_extension_custom_overrides_file() {
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} file ..."
  echo
  echo "global:
  imagePullSecrets:
  - ${IMAGE_PULL_SECRET_NAME}
serverUrl: ${OBSERVABILITY_BASEURL}
apiKey: ${OBSERVABILITY_API_KEY}
apiToken: ${OBSERVABILITY_API_CLI_TOKEN}
clusterName: ${OBSERVABILITY_OBSERVED_CLUSTER_NAME}
 " > ${CUSTOM_OVERRIDES_FILE}
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

install_suse_observability_ai_extension() {
  if ! [ -z ${AI_EXT_VERSION} ]
  then
    local AI_EXT_VER_ARG="--version ${AI_EXT_VERSION}"
  fi

  echo "Installing AI Extension ..."
  echo "------------------------------------------------------------"

  echo "COMMAND: helm upgrade --install ai-extension --namespace ${OBSERVABILITY_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} oci://dp.apps.rancher.io/charts/suse-ai-observability-extension ${AI_EXT_VER_ARG} "
  helm upgrade --install ai-extension --namespace ${OBSERVABILITY_NAMESPACE} --create-namespace -f ${CUSTOM_OVERRIDES_FILE} oci://dp.apps.rancher.io/charts/suse-ai-observability-extension ${AI_EXT_VER_ARG}

  #echo
  #echo "COMMAND: kubectl -n ${OBSERVABILITY_NAMESPACE} rollout status deploy/ai-extension"
  #kubectl -n ${OBSERVABILITY_NAMESPACE} rollout status deploy/ai-extension
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
    check_for_kubectl
    check_for_helm
    create_ai_extension_custom_overrides_file
    display_custom_overrides_file
  ;;
  install_only)
    check_for_kubectl
    check_for_helm
    log_into_app_collection
    create_app_collection_secret
    install_suse_observability_ai_extension
  ;;
  help|-h|--help)
    usage
    exit
  ;;
  *)
    check_for_kubectl
    check_for_helm
    log_into_app_collection
    create_app_collection_secret
    create_ai_extension_custom_overrides_file
    display_custom_overrides_file
    install_suse_observability_ai_extension
  ;;
esac

