# 2.1
sudo yum install -y deltarpm
# sudo yum update -y
sudo yum install -y epel-release wget ntp jq net-tools bind-utils moreutils
sudo systemctl start ntpd
sudo systemctl enable ntpd
# Disabling SELinux
sudo getenforce | grep Disabled || setenforce 0
sudo echo "SELINUX=disabled" > /etc/sysconfig/selinux
# Disabling SWAP
sed -i '/swap/d' /etc/fstab
swapoff --all



echo "************2.2*************"
# 2.2 Configure Docker Daemon
mkdir -p /etc/docker
# Setting CGroup Driver
sudo cat <<EOF > /etc/docker/daemon.json
{
    "exec-opts": [
        "native.cgroupdriver=systemd"
    ]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
docker info | egrep "Cgroup Driver"

# Enable passing bridged IPv4 traffic to iptables' chains
sudo cat <<EOF > /etc/sysctl.d/docker.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system



# 2.3 Kubernetes Base Instalaltion
sudo echo "
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
" > /etc/yum.repos.d/kubernetes.repo

sudo yum install -y kubelet kubeadm kubectl kubernetes-cni

sudo systemctl restart docker && systemctl enable docker
sudo systemctl restart kubelet && systemctl enable kubelet



# join cluster
kubeadm join --token abcdef.0123456789abcdef --discovery-token-unsafe-skip-ca-verification --ignore-preflight-errors=all 192.168.56.11:6443
