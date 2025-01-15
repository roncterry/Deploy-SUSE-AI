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

# OBSERVABILITY_LICENSE_KEY and OBSERVABILITY_HELM_REPO_URL are in a separate
# config file that is sourced in here:
source authentication_and_licenses.cfg

#SUSE_AI_NAMESPACE=suse-ai

#OBSERVABILITY_HOST=ai-observability.example.com
#OBSERVABILITY_BASEURL=http://${OBSERVABILITY_HOST}
#OBSERVABILITY_SIZING_PROFILE=trial
#OBSERVABILITY_VALUES_DIR=${PWD}

##############################################################################

install_observability() {
  echo
  echo "COMMAND: helm repo add suse-observability ${OBSERVABILITY_HELM_REPO_URL}"
  helm repo add suse-observability ${OBSERVABILITY_HELM_REPO_URL}
  echo "COMMAND: helm repo update"
  helm repo update
  echo

  echo "COMMAND: helm template --set license=\"${OBSERVABILITY_LICENSE_KEY}\" --set baseUrl=\"${OBSERVABILITY_BASEURL}\" --set sizing.profile=\"${OBSERVABILITY_SIZING_PROFILE}\" suse-observability-values suse-observability/suse-observability-values --output-dir ${OBSERVABILITY_VALUES_DIR}"
  helm template --set license="${OBSERVABILITY_LICENSE_KEY}" --set baseUrl="${OBSERVABILITY_BASEURL}" --set sizing.profile="${OBSERVABILITY_SIZING_PROFILE}" suse-observability-values suse-observability/suse-observability-values --output-dir ${OBSERVABILITY_VALUES_DIR}

  echo "Writing out ingress manifest ..."
  echo
  echo "
ingress:
  annotations: 
    nginx.ingress.kubernetes.io/proxy-body-size: '50m'
    nginx.ingress.kubernetes.io/proxy-read-timeout: '3600'
    nginx.ingress.kubernetes.io/proxy-send-timeout: '3600'
  enabled: true
  path: /
  hosts: 
    - host: ${OBSERVABILITY_HOST}
" > ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/ingress_values.yaml
  cat ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/ingress_values.yaml
  echo

  echo "COMMAND: helm upgrade --install --namespace ${SUSE_AI_NAMESPACE} --create-namespace --values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/baseConfig_values.yaml --values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/sizing_values.yaml --values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/ingress_values.yaml suse-observability suse-observability/suse-observability"
  helm upgrade --install --namespace ${SUSE_AI_NAMESPACE} --create-namespace --values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/baseConfig_values.yaml --values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/sizing_values.yaml --values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/ingress_values.yaml suse-observability suse-observability/suse-observability

  echo
  sleep 5
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-kafkaup-operator-kafkaup"
  kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-kafkaup-operator-kafkaup
  echo
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-prometheus-elasticsearch-exporter"
  kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-prometheus-elasticsearch-exporter
  echo
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-router"
  kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-router
  echo
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-ui"
  kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-ui
  echo
  #echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-hbase-console"
  #kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-console
  #echo
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-hbase-correlate"
  kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-correlate
  echo
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-e2es"
  kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-e2es
  echo
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-receiver"
  kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-receiver
  echo
  echo "COMMAND: kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-server"
  kubectl -n ${SUSE_AI_NAMESPACE} rollout status deploy/suse-observability-server
  echo
}

##############################################################################

install_observability

