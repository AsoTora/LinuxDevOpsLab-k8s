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



echo "************2.3*************"
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



echo "************2.4*************"
# 2.4
# Cluster Init 
# kubeadm reset # in case of running multiple times

sudo sed -i "s/\(KUBELET_EXTRA_ARGS=\).*/\1--node-ip=192.168.56.11/" /etc/sysconfig/kubelet

sudo kubeadm init \
  --pod-network-cidr 10.244.0.0/16 \
  --apiserver-advertise-address 192.168.56.11 \
  --token abcdef.0123456789abcdef \
  --ignore-preflight-errors=all

# Save k8s config for kubectl
mkdir -p $HOME/.kube
sudo cp -i -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
# sudo scp /etc/kubernetes/admin.conf student@192.168.56.1:$HOME/.kube/admin.conf



echo "************2.5*************"
# 2.5 Deploying POD Network
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/k8s-manifests/kube-flannel-rbac.yml
kubectl patch daemonsets kube-flannel-ds-amd64 -n kube-system --patch='{
  "spec":{
    "template":{
      "spec":{
        "containers":[
        {
          "name": "kube-flannel",
          "args":[
          "--ip-masq",
          "--kube-subnet-mgr",
          "--iface=eth1"
          ]
        }
        ]
      }
    }
  }
}'
kubectl get daemonsets -n kube-system kube-flannel-ds-amd64
kubectl get nodes | grep master


# To deploy stuff on master node. After slave joins cluster its unnecessary
echo "************2.6*************"
# 2.6 master isolation
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl patch node k8s-master -p='{
    "metadata": {
        "labels": {
            "node-role.kubernetes.io/node": ""
        }
    }
}'



echo "************3.1*************"
# 3.1 Deploy Dashboard
dash=$(kubectl get deployments --all-namespaces | grep kubernetes-dashboard >/dev/null; echo $?)
if [ $dash -ne 0 ]; then 
    echo "Deploying Dashboard"
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml
    # Add to Cluster Info
    kubectl patch svc -n kube-system kubernetes-dashboard --patch='{
      "metadata": {
        "labels": {
          "kubernetes.io/cluster-service": "true",
          "k8s-addon": "kubernetes-dashboard.addons.k8s.io"
        }
      }
    }'
    
    # create service account
    cat << EOF | kubectl apply -f -
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
EOF
fi

# Admin Token
echo "*********TOKEN***********"
echo
echo
echo
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
kubectl proxy &
echo
echo
echo
echo "*********TOKEN***********"


# temp port
kubectl get svc -n kube-system kubernetes-dashboard
kubectl patch svc -n kube-system kubernetes-dashboard --patch='{
    "spec": {
        "type": "NodePort"
    }
}'
kubectl get svc -n kube-system kubernetes-dashboard



echo "************3.2*************"
# 3.2 MetalLB
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.56.1-192.168.56.254
EOF


# expose Dashboard to LB
kubectl patch svc -n kube-system kubernetes-dashboard --patch='{
    "spec": {
        "type": "LoadBalancer"
    }
}'
kubectl get svc -n kube-system kubernetes-dashboard




echo "************3.3*************"
# 3.3 Deploying Nginx Ingress Controller
# - https://github.com/nginxinc/kubernetes-ingress/blob/master/docsinstallation.md
# - https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal
# https://github.com/nginxinc/kubernetes-ingress/blob/master/docs/installation.md

# setup ns and account
kubectl apply -f https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/master/deployments/common/ns-and-sa.yaml
# mandatory
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.0/deploy/static/mandatory.yaml
# bare-metal with MetalLB
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.0/deploy/static/provider/cloud-generic.yaml

# With MetaLB, IP will be allocated automatically
kubectl patch svc ingress-nginx -n default --patch '{
    "spec": {
      "type": "LoadBalancer"
    }
}'

# WITHOUT MetalLB it will be mandatory to setup ExternalIP's
kubectl patch svc ingress-nginx -n default --patch '{
    "spec": {
      "externalIPs": 
    }
}'

kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx
kubectl get svc -A

# deploy simple web-app to ensure ingress works correclty
kubectl apply -f /vagrant/simple-webapp-ingress


# 4

# 4.3 autocompletion
sudo yum install -y bash-completion
source /usr/share/bash-completion/bash_completion
echo 'source <(kubectl completion bash)' >>~/.bashrc
sudo kubectl completion bash >/etc/bash_completion.d/kubectl



# 4.4 Helm
cd /opt 
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > install-helm.sh
chmod u+x install-helm.sh
./install-helm.sh
# check
helm version
