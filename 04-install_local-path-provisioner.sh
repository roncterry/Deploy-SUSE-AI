#!/bin/bash

LPP_INSTALL_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"
LPP_IS_DEFAULT_STORAGECLASS="true"

echo "COMMAND: kubectl apply -f ${LPP_INSTALL_URL}"
kubectl apply -f ${LPP_INSTALL_URL}
echo

case ${LPP_IS_DEFAULT_STORAGECLASS} in 
  true)
    echo "COMMAND: kubectl annotate storageclass local-path storageclass.kubernetes.io/is-default-class=true"
    kubectl annotate storageclass local-path storageclass.kubernetes.io/is-default-class=true
    echo
  ;;
esac
