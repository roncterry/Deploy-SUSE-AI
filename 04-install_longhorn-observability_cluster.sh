#!/bin/bash

# You can either source in the variables from a common config file or
# set them in this script.

CONFIG_FILE=deploy_suse_observability.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  LH_HELM_REPO_URL=https://charts.longhorn.io
  LH_USER="admin"
  LH_PASSWORD="longhorn"
  LH_URL="longhorn.example.com"
  LH_DEFAULT_REPLICA_COUNT=1
  LH_DEFAULT_CLASS_REPLICA_COUNT=1
  LH_CSI_REPLICA_COUNT=1
  LH_RESERVED_DISK_PERCENTAGE=15
fi

if [ -z ${LH_URL} ]
then
  LH_URL="$(hostname -f)"
fi

CUSTOM_OVERRIDES_FILE=longhorn-values.yaml

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


install_openiscsi() {
  case ${NAME} in
    SLES)
      if ! zypper se open-iscsi | grep open-iscsi | grep -q ^i
      then
        echo "Installing open-iscsi ..."
        echo "COMMAND: ${SUDO_CMD} zypper install -y --auto-agree-with-licenses open-iscsi"
        ${SUDO_CMD} zypper install -y --auto-agree-with-licenses open-iscsi
        echo
      fi
    ;;
  esac
}

write_out_longhorn_custom_overrides_file() {
  echo "Writing out ${CUSTOM_OVERRIDES_FILE} file ..."
  echo
  echo "
defaultSettings:
  defaultReplicaCount: ${LH_DEFAULT_REPLICA_COUNT}
  storageReservedPercentageForDefaultDisk: ${LH_RESERVED_DISK_PERCENTAGE}
persistence:
  defaultClassReplicaCount: ${LH_DEFAULT_CLASS_REPLICA_COUNT}
csi:
  attacherReplicaCount: ${LH_CSI_REPLICA_COUNT}
  provisionerReplicaCount: ${LH_CSI_REPLICA_COUNT}
  resizerReplicaCount: ${LH_CSI_REPLICA_COUNT}
  snapshotterReplicaCount: ${LH_CSI_REPLICA_COUNT}
" > ${CUSTOM_OVERRIDES_FILE}
  echo
}

display_custom_overrides_file() {
  echo
  cat ${CUSTOM_OVERRIDES_FILE}
  echo
}

deploy_longhorn() {
  if ! helm repo list | grep -q longhorn
  then
    echo "COMMAND: helm repo add longhorn ${LH_HELM_REPO_URL}"
    helm repo add longhorn ${LH_HELM_REPO_URL}
  fi

  echo "COMMAND: helm repo update"
  helm repo update
  echo

  echo "COMMAND: helm upgrade --install longhorn --namespace longhorn-system --create-namespace -f longhorn-values.yaml longhorn/longhorn"
  helm upgrade --install longhorn --namespace longhorn-system --create-namespace -f longhorn-values.yaml longhorn/longhorn
  echo

  echo "COMMAND: kubectl -n longhorn-system rollout status deploy/longhorn-driver-deployer"
  kubectl -n longhorn-system rollout status deploy/longhorn-driver-deployer
  echo

  until kubectl -n longhorn-system rollout status deploy/longhorn-ui > /dev/null 2>&1
  do
    sleep 1
  done
  echo "COMMAND: kubectl -n longhorn-system rollout status deploy/longhorn-ui"
  kubectl -n longhorn-system rollout status deploy/longhorn-ui
  echo

  until kubectl -n longhorn-system rollout status deploy/csi-attacher > /dev/null 2>&1
  do
    sleep 1
  done
  echo "COMMAND: kubectl -n longhorn-system rollout status deploy/csi-attacher"
  kubectl -n longhorn-system rollout status deploy/csi-attacher
  echo

  until kubectl -n longhorn-system rollout status deploy/csi-provisioner > /dev/null 2>&1
  do
    sleep 1
  done
  echo "COMMAND: kubectl -n longhorn-system rollout status deploy/csi-provisioner"
  kubectl -n longhorn-system rollout status deploy/csi-provisioner
  echo

  until kubectl -n longhorn-system rollout status deploy/csi-resizer > /dev/null 2>&1
  do
    sleep 1
  done
  echo "COMMAND: kubectl -n longhorn-system rollout status deploy/csi-resizer"
  kubectl -n longhorn-system rollout status deploy/csi-resizer
  echo

  until kubectl -n longhorn-system rollout status deploy/csi-snapshotter > /dev/null 2>&1
  do
    sleep 1
  done
  echo "COMMAND: kubectl -n longhorn-system rollout status deploy/csi-snapshotter"
  kubectl -n longhorn-system rollout status deploy/csi-snapshotter
  echo

  echo "-----------------------------------------------------------------------------"
  echo
  echo "COMMAND: kubectl get storageclasses"
  kubectl get storageclasses
  echo

  echo "-----------------------------------------------------------------------------"
  echo
  echo "COMMAND: kubectl describe storageclasses longhorn"
  kubectl describe storageclasses longhorn
  echo 

  echo "-----------------------------------------------------------------------------"
  echo
}

create_longhorn_ingress_secret() {
  echo "${LH_USER}:$(openssl passwd -stdin -apr1 <<< ${LH_PASSWORD})" > longhorn-auth

  echo "Creating secret for Longhorn ingress access ..."
  echo "COMMAND: kubectl -n longhorn-system create secret generic longhorn-auth --from-file=longhorn-auth"
  kubectl -n longhorn-system create secret generic longhorn-auth --from-file=longhorn-auth
  echo
}

write_out_longhorn_ingress_manifest() {
  echo "Writing out longhorn-ingress.yaml ..."
  echo
  echo "
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: longhorn-system
  annotations:
    # type of authentication
    nginx.ingress.kubernetes.io/auth-type: basic
    # prevent the controller from redirecting (308) to HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
    # name of the secret that contains the user/password definitions
    nginx.ingress.kubernetes.io/auth-secret: longhorn-auth
    # message to display with an appropriate context why the authentication is required
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required '
    # custom max body size for file uploading like backing image uploading
    nginx.ingress.kubernetes.io/proxy-body-size: 10000m
spec:
  rules:
  - host: "${LH_URL}"
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
" > longhorn-ingress.yaml
  echo
  cat longhorn-ingress.yaml
  echo
}

create_longhorn_ingress() {
  echo "COMMAND: kubectl -n longhorn-system create -f longhorn-ingress.yaml"
  kubectl -n longhorn-system create -f longhorn-ingress.yaml
  echo

  echo "-----------------------------------------------------------------------------"
  echo "COMMAND: kubectl -n longhorn-system get ingresses"
  kubectl -n longhorn-system get ingresses
  echo 
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

###############################################################################

case ${1} in
  custom_overrides_only)
    write_out_longhorn_custom_overrides_file
    display_custom_overrides_file
  ;;
  install_only)
    install_openiscsi
    check_for_kubectl
    check_for_helm
    display_custom_overrides_file
    deploy_longhorn
  ;;
  help|-h|--help)
    usage
    exit
  ;;
  *)
    install_openiscsi
    check_for_kubectl
    check_for_helm
    write_out_longhorn_custom_overrides_file
    display_custom_overrides_file
    deploy_longhorn
  ;;
esac

if echo ${*} | grep -q with_ingress
then
  write_out_longhorn_ingress_manifest
  create_longhorn_ingress_secret
  create_longhorn_ingress
fi
