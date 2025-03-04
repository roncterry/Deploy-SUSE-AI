#!/bin/bash

K8S_DISTRO="rke2"
NODE_TYPE="agent"

if [ -d /opt/${K8S_DISTRO}/bin ]
then
  BIN_PATH=/opt/${K8S_DISTRO}/bin/
else
  BIN_PATH=/usr/local/bin/
fi

echo
echo "Making a backup copy of the config.yaml ..."
DATESTAMP=$(date +%s)
echo "cp /etc/rancher/${K8S_DISTRO}/config.yaml ~/config.yaml.backup-${DATESTAMP}"
cp /etc/rancher/${K8S_DISTRO}/config.yaml ~/config.yaml.backup-${DATESTAMP}
echo
echo "========================================================================="

echo
echo "Disabling and stopping the service ..."
echo "COMMAND: systemctl disable --now ${K8S_DISTRO}-${NODE_TYPE}.service"
systemctl disable --now ${K8S_DISTRO}-${NODE_TYPE}.service
echo
echo "========================================================================="

echo "Uninstalling RKE2 ..."
echo "COMMAND: ${BIN_PATH}${K8S_DISTRO}-killall.sh"
${BIN_PATH}${K8S_DISTRO}-killall.sh
echo

echo
echo "COMMAND: ${BIN_PATH}${K8S_DISTRO}-uninstall.sh"
${BIN_PATH}${K8S_DISTRO}-uninstall.sh
echo
echo "========================================================================="
echo

case ${NODE_TYPE} in
  server)
    echo "Removing the kubeconfig file ..."
    echo "COMMAND: rm -rf ~/.kube"
    rm -rf ~/.kube
    echo

    echo "Removing the kubectl command ..."
    echo "COMMAND: rm /usr/local/bin/kubectl"
    rm /usr/local/bin/kubectl
    echo
    echo "========================================================================="
    echo
  ;;
esac

echo "----- Finished -----"
echo
