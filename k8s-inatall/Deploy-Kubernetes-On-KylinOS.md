```textile
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```

本文是阐述如何在kylin os上部署kubernetes

|系统版本|K8S版本|节点名称|节点IP|
|-|-|-|-|
|Kylin V10 SP3|1.30.2|k8s-master|192.168.8.3|
|Kylin V10 SP3|1.30.2|k8s-worker1|192.168.8.4|
|Kylin V10 SP3|1.30.2|k8s-worker2|192.168.8.5|

# 确认系统版本

```bash
cat /etc/os-release
```
输出

```text
NAME="Kylin Linux Advanced Server"
VERSION="V10 (Lance)"
ID="kylin"
VERSION_ID="V10"
PRETTY_NAME="Kylin Linux Advanced Server V10 (Lance)"
ANSI_COLOR="0;31"
```

# 配置hosts解析

**这一步需要在所有机器上完成**

```bash
cat >> /etc/hosts <<EOF
192.168.8.3 k8s-master
192.168.8.4 k8s-worker1
192.168.8.5 k8s-worker2
EOF
```

# 安装docker作为运行时

服务器版的kylin基于红帽系的yum作为包管理器

**安装docker的所有步骤，也就是从准备docker仓库一直到cri-docker部署都需要在所有节点完成**

## 准备docker ce仓库

```bash
cat > /etc/yum.repos.d/docker-ce.repo << 'EOF'
[lxh-docker-ce]
name=docker ce
baseurl=https://mirrors.nju.edu.cn/docker-ce/linux/rhel/8/x86_64/stable/
enabled=1
gpgcheck=0
EOF
```

## 部署docker ce

```bash
yum install docker-ce -y
```

## 启动docker服务

```bash
systemctl enable docker --now
```

## 测试docker是否正常工作

尝试运行一个测试容器

```bash
docker run hello-world
```

输出以下内容为正常

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/

```

## 部署cri-docker

cri-docker将作为k8s和docker的沟通桥梁所在

```bash
curl -o cri-docker.rpm https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.14/cri-dockerd-0.3.14-3.el8.x86_64.rpm
```
下载后安装
```bash
yum localinstall cri-docker.rpm -y
```

修改镜像到国内并启动服务

```bash
sed -i 's/ExecStart=.*/ExecStart=\/usr\/bin\/cri-dockerd --container-runtime-endpoint fd:\/\/ --network-plugin=cni --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com\/google_containers\/pause:3.9/' /lib/systemd/system/cri-docker.service
systemctl daemon-reload
systemctl restart cri-docker.service
systemctl enable cri-docker.service
```

# Kubernetes 部署

## 关闭swap分区

**这一步需要在所有机器上完成**

```bash
swapoff -a
sed -i 's/.*swap.*/#&/' /etc/fstab
```

## 允许 iptables 检查桥接流量

**这一步需要在所有机器上完成**

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl --system
```

## 关闭SELINUX

```bash
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
```

## 安装 kubeadm

**这一步需要在所有机器上完成**

```bash
cat > /etc/yum.repos.d/k8s.repo << 'EOF'
[lxh-k8s]
name=k8s repo
baseurl=https://mirrors.nju.edu.cn/kubernetes/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=0
EOF
```

```bash
yum install -y kubelet kubeadm kubectl
systemctl enable --now kubelet
```

## 添加命令自动补齐功能

这一步不是必须执行的，只是为了提升使用体验

```bash
yum install bash-completion -y
kubectl completion bash > /etc/bash_completion.d/kubectl
kubeadm completion bash > /etc/bash_completion.d/kubeadm
source /etc/bash_completion.d/kubectl
source /etc/bash_completion.d/kubeadm
```

## 集成CRI-Docker

**这一步需要在所有机器上完成**

让k8s对接cri-docker，然后cri-docker再去对接docker

集成的步骤务必确保crictl images命令回车的时候不能出错

```bash
crictl config runtime-endpoint unix:///run/cri-dockerd.sock
crictl images
```

## 准备控制平面防火墙

```bash
sudo firewall-cmd --zone=public --add-port=6443/tcp --permanent
sudo firewall-cmd --zone=public --add-port=2379-2380/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10250/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10259/tcp --permanent
sudo firewall-cmd --zone=public --add-port=10257/tcp --permanent
sudo firewall-cmd --zone=public --add-port=179/tcp --permanent
sudo firewall-cmd --reload
```

## 集群部署

