#!/bin/bash

#disable swap
sudo swapoff -a

#Install Packages
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

#setup required sysctl params,
sudo cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

#Apply sysctl params without reboot
sudo sysctl --system

#Update system
sudo apt-get update
sudo apt-get install -y containerd

#Configure containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml

#Restart containerd with the new configuration
sudo systemctl restart containerd

#Install Kubernetes packages - kubeadm, kubelet and kubectl
#Add Google's apt repository gpg key
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

#Add the Kubernetes apt repository
sudo bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'

#Update the package list and use apt-cache policy to inspect versions available in the repository
sudo apt-get update
sudo apt-cache policy kubelet | head -n 20

#Install the required packages, if needed we can request a specific version. 
#Use this version because in a later course we will upgrade the cluster to a newer version.
VERSION=1.22.4-00
sudo apt-get install -y kubelet=$VERSION kubeadm=$VERSION kubectl=$VERSION
sudo apt-mark hold kubelet kubeadm kubectl containerd

#Check the status of our kubelet and our container runtime, containerd.
#The kubelet will enter a crashloop until a cluster is created or the node is joined to an existing cluster.
#sudo systemctl status kubelet.service 
#sudo systemctl status containerd.service 


#Ensure both are set to start when the system starts up.
sudo systemctl enable kubelet.service
sudo systemctl enable containerd.service

##Run join command from master.
echo "Run join command from master to join to cluster."