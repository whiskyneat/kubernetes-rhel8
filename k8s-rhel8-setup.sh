#!/bin/bash
##01
echo "01 Disabling swap...."
sudo swapoff -a
sudo sed -i.bak '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

##02
echo "02 Adding Prereqs"
cat > /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

##03
echo "03 Installing containerd...."
sudo dnf install -y  yum-utils device-mapper-persistent-data lvm2
### Add docker Repository
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
## Install containerd
dnf update -y && dnf install -y containerd.io
## Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
# Restart containerd 
systemctl restart containerd
# Enable containerd on boot 
systemctl enable containerd


##04
echo "04 Installing Kubeadm, kubelet and kubectl...."
# Add yum repo file for Kubernetes  
echo "..04a Adding yum repo for K8s...."
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# Install kubeadm, kubelet and kubectl
echo "..04b Installing Kubernetes...."
dnf install -y kubeadm kubelet kubectl

#enable and start kubelet
systemctl enable kubelet
echo 'KUBELET_EXTRA_ARGS="--fail-swap-on=false"' > /etc/sysconfig/kubelet
systemctl start kubelet

##05
echo "05 Configuring control-plane master with kubeadm...."
sudo kubeadm init --pod-network-cidr=192.168.0.0/16


##06
echo "06 Configure kube user...."
read -p "If you have a successful token key from the installation, please press any key to continue."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


##07
echo "07 Configuring Pod Network with Calico as our CNI...."
sudo dnf install wget -y
kubectl create -f https://projectcalico.docs.tigera.io/manifests/tigera-operator.yaml
kubectl create -f https://projectcalico.docs.tigera.io/manifests/custom-resources.yaml


## Finished
kubectl get nodes -o wide

