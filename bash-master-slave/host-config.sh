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


#4.1 Installing kubectl
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kebernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el17-x86_
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg 
exclude=kube*
EOF

sydo yum install -y kubectl --disableexcludes=kubernetes

mkdir -p $HOME/.kube
sudo cp -i -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl get nodes