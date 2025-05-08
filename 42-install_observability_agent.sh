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
  CLUSTER_NAME=aicluster01
  OBSERVABILITY_NAMESPACE=susse-observability
  OBSERVABILITY_HELM_REPO_URL=https://charts.rancher.com/server-charts/prime/suse-observability
fi

#LICENSES_FILE=authentication_and_licenses.cfg

CUSTOM_OVERRIDES_FILE=otc_custom_overrides.yaml

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

install_observability_agent() {
  echo "Installing the Observability Agent ..."
  echo "------------------------------------------------------------"

  echo "COMMAND: helm repo add suse-observability ${OBSERVABILITY_HELM_REPO_URL}"
  helm repo add suse-observability ${OBSERVABILITY_HELM_REPO_URL}

  echo "COMMAND: helm repo update"
  helm repo update
  echo

  echo "COMMAND: helm upgrade --install --namespace ${OBSERVABILITY_NAMESPACE} --create-namespace --set-string stackstate.apiKey=${OBSERVABILITY_RECEIVER_API_KEY} --set-string stackstate.cluster.name=${CLUSTER_NAME} --set-string stackstate.url=http://${OBSERVABILITY_HOST}/receiver/stsAgent --set nodeAgent.skipKubeletTLSVerify=true suse-observability-agent suse-observability/suse-observability-agent"
  helm upgrade --install --namespace suse-observability ${OBSERVABILITY_NAMESPACE} --set-string stackstate.apiKey=${OBSERVABILITY_RECEIVER_API_KEY} --set-string stackstate.cluster.name=${CLUSTER_NAME} --set-string stackstate.url=http://${OBSERVABILITY_HOST}/receiver/stsAgent --set nodeAgent.skipKubeletTLSVerify=true suse-observability-agent suse-observability/suse-observability-agent
  echo

  echo
  echo "COMMAND: kubectl -n ${OBSERVABILITY_NAMESPACE} rollout status deploy/suse-observability-agent"
  kubectl -n ${OBSERVABILITY_NAMESPACE} rollout status deploy/suse-observability-agent
}


##############################################################################

case ${1} in
  *)
    check_for_kubectl
    check_for_helm
    install_observability_agent
  ;;
esac

