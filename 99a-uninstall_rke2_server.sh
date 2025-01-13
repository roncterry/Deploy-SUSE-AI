#!/bin/bash

K8S_DISTRO="rke2"
NODE_TYPE="server"

if [ -d /opt/${K8S_DISTRO}/bin ]
then
  BIN_PATH=/opt/${K8S_DISTRO}/bin/
else
  BIN_PATH=/usr/local/bin/
fi

cp /etc/rancher/${K8S_DISTRO}/config.yaml ~/config.yaml.backup-$(date +%s)

systemctl disable --now ${K8S_DISTRO}-${NODE_TYPE}.service

${BIN_PATH}${K8S_DISTRO}-killall.sh
${BIN_PATH}${K8S_DISTRO}-uninstall.sh

