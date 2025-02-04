#!/bin/bash

# You can either source in the variables from a common config file or
# set the them in this script.

CONFIG_FILE=deploy_suse_ai.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  K8S_DISTRO=rke2
  CLUSTER_NAME=aicluster01
  DOMAIN_NAME=example.com
fi

if [ -z ${1} ]
then
  echo
  echo "ERROR: You must supply the hostname of the first cluster node."
  echo
  echo "Example: ${0} node01"
  echo "         ${0} node01.example.com"
  echo
  exit
else
  if ! echo ${1} | grep -q ${DOMAIN_NAME}
  then
    #NODE01=node01.${DOMAIN_NAME}
    NODE01=${1}.${DOMAIN_NAME}
  else
    NODE01=${1}
  fi
fi

if ! [ $(whoami) == "root" ]
then
  SUDO_CMD=sudo
fi

##############################################################################

retrieve_kubectl() {
  echo "COMMAND: ${SUDO_CMD} scp root@${NODE01}:/var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/"
  ${SUDO_CMD} scp root@${NODE01}:/var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/
  echo

  echo "COMMAND: ${SUDO_CMD} chmod +x /usr/local/bin/kubectl"
  ${SUDO_CMD} chmod +x /usr/local/bin/kubectl
  echo
}

retrieve_kubeconfig() {
  echo "COMMAND: mkdir -p ~/.kube"
  mkdir -p ~/.kube
  echo

  echo "COMMAND: scp root@${NODE01}:/etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config"
  scp root@${NODE01}:/etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config
  echo

  echo "COMMAND: sed -i \"s/\( .*\)server:.*/\1server: https:\/\/${CLUSTER_NAME}.${DOMAIN_NAME}:6443/\" ~/.kube/config"
  sed -i "s/\( .*\)server:.*/\1server: https:\/\/${CLUSTER_NAME}.${DOMAIN_NAME}:6443/" ~/.kube/config
  echo

  echo "COMMAND: "chmod 600 ~/.kube/config
  chmod 600 ~/.kube/config
  echo
}

create_kubectl_bash_completion_file() {
  echo "COMMAND: kubectl completion bash | ${SUDO_CMD} tee /etc/bash_completion.d/kubectl > /dev/null"
  kubectl completion bash | ${SUDO_CMD} tee /etc/bash_completion.d/kubectl > /dev/null
  echo
}

##############################################################################

retrieve_kubectl
retrieve_kubeconfig
create_kubectl_bash_completion_file

