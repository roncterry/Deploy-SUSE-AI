#!/bin/bash

# You can either source in the variables from a common config file or
# uncomment the LH_* variables below to have them set in this script.

source deploy_suse_ai.cfg

#LH_HELM_REPO_URL=https://charts.longhorn.io
#LH_USER="admin"
#LH_PASSWORD="longhorn"
#LH_URL="longhorn.example.com"
#LH_DEFAULT_REPLICA_COUNT=3
#LH_DEFAULT_CLASS_REPLICA_COUNT=3

if [ -z ${LH_URL} ]
then
  LH_URL="$(hostname -f)"
fi

source /etc/os-release

###############################################################################

install_openiscsi() {
  case ${NAME} in
    SLES)
      if ! zypper se open-iscsi | grep -q ^i
      then
        zypper install -y --auto-agree-with-licenses open-iscsi
      fi
    ;;
  esac
}

deploy_longhorn() {
  echo "
defaultSettings:
  defaultReplicaCount: ${LH_DEFAULT_REPLICA_COUNT}
persistence:
  defaultClassReplicaCount: ${LH_DEFAULT_CLASS_REPLICA_COUNT}
" > longhorn-values.yaml

  if ! helm repo list | grep -q longhorn
  then
    echo "COMMAND: helm repo add longhorn ${LH_HELM_REPO_URL}"
    helm repo add longhorn ${LH_HELM_REPO_URL}
  fi

  echo "COMMAND: helm repo update"
  helm repo update
  echo

  echo "COMMAND: helm install longhorn --namespace longhorn-system --create-namespace -f longhorn-values.yaml longhorn/longhorn"
  helm install longhorn --namespace longhorn-system --create-namespace -f longhorn-values.yaml longhorn/longhorn
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

}

create_longhorn_ingress() {
  echo "${LH_USER}:$(openssl passwd -stdin -apr1 <<< ${LH_PASSWORD})" > longhorn-auth

  kubectl -n longhorn-system create secret generic longhorn-auth --from-file=longhorn-auth

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

  kubectl -n longhorn-system create -f longhorn-ingress.yaml
}

###############################################################################

install_openiscsi

if ! which kubectl > /dev/null
then
  echo
  echo "ERROR: The rest of this script requires the helm and kubectl commands."
  echo "       Run this again on a control plane node or management machine."
  echo
  exit
fi

if ! which helm > /dev/null
then
  echo
  echo "ERROR: The rest of this script requires the helm and kubectl commands."
  echo "       Run this again on a control plane node or management machine."
  echo
  exit
fi

deploy_longhorn

if echo ${*} | grep -q with-ingress
then
  create_longhorn_ingress
fi

