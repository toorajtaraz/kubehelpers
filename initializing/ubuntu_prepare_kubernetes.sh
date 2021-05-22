#!/bin/bash 
 
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

#handling netplan 
echo "writing netplan config..."
test_for_nameserver=$(sed '/nameservers/,$!d' /etc/netplan/50-cloud-init.yaml) 
if [[ $test_for_nameserver = *[!\ ]* ]]; then 
        test_out=$(sed '/nameservers:/,+1d' /etc/netplan/50-cloud-init.yaml | sudo tee "/etc/netplan/50-cloud-init.yaml") 
else 
  echo "\$test_for_nameserver is fine" 
fi 
 
output=$(sed "/set-name: ens3/a\            nameservers:\n                addresses: [185.51.200.2, 178.22.122.100]" /etc/netplan/50-cloud-init.yaml | sudo tee "/etc/netplan/50-cloud-init.yaml") 
sudo netplan apply > /dev/null  && echo "netplan config DONE" 
 
 
#installing needed programs 
echo "==>${red}updating packages db and installing needed utils${reset}"
sudo apt update > /dev/null && echo "${green} OK${reset}"  
sudo apt -y install curl apt-transport-https > /dev/null  && echo "${green} OK${reset}"  
echo "==>${red}adding kube keys and repos${reset}"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && echo "${green} OK${reset}"  
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list && echo "${green} OK${reset}"  
sudo apt update > /dev/null  && echo "${green} OK${reset}"  
echo "==>${red}installing kube utils${reset}"
sudo apt -y install vim git curl wget kubelet kubeadm kubectl > /dev/null  && echo "${green} OK${reset}"  
echo "==>${red}puttin kube packages on hold"
sudo apt-mark hold kubelet kubeadm kubectl > /dev/null  && echo "${green} OK${reset}"  
echo "==>${red}testing kubectl & kubeadm${reset}"
kubectl version --client > /dev/null  && kubeadm version > /dev/null  && echo "${green} OK${reset}" 


##disabling swap
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a


##adding needed kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/modules-load.d/k8s.conf <<EOF
br_netfilter
EOF

sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

##installing docker
echo "==>${red}updating packages db and installing needed utils${reset}"
sudo apt update > /dev/null  && echo "${green} OK${reset}"  
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates > /dev/null  && echo "${green} OK${reset}"  
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - > /dev/null  && echo "${green} OK${reset}"  
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /dev/null  && echo "${green} OK${reset}"  
sudo apt update > /dev/null  && echo "${green} OK${reset}"  
sudo apt install -y containerd.io docker-ce docker-ce-cli > /dev/null  && echo "${green} OK${reset}"  

sudo mkdir -p /etc/systemd/system/docker.service.d > /dev/null  && echo "${green} OK${reset}"  

sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

echo "==>${red}enabling docker service${reset}"
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker
echo "${green} OK${reset}"
