#!/bin/bash

source /etc/os-release

#########################################################
#     Cert-Manager Vars
#########################################################

# Cert-Manager Helm Install URL
# 
# The Helm repo to install Cert-Manager from.
#
CERTMANAGER_HELM_REPO="https://charts.jetstack.io"


# Version of cert-manager to install
#
#CERTMANAGER_VERSION="--version v1.11.0"
CERTMANAGER_VERSION=""


#########################################################
#     Rancher Vars
#########################################################

# Rancher Helm Install URL
# 
# The Helm repo to install Rancher Manager from.
#
RANCHER_HELM_REPO="https://charts.rancher.com/server-charts/prime"


# The hostname/FQDN to use for the Rancher manager
# This must be resolvable via DNS.
#
RANCHER_HOSTNAME="cluster01.example.com"


# The password to use for the Rancher admin user
#
RANCHER_ADMIN_PW="rancher"


# The number of Rancher replicas to run in the cluster
#
RANCHER_REPLICAS=1


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

install_rancher() {
  echo "Installing Rancher ..."
  echo "------------------------------------------------------------"
  echo "COMMAND: 
  helm repo add cert-manager ${CERTMANAGER_HELM_REPO}
  helm repo add rancher-latest ${RANCHER_HELM_REPO}
  helm repo update"

  helm repo add cert-manager ${CERTMANAGER_HELM_REPO}
  helm repo add rancher-manager ${RANCHER_HELM_REPO}
  helm repo update

  echo "COMMAND: helm install cert-manager cert-manager/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true ${CERTMANAGER_VERSION}"
  helm install cert-manager cert-manager/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true ${CERTMANAGER_VERSION}

  echo "COMMAND: kubectl -n cert-manager rollout status deploy/cert-manager"
  kubectl -n cert-manager rollout status deploy/cert-manager
  echo

  echo "COMMAND: helm install rancher rancher-manager/rancher --namespace cattle-system --create-namespace --set hostname=${RANCHER_HOSTNAME} --set bootstrapPassword=${RANCHER_ADMIN_PW} --set replicas=${RANCHER_REPLICAS}"
  helm install rancher rancher-manager/rancher --namespace cattle-system --create-namespace --set hostname=${RANCHER_HOSTNAME} --set bootstrapPassword=${RANCHER_ADMIN_PW} --set replicas=${RANCHER_REPLICAS}

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

install_rancher

