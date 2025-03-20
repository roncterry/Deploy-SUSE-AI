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

source /etc/os-release

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

install_apache2utils() {
  case ${NAME} in
    SLES)
      if zypper se apache2-utils | grep -q "No matching items found"
      then
        echo
        echo "ERROR: The appache2-utils package is required to provide the htpasswd utility."
        echo "       The appache2-utils package does not appear to be installed or available."
        echo "       Please ensure the sle-module-server-applications product is added and try again."
        echo
        exit
      elif ! zypper se apache2-utils | grep apache2-utils | grep -q ^i
      then
        echo "Installing apache2-utils (for htpasswd)..."
        echo "COMMAND: ${SUDO_CMD} zypper install -y --auto-agree-with-licenses apache2-utils"
        ${SUDO_CMD} zypper install -y --auto-agree-with-licenses apache2-utils
        echo
      fi
    ;;
  esac
}

create_observability_templates() {
  echo
  echo "COMMAND: helm repo add suse-observability ${OBSERVABILITY_HELM_REPO_URL}"
  helm repo add suse-observability ${OBSERVABILITY_HELM_REPO_URL}
  echo "COMMAND: helm repo update"
  helm repo update
  echo

  echo "COMMAND: helm template --set license=\"${OBSERVABILITY_LICENSE_KEY}\" --set baseUrl=\"${OBSERVABILITY_BASEURL}\" --set sizing.profile=\"${OBSERVABILITY_SIZING_PROFILE}\" suse-observability-values suse-observability/suse-observability-values --output-dir ${OBSERVABILITY_VALUES_DIR}"
  helm template --set license="${OBSERVABILITY_LICENSE_KEY}" --set baseUrl="${OBSERVABILITY_BASEURL}" --set sizing.profile="${OBSERVABILITY_SIZING_PROFILE}" suse-observability-values suse-observability/suse-observability-values --output-dir ${OBSERVABILITY_VALUES_DIR}

  export OBSERVABILITY_BASECONFIG_VALUES_ARG="--values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/baseConfig_values.yaml"
  export OBSERVABILITY_SIZING_VALUES_ARG="--values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/sizing_values.yaml"
}

write_out_observability_ingress_values_file() {
  if ! [ -z "${OBSERVABILITY_HOST}" ]
  then
    case ${OBSERVABILITY_TLS_SOURCE} in
      secret)
        echo "COMMAND: kubectl -n ${OBSERVABILITY_NAMESPACE} create secret tls tls-ingress-secret --cert ${OBSERVABILITY_TLS_CERT_FILE} --key ${OBSERVABILITY_TLS_KEY_FILE}"
        kubectl -n ${OBSERVABILITY_NAMESPACE} create secret tls tls-ingress-secret --cert ${OBSERVABILITY_TLS_CERT_FILE} --key ${OBSERVABILITY_TLS_KEY_FILE}
        echo

        echo "COMMAND: kubectl -n ${OBSERVABILITY_NAMESPACE} create secret generic tls-ca --from-file=${OBSERVABILITY_TLS_CA_FILE}"
        kubectl -n ${OBSERVABILITY_NAMESPACE} create secret generic tls-ca --from-file=${OBSERVABILITY_TLS_CA_FILE}
        echo

        echo "Writing out ingress values ..."
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
  tls:
    - hosts:
        - ${OBSERVABILITY_HOST}
      secretName: tls-ingress-secret
" > ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/ingress_values.yaml
      ;;
      letsEncrypt)
        echo "Writing out ingress values ..."
        echo
        echo "
ingress:
  annotations: 
    nginx.ingress.kubernetes.io/proxy-body-size: '50m'
    nginx.ingress.kubernetes.io/proxy-read-timeout: '3600'
    nginx.ingress.kubernetes.io/proxy-send-timeout: '3600'
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    cert-manager.io/acme-challenge-type: "http01"
    cert-manager.io/acme-challenge-path: "/.well-known/acme-challenge"
  enabled: true
  path: /
  hosts: 
    - host: ${OBSERVABILITY_HOST}
  tls:
    - hosts:
        - ${OBSERVABILITY_HOST}
      secretName: tls-secret
" > ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/ingress_values.yaml
      ;;
      *)
        echo "Writing out ingress values ..."
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
      ;;
    esac
    cat ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/ingress_values.yaml
    echo 

    OBSERVABILITY_INGRESS_VALUES_ARG="--values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/ingress_values.yaml"
  fi
}

hash_observability_admin_user_password() {
  if ! [ -z "${OBSERVABILITY_ADMIN_PASSWORD}" ]
  then
    echo "Hashing admin password ..."
    echo
    export OBSERVABILITY_ADMIN_PASSWORD_HASH=$(htpasswd -bnBC 10 "" ${OBSERVABILITY_ADMIN_PASSWORD} | tr -d ':\n')

    sed -i "s/^    adminPassword:.*/    adminPassword: \"${OBSERVABILITY_ADMIN_PASSWORD_HASH}\"/g" ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/baseConfig_values.yaml
    sed -i "s/^# Your SUSE Observability admin password is:.*/# Your SUSE Observability admin password is: ${OBSERVABILITY_ADMIN_PASSWORD}\"/g" ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/baseConfig_values.yaml
    echo
    echo "Observability admin username: ${OBSERVABILITY_ADMIN_USERNAME}"
    echo "Observability admin password: ${OBSERVABILITY_ADMIN_PASSWORD}"
    echo
  else
    echo "(Using auto-generated admin password)"
    echo
  fi
}