下方kubeadm.yaml中name字段必须在网络中可被解析，也可以将解析记录添加到集群中所有机器的/etc/hosts中

**这个集群部署的操作只需要在master上执行即可**

```bash
kubeadm config print init-defaults > kubeadm.yaml
sed -i 's/.*advert.*/  advertiseAddress: 192.168.8.3/g' kubeadm.yaml
sed -i 's/.*name.*/  name: k8s-master/g' kubeadm.yaml
sed -i 's/imageRepo.*/imageRepository: registry.cn-hangzhou.aliyuncs.com\/google_containers/g' kubeadm.yaml
# 注意下面的替换，只有在集成的是CRI-Docker时才需要执行，而Containerd就不需要
sed -i 's/  criSocket.*/  criSocket: unix:\/\/\/run\/cri-dockerd.sock/' kubeadm.yaml
```

```bash
modprobe br_netfilter 
kubeadm init --config kubeadm.yaml
```

出现下面的提示就是成功了，保存好join的命令

```bash
Your Kubernetes control-plane has initialized successfully!
...
kubeadm join 192.168.8.3:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:d0edd579cbefc3baee6c2253561e24261300ede214ae172bf9687404e09104bf 
```

授权管理权限
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## 部署Calico网络插件

**这个Calico网络插件部署的操作只需要在master上执行即可**

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml 
```

查询集群组件是否工作正常，正常应该都处于running

```bash
kubectl get pod -A
```

## 加入Worker节点

加入节点操作需在所有的worker节点完成，这里要注意，Worker节点需要完成以下先决条件才能执行kubeadm join

1. Docker、CRI-Docker 部署
2. Swap 分区关闭
3. iptables 桥接流量的允许和SELINUX的关闭
4. 安装kubeadm等软件
5. 集成CRI-Docker
6. 所有节点的/etc/hosts中互相添加对方的解析
7. 在防火墙开通工作节点相关端口

**开通防火墙需要在所有工作节点完成**

```bash
firewall-cmd --zone=public --add-port=10250/tcp --permanent
firewall-cmd --zone=public --add-port=10256/tcp --permanent
firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent
firewall-cmd --zone=public --add-port=179/tcp --permanent
firewall-cmd --reload
```

在**master节点**用以下方式生成新的token

```bash
kubeadm token create --print-join-command
```

cri-docker的安装会有多个CRI对象，在**worker节点**上执行以下命令加入节点时，指定CRI对象，案例如下：

```bash
kubeadm join 192.168.8.3:6443 --token m0uywc.81wx2xlrzzfe4he0 \
--discovery-token-ca-cert-hash sha256:5a24296d9c8f5ace4dede7ed46ee2ecf5ed51c0877e5c1650fe2204c09458274 \
--cri-socket=unix:///var/run/cri-dockerd.sock
```

在k8s-master机器上执行以下内容给节点打上角色标签，k8s-worker1 k8s-worker2打上了worker标签

```bash
kubectl label nodes k8s-worker1 k8s-worker2 node-role.kubernetes.io/worker=
kubectl get nodes
```
输出
```text
k8s-master    Ready    control-plane   16m   v1.30.2
k8s-worker1   Ready    worker          10m   v1.30.2
k8s-worker2   Ready    worker          10m   v1.30.2
```

查询pod状态

```bash
kubectl get pod -A
```
输出

```text
NAMESPACE     NAME                                       READY   STATUS    RESTARTS      AGE
kube-system   calico-kube-controllers-5b9b456c66-7v2z5   1/1     Running   0             15m
kube-system   calico-node-5vssp                          1/1     Running   0             15m
kube-system   calico-node-jfd6w                          1/1     Running   0             10m
kube-system   calico-node-kvmcg                          1/1     Running   0             10m
kube-system   coredns-7c445c467-8zzw7                    1/1     Running   0             16m
kube-system   coredns-7c445c467-zpdrd                    1/1     Running   0             16m
kube-system   etcd-k8s-master                            1/1     Running   1 (16m ago)   17m
kube-system   kube-apiserver-k8s-master                  1/1     Running   1 (16m ago)   17m
kube-system   kube-controller-manager-k8s-master         1/1     Running   1 (16m ago)   17m
kube-system   kube-proxy-n9n4h                           1/1     Running   1 (16m ago)   16m
kube-system   kube-proxy-rx2c2                           1/1     Running   0             10m
kube-system   kube-proxy-xscpx                           1/1     Running   0             10m
kube-system   kube-scheduler-k8s-master                  1/1     Running   1 (16m ago)   17m
```