#!/bin/bash

##############################################################################

source /etc/os-release

# You can either source in the variables from a common config file or
# set them in this script.

CONFIG_FILE=deploy_rancher.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  CERTMANAGER_HELM_REPO="https://charts.jetstack.io"
  CERTMANAGER_VERSION=""
  RANCHER_HELM_REPO="https://charts.rancher.com/server-charts/prime"
  RANCHER_HOSTNAME="rancher.example.com"
  RANCHER_ADMIN_PW="rancher"
  RANCHER_REPLICAS=1
  RANCHER_TLS_SOURCE="rancher"
  RANCHER_TLS_EMAIL="admin@example.com"
  RANCHER_TLS_INGRESS_CLASS="nginx"
  RANCHER_TLS_CERT_FILE=
  RANCHER_TLS_KEY_FILE=
  RANCHER_TLS_CA_FILE=
  RANCHER_TLS_PRIVATE_CA=true
fi

##############################################################################

case $(whoami) in
  root)
    SUDO_CMD=""
  ;;
  *)
    SUDO_CMD="sudo"
  ;;
esac


###############################################################################
#   Functions
###############################################################################

test_user() {
  if whoami | grep -q root
  then
    echo
    echo "ERROR: You must run this script as a non-root user. Exiting."
    echo
    exit 1
  fi
}

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

install_certmanager() {
  echo "Installing Cert-Manager ..."
  echo "------------------------------------------------------------"
  echo "COMMAND: 
  helm repo add cert-manager ${CERTMANAGER_HELM_REPO}
  helm repo update"

  helm repo add cert-manager ${CERTMANAGER_HELM_REPO}
  helm repo update

  echo
  echo "COMMAND: helm install cert-manager cert-manager/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true ${CERTMANAGER_VERSION}"
  helm install cert-manager cert-manager/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true ${CERTMANAGER_VERSION}

  echo
  echo "COMMAND: kubectl -n cert-manager rollout status deploy/cert-manager"
  kubectl -n cert-manager rollout status deploy/cert-manager
}

install_rancher() {
  echo
  echo "Installing Rancher ..."
  echo "------------------------------------------------------------"

  case ${RANCHER_TLS_SOURCE} in
    letsEncrypt)
      echo "Retreiving the Let's Encrypt CA certificate ..."
      echo "COMMAND: curl https://letsencrypt.org/certs/isrg-root-x1-cross-signed.pem --output cacerts.pem"
      curl https://letsencrypt.org/certs/isrg-root-x1-cross-signed.pem --output cacerts.pem
      echo

      echo "Creating secret for the CA cert ..."
      echo "COMMAND: kubectl -n cattle-system create secret generic tls-ca --from-file=cacerts.pem"
      kubectl -n cattle-system create secret generic tls-ca --from-file=cacerts.pem

      RANCHER_CERT_ARGS="--set ingress.tls.source=letsEncrypt --set letsEncrypt.email=${RANCHER_TLS_EMAIL} --set letsEncrypt.ingress.class=${RANCHER_TLS_INGRESS_CLASS} --set privateCA=true"
      echo
    ;;
    secret)
      echo "Creating TLS secret ..."
      echo "COMMAND: kubectl -n cattle-system create secret tls tls-rancher-ingress --cert=${RANCHER_TLS_CERT_FILE} --key=${RANCHER_TLS_KEY_FILE}"
      kubectl -n cattle-system create secret tls tls-rancher-ingress --cert=${RANCHER_TLS_CERT_FILE} --key=${RANCHER_TLS_KEY_FILE}
      echo

      echo "Creating secret for the CA cert ..."
      echo "COMMAND: kubectl -n cattle-system create secret generic tls-ca --from-file=${RANCHER_TLS_CA_FILE}"
      kubectl -n cattle-system create secret generic tls-ca --from-file=${RANCHER_TLS_CA_FILE}

      RANCHER_CERT_ARGS="--set ingress.tls.source=secret --set privateCA=${RANCHER_TLS_PRIVATE_CA}"
      echo
    ;;
  esac

  echo "COMMAND: 
  helm repo add rancher-prime ${RANCHER_HELM_REPO}
  helm repo update"

  helm repo add rancher-prime ${RANCHER_HELM_REPO}
  helm repo update

  echo
  echo "COMMAND: helm upgrade --install rancher rancher-prime/rancher --namespace cattle-system --create-namespace --set hostname=${RANCHER_HOSTNAME} --set bootstrapPassword=${RANCHER_ADMIN_PW} --set replicas=${RANCHER_REPLICAS} ${RANCHER_CERT_ARGS}"
  helm upgrade --install rancher rancher-prime/rancher --namespace cattle-system --create-namespace --set hostname=${RANCHER_HOSTNAME} --set bootstrapPassword=${RANCHER_ADMIN_PW} --set replicas=${RANCHER_REPLICAS} ${RANCHER_CERT_ARGS}

  echo
  echo "COMMAND: kubectl -n cattle-system rollout status deploy/rancher"
  kubectl -n cattle-system rollout status deploy/rancher

  echo
  echo
  echo "Finished"
  echo
}

###############################################################################
#   Main Code Body
###############################################################################

case ${RANCHER_TLS_SOURCE} in
  secret)
    install_rancher
  ;;
  *)
    install_certmanager
    install_rancher
  ;;
esac

