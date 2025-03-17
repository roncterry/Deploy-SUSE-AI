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
  K8S_DISTRO=rke2
  K8S_DISTRO_CHANNEL=stable
  CLUSTER_NAME=observability
fi

#------------------------------------------------------------------------------

# The NODE_TYPE variable must be set in this script.
# Options: server, agent
#
NODE_TYPE=agent

# The FIRST_SERVER must be set to 'true' for the initial server node and 
# 'false' for all other server nodes. This variable must be set in this script.
# This is ignored if NODE_TYPE=agent
#
FIRST_SERVER=false

#########################################
#  Deploy RKE2
#########################################

echo "Downloading ${K8S_DISTRO} installer ..."
echo "COMMAND: curl -sfL https://get.${K8S_DISTRO}.io --output /root/${K8S_DISTRO}-install.sh"
curl -sfL https://get.${K8S_DISTRO}.io --output /root/${K8S_DISTRO}-install.sh

echo "COMMAND: chmod +x /root/${K8S_DISTRO}-install.sh"
chmod +x /root/${K8S_DISTRO}-install.sh
echo

echo "COMMAND: mkdir -p /etc/rancher/${K8S_DISTRO}"
mkdir -p /etc/rancher/${K8S_DISTRO}
echo

echo "Writing out /etc/rancher/${K8S_DISTRO}/config.yaml file ..."
case ${NODE_TYPE} in
  server)
    case ${FIRST_SERVER} in
      true)
        echo "token: ${CLUSTER_NAME}" > /etc/rancher/${K8S_DISTRO}/config.yaml
        echo "tls-san:" >> /etc/rancher/${K8S_DISTRO}/config.yaml
        echo "  - ${CLUSTER_NAME}.example.com" >> /etc/rancher/${K8S_DISTRO}/config.yaml
        echo "write-kubeconfig-mode: 600" >> /etc/rancher/${K8S_DISTRO}/config.yaml
      ;;
      *)
        echo "server: https://${CLUSTER_NAME}.example.com:9345" > /etc/rancher/${K8S_DISTRO}/config.yaml
        echo "token: ${CLUSTER_NAME}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
        echo "tls-san:" >> /etc/rancher/${K8S_DISTRO}/config.yaml
        echo "  - ${CLUSTER_NAME}.example.com" >> /etc/rancher/${K8S_DISTRO}/config.yaml
        echo "write-kubeconfig-mode: 600" >> /etc/rancher/${K8S_DISTRO}/config.yaml
      ;;
    esac
  ;;
  agent)
    echo "server: https://${CLUSTER_NAME}.example.com:9345" > /etc/rancher/${K8S_DISTRO}/config.yaml
    echo "token: ${CLUSTER_NAME}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
  ;;
esac
echo
cat /etc/rancher/${K8S_DISTRO}/config.yaml
echo

echo "COMMAND: INSTALL_RKE2_TYPE=${NODE_TYPE} INSTALL_RKE2_CHANNEL=${K8S_DISTRO_CHANNEL} /root/${K8S_DISTRO}-install.sh"
INSTALL_RKE2_TYPE=${NODE_TYPE} INSTALL_RKE2_CHANNEL=${K8S_DISTRO_CHANNEL} /root/${K8S_DISTRO}-install.sh
echo

echo "COMMAND: systemctl enable --now ${K8S_DISTRO}-${NODE_TYPE}.service"
systemctl enable --now ${K8S_DISTRO}-${NODE_TYPE}.service
echo

case ${NODE_TYPE} in
  server)
    echo "COMMAND: mkdir ~/.kube"
    mkdir ~/.kube
    echo

    echo "COMMAND: cp /etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config"
    cp /etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config
    echo

    echo "COMMAND: ln -s /var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/"
    ln -s /var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/
    echo

    echo "COMMAND: kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null"
    kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
    echo

    echo -n "Waiting for node to be ready "
    until kubectl get nodes | grep -q " Ready"
    do
      echo -n "."
      sleep 2
    done
    echo "."
    echo

    echo "COMMAND: kubectl get nodes"
    kubectl get nodes
    echo
  ;;
  agent)
    echo "COMMAND: mkdir ~/.kube"
    mkdir ~/.kube
    echo

    echo "COMMAND: scp ${CLUSTER_NAME}.example.com:/etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config"
    scp ${CLUSTER_NAME}.example.com:/etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config
    echo

    echo "COMMAND: sed -i \"s/127.0.0.1:6443/${CLUSTER_NAME}.example.com:6443/g\" ~/.kube/config"
    sed -i "s/127.0.0.1:6443/${CLUSTER_NAME}.example.com:6443/g" ~/.kube/config
    echo

    echo "COMMAND: scp ${CLUSTER_NAME}.example.com:/var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/"
    scp ${CLUSTER_NAME}.example.com:/var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/
    echo

    echo "COMMAND: chmod +x /usr/local/bin/kubectl"
    chmod +x /usr/local/bin/kubectl
    echo

    echo "COMMAND: kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null"
    kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
    echo
  ;;
esac

