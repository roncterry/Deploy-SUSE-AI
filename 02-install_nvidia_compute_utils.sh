#!/bin/bash

case $(whoami) in
  root)
    SUDO_CMD=
  ;;
  *)
    SUDO_CMD=sudo
  ;;
esac

install_nvidia_compute_utils() {
  source /etc/os-release

  if lspci | grep -i nvidia | grep -qi vga
  then
    echo "Nvidia VGA device found, checking for nvidia-compute-utils package ..."
    if ! zypper se nvidia-compute-untils-G06 | grep -q ^i
    then
      case ${NAME} in
        SLES)
          echo "Installing nvidia-compute-utils-G06 ..."
          echo "COMMAND: ${SUDO_CMD} zypper install -y --auto-agree-with-licenses nvidia-compute-utils-G06"
          ${SUDO_CMD} zypper install -y --auto-agree-with-licenses nvidia-compute-utils-G06
          echo
        ;;
      esac
    else
      echo "nvidia-compute-utils-G06 already installed, continuing ..."
      echo
    fi
 
    case ${NAME} in
      SLES)
        if ! [ -e /sbin/ldconfig.real ]
        then
          echo "COMMAND: ${SUDO_CMD} ln -s /sbin/ldconfig /sbin/ldconfig.real"
          ${SUDO_CMD} ln -s /sbin/ldconfig /sbin/ldconfig.real
          echo
        fi
  
        if ! grep -q ^PATH /etc/default/rke2-server
        then
          echo "COMMAND: ${SUDO_CMD} echo PATH=${PATH} >> /etc/default/rke2-server"
          ${SUDO_CMD} echo PATH=${PATH} >> /etc/default/rke2-server
          echo
        fi
      ;;
    esac
  fi
}

##############################################################################

install_nvidia_compute_utils
