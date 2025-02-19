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

CONFIG_FILE=deploy_suse_observability.cfg

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
  OBSERVABILITY_SIZING_PROFILE=trial
  OBSERVABILITY_VALUES_DIR=${PWD}
fi

LICENSES_FILE=authentication_and_licenses.cfg

# OBSERVABILITY_LICENSE_KEY and OBSERVABILITY_HELM_REPO_URL are in a separate
# config file that is sourced in here:
source ${LICENSES_FILE}

##############################################################################

create_observability_templates() {
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
}

install_observability() {
  echo
  echo "COMMAND: helm upgrade --install --namespace ${OBSERVABILITY_NAMESPACE} --create-namespace --values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/baseConfig_values.yaml --values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/sizing_values.yaml --values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/ingress_values.yaml suse-observability suse-observability/suse-observability"
  helm upgrade --install --namespace ${OBSERVABILITY_NAMESPACE} --create-namespace --values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/baseConfig_values.yaml --values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/sizing_values.yaml --values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/ingress_values.yaml suse-observability suse-observability/suse-observability

  echo
  sleep 5
  echo "COMMAND: kubectl rollout status deploy/suse-observability-kafkaup-operator-kafkaup -n ${OBSERVABILITY_NAMESPACE}"
  kubectl rollout status deploy/suse-observability-kafkaup-operator-kafkaup -n ${OBSERVABILITY_NAMESPACE}
  echo
  echo "COMMAND: kubectl rollout status deploy/suse-observability-prometheus-elasticsearch-exporter -n ${OBSERVABILITY_NAMESPACE}"
  kubectl rollout status deploy/suse-observability-prometheus-elasticsearch-exporter -n ${OBSERVABILITY_NAMESPACE}
  echo
  echo "COMMAND: kubectl rollout status deploy/suse-observability-router -n ${OBSERVABILITY_NAMESPACE}"
  kubectl rollout status deploy/suse-observability-router -n ${OBSERVABILITY_NAMESPACE}
  echo
  echo "COMMAND: kubectl rollout status deploy/suse-observability-ui -n ${OBSERVABILITY_NAMESPACE}"
  kubectl rollout status deploy/suse-observability-ui -n ${OBSERVABILITY_NAMESPACE}
  echo
  #echo "COMMAND: kubectl rollout status deploy/suse-observability-hbase-console -n ${OBSERVABILITY_NAMESPACE}"
  #kubectl rollout status deploy/suse-observability-console -n ${OBSERVABILITY_NAMESPACE}
  #echo
  echo "COMMAND: kubectl rollout status deploy/suse-observability-hbase-correlate -n ${OBSERVABILITY_NAMESPACE}"
  kubectl rollout status deploy/suse-observability-correlate -n ${OBSERVABILITY_NAMESPACE}
  echo
  echo "COMMAND: kubectl rollout status deploy/suse-observability-e2es -n ${OBSERVABILITY_NAMESPACE}"
  kubectl rollout status deploy/suse-observability-e2es -n ${OBSERVABILITY_NAMESPACE}
  echo
  echo "COMMAND: kubectl rollout status deploy/suse-observability-receiver -n ${OBSERVABILITY_NAMESPACE}"
  kubectl rollout status deploy/suse-observability-receiver -n ${OBSERVABILITY_NAMESPACE}
  echo
  echo "COMMAND: kubectl rollout status deploy/suse-observability-server -n ${OBSERVABILITY_NAMESPACE}"
  kubectl rollout status deploy/suse-observability-server -n ${OBSERVABILITY_NAMESPACE}
  echo
}

##############################################################################

case ${1} in
  templates_only)
    create_observability_templates
  ;;
  install_only)
    install_observability
  ;;
  help|-h|--help)
    echo 
    echo "USAGE: ${0} [templates_only|install_only]"
    echo 
    exit
  ;;
  *)
    create_observability_templates
    install_observability
  ;;
esac

