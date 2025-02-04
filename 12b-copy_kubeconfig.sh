#!/bin/bash

#######################################################
# Usage: ${0} [<username>]
#######################################################

if [ -z ${1} ]
then
  TARGET_USERNAME=$(whoami)
  TARGET_GROUP=$(groups | awk '{ print $1 }')
  TARGET_HOMEDIR=${HOME}
else
  TARGET_USERNAME=${1}
  TARGET_GROUP=$(goups ${TARGET_USERNAME} | cut -d : -f 2 | awk '{ print $1 ]')
  TARGET_HOMEDIR=/home/${TARGET_USERNAME}
fi

K8S_DISTRO=rke2

##############################################################################

echo "Copying kubeconfig file to ${TARGET_HOMEDIR}/.kube/config ..."
echo

echo "COMMAND: mkdir ${TARGET_HOMEDIR}/kube"
mkdir ${TARGET_HOMEDIR}/kube

echo "COMMAND: sudo cp /etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ${TARGET_HOMEDIR}/.kube/config"
sudo cp /etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ${TARGET_HOMEDIR}/.kube/config

echo "COMMAND: sudo chown -R ${TARGET_USERNAME}.${TARGET_GROUP} ${TARGET_HOMEDIR}/.kube"
sudo chown -R ${TARGET_USERNAME}.${TARGET_GROUP} ${TARGET_HOMEDIR}/.kube

echo
