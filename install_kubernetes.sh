#!/bin/bash

#------------------Installing kubernetes on minions-------------

apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

#Disabling swap:
sudo swapoff -a
#Also after reboot:
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

#kubeadm join 10.0.2.13:6443 --token yd7ywd.dw5k5uedmru2ysm4 --discovery-token-ca-cert-hash sha256:bf6352b0ed473e369789040bdd4acd40ca862f64b6719834041f4c7007bcc0f5

#kubeadm join 10.0.2.11:6443 --token wov70z.igvg9qyiklotsm2a --discovery-token-ca-cert-hash sha256:2c60a01238abfc8c9fc5034e1cd86672ade10ad5980f98af56170003a181f7a6

#kubeadm join 10.0.2.11:6443 --token 3c3paf.4q395lhi1lmzblw3 --discovery-token-ca-cert-hash sha256:2c60a01238abfc8c9fc5034e1cd86672ade10ad5980f98af56170003a181f7a6
#kubeadm join 10.0.2.13:6443 --token s8o2y4.r6gpebbj4096g8yq --discovery-token-ca-cert-hash sha256:f2ffc5a31fbc4e42c175d8178153bf9b7dc0b92a6ad6cfb1b29a45fb2957ca6e

