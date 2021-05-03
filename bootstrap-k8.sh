#!/usr/bin/env bash

#set -Eeuo pipefail
#trap cleanup SIGINT SIGTERM ERR EXIT


IFNAME=$1
ADDR_LOCAL=127.0.0.1
ADDR_INT=$(ifconfig enp0s3 | grep 'inet ' | xargs | cut -d " " -f 2)
ADDR_EXT=$(ifconfig enp0s8 | grep 'inet ' | xargs | cut -d " " -f 2)

HOST_NAME=$(hostname -s)

echo "IFNAME: $IFNAME"
echo "ADDR_INT: $ADDR_INT"
echo "ADDR_EXT: $ADDR_EXT"
echo "--------------------------"
sed -e "s/^.*${HOSTNAME}.*/${ADDR_LOCAL} ${HOSTNAME} ${HOSTNAME}.local/" -i /etc/hosts

#Remove ubuntu-bionic entry
sed -e '/^.*ubuntu-bionic.*/d' -i /etc/hosts
sed -i -e 's/#DNS=/DNS=8.8.8.8/' /etc/systemd/resolved.conf

echo "------------- Disable Swap -------------"
#Disable swaping
sed 's/#   /swap.*/#swap.img/' /etc/fstab
sudo swapoff -a

# #Update /etc/hosts about other hosts
# cat >> /etc/hosts <<EOF
# 192.168.33.10 kmaster
# 192.168.33.11 kslave01
# 192.168.33.12 kslave02
# EOF

echo "------------- Install Basics -------------"
apt-get update

#Install Basics
apt-get install -y wget curl git vim nohup
apt-get install -y software-properties-common
apt-get install -y apt-transport-https gnupg2

#Install Ansible
# apt-add-repository ppa:ansible/ansible
# apt-get install -y ansible

echo "------------- Install ContainerD -------------"
#Install ContainerD
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
systemctl enable containerd
systemctl start containerd
systemctl status containerd
ps -f -C containerd
ctr version

#Install Docker
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
# apt-get install -y docker.io

# run docker commands as vagrant user (sudo not required)
usermod -aG docker vagrant

echo "------------- Install OpenSSH -------------"
#Install SSH Server
apt-get install -y openssh-server
systemctl status ssh
systemctl enable ssh

sed -i "/^[^#]*PasswordAuthentication[[:space:]]no/c\PasswordAuthentication yes" /etc/ssh/sshd_config
systemctl restart ssh

echo "------------- Install Kubernetes -------------"
#Install Kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
apt-get install -y kubeadm kubelet kubectl
apt-mark hold kubeadm kubelet kubectl
kubeadm version
apt-get install -y bash-completion
echo 'source <(kubectl completion bash)' >> ~/.bashrc
kubectl completion bash > /etc/bash_completion.d/kubectl

echo "KUBELET_EXTRA_ARGS=--node-ip=$ADDR_EXT" >> /etc/default/kubelet
systemctl restart kubelet

echo "------------- Setup IP Bridging -------------"
#Set iptables bridging
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo echo '1' > /proc/sys/net/ipv4/ip_forward
sudo sysctl --system

sudo modprobe overlay
sudo modprobe br_netfilter

service systemd-resolved restart