write_out_observability_auth_values_file() {
  if ! [ -z "${OBSERVABILITY_USERS_LIST}" ]
  then
    echo "Writing out authentication values ..."
    echo
    echo "
stackstate:
  authentication:
    file:
      logins:" > ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/authentication_values.yaml

    if ! [ -z ${OBSERVABILITY_ADMIN_USERNAME} ]
    then
      OBSERVABILITY_ADMIN_USERNAME=admin
    fi

    #if [ -z ${OBSERVABILITY_ADMIN_PASSWORD} ]
    #then
    #fi

    echo "        - username: ${OBSERVABILITY_ADMIN_USERNAME}
          passwordHash: ${OBSERVABILITY_ADMIN_PASSWORD_HASH}
          roles: [ stackstate-admin ]" >> ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/authentication_values.yaml

    for OBSERVABILITY_USER in ${OBSERVABILITY_USERS_LIST}
    do
      local OBSV_USER_NAME=$(echo ${OBSERVABILITY_USER}|cut -d : -f 1)
      local OBSV_USER_PASSWD=$(echo ${OBSERVABILITY_USER}|cut -d : -f 2)
      local OBSV_USER_PASSWD_HASH=$(htpasswd -bnBC 10 "" ${OBSV_USER_PASSWD} | tr -d ':\n')
      local OBSV_USER_ROLE=$(echo ${OBSERVABILITY_USER}|cut -d : -f 3)
      echo "        - username: ${OBSV_USER_NAME}
          passwordHash: ${OBSV_USER_PASSWD_HASH}
          roles: [ ${OBSV_USER_ROLE} ]" >> ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/authentication_values.yaml
    done

    cat ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/authentication_values.yaml
    echo 
    export OBSERVABILITY_AUTH_VALUES_ARG="--values ${OBSERVABILITY_VALUES_DIR}/suse-observability-values/templates/authentication_values.yaml"
    echo
  fi
}

install_certmanager_for_observability() {
  echo "Installing Cert-Manager ..."
  echo "------------------------------------------------------------"
  echo "COMMAND: 
  helm repo add cert-manager ${CERTMANAGER_HELM_REPO}
  helm repo update"

  helm repo add cert-manager ${CERTMANAGER_HELM_REPO}
  helm repo update

  echo
  echo "COMMAND: helm install suse-observability-cert-manager cert-manager/cert-manager --namespace ${OBSERVABILITY_NAMESPACE} --create-namespace --set crds.enabled=true ${CERTMANAGER_VERSION}"
  helm install suse-observability-cert-manager cert-manager/cert-manager --namespace ${OBSERVABILITY_NAMESPACE} --create-namespace --set crds.enabled=true ${CERTMANAGER_VERSION}

  echo
  echo "COMMAND: kubectl -n cert-manager rollout status deploy/cert-manager"
  kubectl -n cert-manager rollout status deploy/cert-manager
}

install_observability() {
  echo
  echo "COMMAND: helm upgrade --install --namespace ${OBSERVABILITY_NAMESPACE} --create-namespace ${OBSERVABILITY_BASECONFIG_VALUES_ARG} ${OBSERVABILITY_SIZING_VALUES_ARG} ${OBSERVABILITY_INGRESS_VALUES_ARG} ${OBSERVABILITY_AUTH_VALUES_ARG} suse-observability suse-observability/suse-observability"
  helm upgrade --install --namespace ${OBSERVABILITY_NAMESPACE} --create-namespace ${OBSERVABILITY_BASECONFIG_VALUES_ARG} ${OBSERVABILITY_SIZING_VALUES_ARG} ${OBSERVABILITY_INGRESS_VALUES_ARG} ${OBSERVABILITY_AUTH_VALUES_ARG} suse-observability suse-observability/suse-observability

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

usage() {
  echo 
  echo "USAGE: ${0} [templates_only|install_only]"
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

install_apache2utils

case ${1} in
  templates_only)
    check_for_kubectl
    check_for_helm
    create_observability_templates
    write_out_observability_ingress_values_file
    hash_observability_admin_user_password
    write_out_observability_auth_values_file
  ;;
  install_only)
    check_for_kubectl
    check_for_helm
    install_observability
  ;;
  help|-h|--help)
    usage
    exit
  ;;
  *)
    check_for_kubectl
    check_for_helm
    create_observability_templates
    write_out_observability_ingress_values_file
    hash_observability_admin_user_password
    write_out_observability_auth_values_file
    install_observability
  ;;
esac

