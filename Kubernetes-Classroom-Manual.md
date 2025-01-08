# Kubernetes 课堂笔记

```textile
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```

[TOC]

# Docker和K8S镜像站说明

在<mark>直播上课期间</mark>，我提供了免费的Docker和K8S的镜像加速器以及Docker和K8S软件仓库加速器，需要注意的是，加速器地址可能会受到不可抗力经常变更网址，请需要时，打开以下链接查看最新地址即可

```text
https://www.credclouds.com/k8s/free-image-or-proxy
```

# 准备DNS解析

**这一步需要在所有机器上完成**

```bash
cat >> /etc/hosts <<EOF
192.168.8.3 k8s-master
192.168.8.4 k8s-worker1
192.168.8.5 k8s-worker2
192.168.30.133 registry.xiaohui.cn
EOF
```

# 准备所有机器的软件仓库(可选步骤)

Ubuntu 默认连接国外仓库，可能速度不太好，可以尝试换成国内的仓库加快速度，如果要做，建议在所有机器上都做一下

```bash
cat > /etc/apt/sources.list <<EOF
deb https://mirrors.nju.edu.cn/ubuntu focal main restricted
deb https://mirrors.nju.edu.cn/ubuntu focal-updates main restricted
deb https://mirrors.nju.edu.cn/ubuntu focal universe
deb https://mirrors.nju.edu.cn/ubuntu focal-updates universe
deb https://mirrors.nju.edu.cn/ubuntu focal multiverse
deb https://mirrors.nju.edu.cn/ubuntu focal-updates multiverse
deb https://mirrors.nju.edu.cn/ubuntu focal-backports main restricted universe multiverse
deb https://mirrors.nju.edu.cn/ubuntu focal-security main restricted
deb https://mirrors.nju.edu.cn/ubuntu focal-security universe
deb https://mirrors.nju.edu.cn/ubuntu focal-security multiverse
EOF

apt update
```

我们课程中，目前用的是Docker CE和CRI-Docker，所以请不要再去做containerd的部分

# Docker CE 部署

## 添加Docker 仓库

**为了节约网络流量和时间，这一步只在k8s-master这一台机器上完成，后续如需练习worker节点加入到k8s集群的操作，在k8s-master上初始化好k8s集群后，再来其他节点完成这个步骤也来得及**

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
```

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://mirrors.nju.edu.cn/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.nju.edu.cn/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
```

## 安装Docker CE

**为了节约网络流量和时间，这一步只在k8s-master这一台机器上完成，后续如需练习worker节点加入到k8s集群的操作，在k8s-master上初始化好k8s集群后，再来其他节点完成这个步骤也来得及**

```bash
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

部署完Docker CE之后，还需要cri-docker shim才可以和Kubernetes集成

## CRI-Docker 部署

**为了节约网络流量和时间，这一步只在k8s-master这一台机器上完成，后续如需练习worker节点加入到k8s集群的操作，在k8s-master上初始化好k8s集群后，再来其他节点完成这个步骤也来得及**

```bash
wget https://class-git.myk8s.cn/Mirantis/cri-dockerd/releases/download/v0.3.15/cri-dockerd_0.3.15.3-0.ubuntu-focal_amd64.deb
dpkg -i cri-dockerd_0.3.15.3-0.ubuntu-focal_amd64.deb
```

将镜像指引到国内

```bash
sed -i 's/ExecStart=.*/ExecStart=\/usr\/bin\/cri-dockerd --container-runtime-endpoint fd:\/\/ --network-plugin=cni --pod-infra-container-image=class-k8s.myk8s.cn\/pause:3.10/' /lib/systemd/system/cri-docker.service
systemctl daemon-reload
systemctl restart cri-docker.service
systemctl enable cri-docker.service

```

除非我明确要求，不然不要做下面的Containerd的所有部分

# Containerd 部署

## 安装Containerd

```bash
wget https://class-git.myk8s.cn/containerd/nerdctl/releases/download/v1.7.7/nerdctl-full-1.7.7-linux-amd64.tar.gz
tar Cxzvvf /usr/local nerdctl-full-1.7.7-linux-amd64.tar.gz
```

## 生成配置文件

```bash
mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml
#使用systemd
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
#沙盒镜像改为国内
sed -i 's|sandbox_image = "registry.k8s.io/pause:3.8"|sandbox_image = "registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.10"|' /etc/containerd/config.toml
#添加加速器地址
sed -i '/\[plugins."io.containerd.grpc.v1.cri".registry\]/{n;s|config_path = ""|config_path = "/etc/containerd/certs.d"|}' /etc/containerd/config.toml
```

## 使用镜像加速器

```bash
mkdir /etc/containerd/certs.d/docker.io -p
cat > /etc/containerd/certs.d/docker.io/hosts.toml <<-'EOF'
server = "https://xxx.xxx.xxx"
[host."https://xxx.xxx.xxx"]
  capabilities = ["pull", "resolve", "push"]
EOF
```

## 启动Containerd服务

```bash
systemctl daemon-reload
systemctl enable --now containerd
systemctl enable --now buildkit
```

## 添加nerdctl命令自动补齐功能

```bash
nerdctl completion bash > /etc/bash_completion.d/nerdctl
source /etc/bash_completion.d/nerdctl
```

# 创建第一个容器

## 运行容器

```bash
docker run -d -p 8000:80 --name container1 registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
docker ps
```

输出
```text
CONTAINER ID    IMAGE                             COMMAND                   CREATED          STATUS    PORTS                   NAMES
eea8ed66990c    registry.cn-shanghai.aliyuncs.com/cnlxh/nginx:latest    "/docker-entrypoint.…"    7 seconds ago    Up        0.0.0.0:8000->80/tcp    container1    
```

如果用的是containerd，运行容器的命令就是下面这样的

```bash
nerdctl run -d -p 8000:80 --name container1 registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
nerdctl ps
```

输出

```text
CONTAINER ID    IMAGE                                                   COMMAND                   CREATED           STATUS    PORTS                   NAMES
1353d09a9df3    registry.cn-shanghai.aliyuncs.com/cnlxh/nginx:latest    "/docker-entrypoint.…"    21 seconds ago    Up        0.0.0.0:8000->80/tcp    container1
```

-d 是指后台运行

-p 是端口映射，此处是将宿主机的8000端口和容器内的80端口映射到一起

--name 是指容器的名字

nginx 是指本次使用的镜像名字

## 进入容器

```bash
docker exec -it container1 /bin/bash
root@eea8ed66990c:/# echo hello lixiaohui > /usr/share/nginx/html/index.html
root@eea8ed66990c:/# exit
```

如果用的是containerd，进入容器的命令就是下面这样的

```bash
nerdctl exec -it container1 /bin/bash
root@1353d09a9df3:/# echo hello lixiaohui > /usr/share/nginx/html/index.html
root@1353d09a9df3:/# exit
```

exec -it 是指通过交互式进入terminal

## 访问容器内容

```bash
curl http://127.0.0.1:8000
hello lixiaohui
```

# 镜像相关操作

## Commit 构建

将上述实验中的container1容器生成一个新的镜像：nginx:v1

```bash
docker commit container1 nginx:v1
docker images
```
如果用的是containerd，commit方法构建容器镜像的命令就是下面这样的
```bash
nerdctl commit container1 nginx:v1
nerdctl images
```

输出

```bash
REPOSITORY    TAG       IMAGE ID        CREATED           PLATFORM       SIZE         BLOB SIZE
nginx         latest    0d17b565c37b    13 minutes ago    linux/amd64    149.1 MiB    54.1 MiB
nginx         v1        edc2905109d8    5 seconds ago     linux/amd64    149.2 MiB    54.1 MiB
```

## 使用Commit镜像

使用nginx:v1镜像在本机的3000端口提供一个名为lixiaohuicommit的容器

```bash
docker run -d -p 3000:80 --name lixiaohuicommit nginx:v1
curl http://127.0.0.1:3000

hello lixiaohui
```

如果用的是containerd，使用容器镜像的命令就是下面这样的

```bash
nerdctl run -d -p 3000:80 --name lixiaohuicommit nginx:v1
curl http://127.0.0.1:3000

hello lixiaohui
```

## Dockerfile 构建

```bash
cat > dockerfile <<EOF
FROM registry.cn-shanghai.aliyuncs.com/cnlxh/httpd
MAINTAINER 939958092@qq.com
RUN echo hello lixiaohui dockerfile container > /usr/local/apache2/htdocs/index.html
EXPOSE 80
WORKDIR /usr/local/apache2/htdocs/
EOF
```

```bash
docker build -t httpd:v1 -f dockerfile .
docker images
```

如果用的是containerd，dockerfile方式构建容器镜像的命令就是下面这样的
```bash
nerdctl build  -t httpd:v1 -f dockerfile .
nerdctl images
```

```bash
REPOSITORY    TAG       IMAGE ID        CREATED               PLATFORM       SIZE         BLOB SIZE
httpd         v1        494736083f8f    About a minute ago    linux/amd64    150.2 MiB    53.8 MiB
nginx         latest    2d17cc4981bf    4 minutes ago         linux/amd64    149.1 MiB    54.1 MiB
nginx         v1        fc81b1ce4076    3 minutes ago         linux/amd64    149.2 MiB    54.1 MiB
```

docker build -t httpd:v1 -f dockerfile .
不管是docker还是nerdctl，这个命令后面还有一个英文的句号.是指当前目录

## 使用Dockerfile镜像

用httpd:v1的镜像在本机4000端口上提供一个名为lixiaohuidockerfile的容器

```bash
docker run -d -p 4000:80 --name lixiaohuidockerfile httpd:v1
docker ps
```
如果用的是containerd，dockerfile方式构建容器镜像的使用命令就是下面这样的

```bash
nerdctl run -d -p 4000:80 --name lixiaohuidockerfile httpd:v1
nerdctl ps
```

```bash
CONTAINER ID    IMAGE                             COMMAND                   CREATED          STATUS    PORTS                   NAMES
534323e724a7    docker.io/library/nginx:latest    "/docker-entrypoint.…"    5 minutes ago    Up        0.0.0.0:8000->80/tcp    container1             
7ee887b78a75    docker.io/library/httpd:v1        "httpd-foreground"        3 seconds ago    Up        0.0.0.0:4000->80/tcp    lixiaohuidockerfile    
a41ef87ba51f    docker.io/library/nginx:v1        "/docker-entrypoint.…"    3 minutes ago    Up        0.0.0.0:3000->80/tcp    lixiaohuicommit        
```

```bash
curl http://127.0.0.1:4000
```

```bash
hello lixiaohui dockerfile container
```

## 删除容器

```bash
docker rm -f container1 lixiaohuidockerfile lixiaohuicommit 
```

# 构建私有仓库

**本实验是可选实验，感兴趣的可以线下测试一下，不过这里必须使用docker才行**

构建私有仓库请使用另外一台单独的机器，将IP设置为192.168.30.133，并确保在本文档最开始的地方在所有节点之间执行了添加/etc/hosts文件操作

## 生成root证书信息

```bash
openssl genrsa -out /etc/ssl/private/selfsignroot.key 4096
openssl req -x509 -new -nodes -sha512 -days 3650 -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Company/OU=SH/CN=Root" \
-key /etc/ssl/private/selfsignroot.key \
-out /usr/local/share/ca-certificates/selfsignroot.crt

```

## 生成服务器私钥以及证书请求文件

```bash
openssl genrsa -out /etc/ssl/private/registry.key 4096
openssl req -sha512 -new \
-subj "/C=CN/ST=Shanghai/L=Shanghai/O=Company/OU=SH/CN=xiaohui.cn" \
-key /etc/ssl/private/registry.key \
-out registry.csr

```

## 生成openssl cnf扩展文件

```bash
cat > certs.cnf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = registry.xiaohui.cn
EOF

```

## 签发证书

```bash
openssl x509 -req -in registry.csr \
-CA /usr/local/share/ca-certificates/selfsignroot.crt \
-CAkey /etc/ssl/private/selfsignroot.key -CAcreateserial \
-out /etc/ssl/certs/registry.crt \
-days 3650 -extensions v3_req -extfile certs.cnf

```

## 信任根证书

```bash
update-ca-certificates
```

## 部署Harbor仓库

先部署Docker CE

```bash
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://mirror.nju.edu.cn/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirror.nju.edu.cn/docker-ce/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

```

再添加Docker 镜像加速器，这里只限在国内部署时才需要加速，在国外这样加速反而缓慢

```bash

sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://xxx.xxx.xxx"]
}
EOF

```
添加Compose支持，并启动Docker服务

```bash
curl -L "https://class-git.myk8s.cn/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
sudo systemctl daemon-reload
sudo systemctl restart docker

```

```bash
wget https://class-git.myk8s.cn/goharbor/harbor/releases/download/v2.11.1/harbor-offline-installer-v2.11.1.tgz
tar xf harbor-offline-installer-v2.11.1.tgz -C /usr/local/bin
cd /usr/local/bin/harbor
docker load -i harbor.v2.11.1.tar.gz
```

在harbor.yml中，修改以下参数，定义了网址、证书、密码

```bash
vim harbor.yml
# 修改hostname为registry.xiaohui.cn
# 修改https处的certificate为/etc/ssl/certs/registry.crt
# 修改https处的private_key为/etc/ssl/private/registry.key
# 修改harbor_admin_password为admin
```

```bash
./prepare
./install.sh
```

## 生成服务文件

```bash
cat > /etc/systemd/system/harbor.service <<EOF
[Unit]
Description=Harbor
After=docker.service systemd-networkd.service systemd-resolved.service
Requires=docker.service
Documentation=http://github.com/vmware/harbor
[Service]
Type=simple
Restart=on-failure
RestartSec=5
ExecStart=/usr/local/bin/docker-compose -f /usr/local/bin/harbor/docker-compose.yml up
ExecStop=/usr/local/bin/docker-compose -f /usr/local/bin/harbor/docker-compose.yml down
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
systemctl enable harbor --now
```

在所有的机器上，将registry.xiaohui.cn以及其对应的IP添加到/etc/hosts，然后将上述实验中的httpd:v1镜像，改名为带上IP:PORT形式，尝试上传我们的镜像到本地仓库

```bash
docker login registry.xiaohui.cn
docker tag httpd:v1 registry.xiaohui.cn/library/httpd:v1
docker push registry.xiaohui.cn/library/httpd:v1
```

# Kubernetes 部署

## 关闭swap分区

**为了节约网络流量和时间，这一步只在k8s-master这一台机器上完成，后续如需练习worker节点加入到k8s集群的操作，在k8s-master上初始化好k8s集群后，再来其他节点完成这个步骤也来得及**

```bash
swapoff -a
sed -i 's/.*swap.*/#&/' /etc/fstab
```

## 允许 iptables 检查桥接流量

**为了节约网络流量和时间，这一步只在k8s-master这一台机器上完成，后续如需练习worker节点加入到k8s集群的操作，在k8s-master上初始化好k8s集群后，再来其他节点完成这个步骤也来得及**

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
sudo sysctl --system
```

## 安装 kubeadm

**为了节约网络流量和时间，这一步只在k8s-master这一台机器上完成，后续如需练习worker节点加入到k8s集群的操作，在k8s-master上初始化好k8s集群后，再来其他节点完成这个步骤也来得及**

```bash
apt-get update && apt-get install -y apt-transport-https curl
```

```bash
cat > /etc/apt/sources.list.d/k8s.list <<EOF
deb https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.31/deb /
EOF
curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.31/deb/Release.key | apt-key add -
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
```

## 添加命令自动补齐功能

```bash
kubectl completion bash > /etc/bash_completion.d/kubectl
kubeadm completion bash > /etc/bash_completion.d/kubeadm
source /etc/bash_completion.d/kubectl
source /etc/bash_completion.d/kubeadm
```

## 集成CRI-Docker

**为了节约网络流量和时间，这一步只在k8s-master这一台机器上完成，后续如需练习worker节点加入到k8s集群的操作，在k8s-master上初始化好k8s集群后，再来其他节点完成这个步骤也来得及**

```bash
crictl config runtime-endpoint unix:///run/cri-dockerd.sock
crictl images
```

这里请注意，如果你以及安装并打算使用cri-docker，并不要做下面的集成containerd的步骤

## 集成containerd

```bash
crictl config runtime-endpoint unix:///run/containerd/containerd.sock
crictl images
```

## 集群部署

下方kubeadm.yaml中name字段必须在网络中可被解析，也可以将解析记录添加到集群中所有机器的/etc/hosts中

**这个初始化集群部署的操作只能在k8s-master上执行**

```bash
kubeadm config print init-defaults > kubeadm.yaml
sed -i 's/.*advert.*/  advertiseAddress: 192.168.8.3/g' kubeadm.yaml
sed -i 's/.*name.*/  name: k8s-master/g' kubeadm.yaml
sed -i 's/imageRepo.*/imageRepository: class-k8s.myk8s.cn/g' kubeadm.yaml
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

**这个Calico网络插件部署的操作只能在k8s-master上执行**

```bash
kubectl create -f https://class-git-raw.myk8s.cn/cnlxh/Kubernetes/refs/heads/master/cka-yaml/calico.yaml
```

查询集群组件是否工作正常，正常应该都处于running

```bash
kubectl get pod -A
```

## 加入Worker节点

加入节点操作需在所有的worker节点完成，这里要注意，Worker节点需要完成以下先决条件才能执行kubeadm join

1. Docker、CRI-Docker 部署
2. Swap 分区关闭
3. iptables 桥接流量的允许
4. 安装kubeadm等软件
5. 集成CRI-Docker
6. 所有节点的/etc/hosts中互相添加对方的解析

如果时间长忘记了join参数，可以在**master节点**上用以下方法重新生成

```bash
kubeadm token create --print-join-command
```

如果有多个CRI对象，在**worker节点**上执行以下命令加入节点时，指定CRI对象，案例如下：

```bash
kubeadm join 192.168.8.3:6443 --token m0uywc.81wx2xlrzzfe4he0 \
--discovery-token-ca-cert-hash sha256:5a24296d9c8f5ace4dede7ed46ee2ecf5ed51c0877e5c1650fe2204c09458274 \
--cri-socket=unix:///var/run/cri-dockerd.sock
```

**注意上描述命令最后的--cri-socket参数，在系统中部署了docker和cri-docker时，必须明确指明此参数，并将此参数指向我们的cri-docker，不然命令会报告有两个重复的CRI的错误**

在k8s-master机器上执行以下内容给节点打上角色标签，k8s-worker1 k8s-worker2打上了worker标签

```bash
kubectl label nodes k8s-worker1 k8s-worker2 node-role.kubernetes.io/worker=
kubectl get nodes
```

## 重置集群

如果在安装好集群的情况下，想重复练习初始化集群，或者包括初始化集群报错在内的任何原因，想重新初始化集群时，可以用下面的方法重置集群，重置后，集群就会被删除，可以用于重新部署，一般来说，这个命令仅用于k8s-master这个节点

```bash
root@k8s-master:~# kubeadm reset --cri-socket=unix:///var/run/cri-dockerd.sock
...
[reset] Are you sure you want to proceed? [y/N]: y
...
The reset process does not clean CNI configuration. To do so, you must remove /etc/cni/net.d

The reset process does not reset or clean up iptables rules or IPVS tables.
If you wish to reset iptables, you must do so manually by using the "iptables" command.

If your cluster was setup to utilize IPVS, run ipvsadm --clear (or similar)
to reset your system's IPVS tables.

The reset process does not clean your kubeconfig files and you must remove them manually.
Please, check the contents of the $HOME/.kube/config file.
```

根据提示，手工完成文件和规则的清理

```bash
root@k8s-master:~# rm -rf /etc/cni/net.d
root@k8s-master:~# iptables -F
root@k8s-master:~# rm -rf $HOME/.kube/config
```

清理后就可以重新部署集群了

# Namespace

## 命令行创建

```bash
kubectl create namespace lixiaohui
kubectl get namespaces
```

## YAML文件创建

```bash
cat > namespace.yml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: zhangsan
EOF
```

```bash
kubectl create -f namespace.yml 
kubectl get namespaces
```

创建带有namespace属性的资源

```bash
kubectl run nginx --image=registry.cn-shanghai.aliyuncs.com/cnlxh/nginx --namespace=lixiaohui
kubectl get pod -n lixiaohui 
```

每次查询和创建资源都需要带--namespace=lixiaohui挺麻烦，可以设置默认值

```bash
kubectl config set-context --current --namespace=lixiaohui
kubectl config view | grep namespace:
kubectl get pod
```

删除namespace会删除其下所有资源，但是如果要删除已经切换为默认值的namespace时，可能会卡住，所以我们要先把默认值切换为其他，然后再删除

```bash
kubectl config set-context --current --namespace=default
kubectl delete namespaces lixiaohui zhangsan
```

# Pod

## Pod创建

一个Pod中只有一个业务容器

```bash
cat > pod.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: lixiaohuipod
spec:
  containers:
  - name: hello
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', 'echo "Hello, lixiaohui!" && sleep 3600']
  restartPolicy: OnFailure
EOF
```

```bash
kubectl create -f pod.yml 
kubectl get pod
kubectl logs lixiaohuipod 
```

一个Pod中有多个业务容器

```bash
cat > multicontainer.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod
spec:
  containers:
  - name: hello
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', 'echo "Hello, lixiaohui!" && sleep 3600']
  - name: httpd
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/httpd
    ports:
      - name: web
        containerPort: 80
  restartPolicy: OnFailure
EOF
```

```bash
kubectl create -f multicontainer.yml
kubectl get pod
kubectl get -f multicontainer.yml -o wide
```

```bash
NAME   READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
pod    2/2     Running   0          66s   172.16.200.199   k8s-worker1   <none>           <none>
```

```bash
root@k8s-master:~# curl 172.16.200.199
<html><body><h1>It works!</h1></body></html>
```

## 修改Pod

直接修改yaml文件，然后执行以下命令

```bash
kubectl apply -f pod.yml
```

进入容器并修改其内容

```bash
kubectl exec -it pod -c httpd -- /bin/bash
root@pod:/usr/local/apache2# echo lixiaohuitest > htdocs/index.html 
root@pod:/usr/local/apache2# exit

curl http://172.16.200.199
```

## Init类型容器

根据安排，myapp-container的容器将等待两个init结束之后才会启动，也就是40秒之后才会启动

```bash
cat > init.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: initpd
  labels:
    app: myapp
spec:
  containers:
  - name: myapp-container
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', 'echo The app is running! && sleep 3600']
  initContainers:
  - name: init-myservice
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', "sleep 20"]
  - name: init-mydb
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', "sleep 20"]
EOF
```

```bash
kubectl create -f init.yml 
kubectl get pod -w
```

## Sidecar类型容器

两个容器挂载了同一个目录，一个容器负责写入数据，一个容器负责对外展示

```bash
cat > sidecar.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: sidecarpod
spec:
  containers:
  - name: httpd
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/httpd
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /usr/local/apache2/htdocs/
        name: lixiaohuivolume
  - name: busybox
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', 'echo "Hello sidecar" > /usr/local/apache2/htdocs/index.html && sleep 3600']
    volumeMounts:
      - mountPath: /usr/local/apache2/htdocs/
        name: lixiaohuivolume
  restartPolicy: OnFailure
  volumes:
    - name: lixiaohuivolume
      emptyDir: {}
EOF
```

```bash
kubectl create -f sidecar.yml 
kubectl get -f sidecar.yml -o wide
```

```bash
NAME         READY   STATUS    RESTARTS   AGE     IP             NODE          NOMINATED NODE   READINESS GATES
sidecarpod   2/2     Running   0          3m54s   172.17.245.1   k8s-worker2   <none>           <none>
```

```bash
curl http://172.17.245.1
Hello sidecar
```

## Static Pod

运行中的 kubelet 会定期扫描配置的目录中的变化， 并且根据文件中出现/消失的 Pod 来添加/删除 Pod。 

```bash
systemctl status kubelet
...
Drop-In: /usr/lib/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
```

```bash
tail /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
...
[Service]
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
```

```bash
grep -i static /var/lib/kubelet/config.yaml 
staticPodPath: /etc/kubernetes/manifests
```

编写静态pod yaml

```bash
cat > static.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: staticpod
spec:
  containers:
  - name: hello
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', 'echo "Hello, lixiaohui!" && sleep 3600']
  restartPolicy: OnFailure
EOF
```

把这个yaml文件复制到/etc/kubernetes/manifests，然后观察pod列表，然后把yaml文件移出此文件夹，再观察pod列表

```bash
cp static.yml /etc/kubernetes/manifests/
kubectl get pod
```

```bash
NAME                   READY   STATUS    RESTARTS   AGE
staticpod-k8s-master   1/1     Running   0          74s
```

```bash
rm -rf /etc/kubernetes/manifests/static.yml 
kubectl get pod
```

```bash
No resources found in default namespace.
```

## Pod 删除

kubectl delete pod --all会删除所有pod

```bash
kubectl delete pod --all
```

# kubernetes 控制器

## Replica Set

使用nginx镜像创建具有3个pod的RS,并分配合适的标签

```bash
cat > rs.yml <<EOF
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginxrstest
  labels:
    app: nginxrstest
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginxrstest
  template:
    metadata:
      labels:
        app: nginxrstest
    spec:
      containers:
      - name: nginx
        image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
        ports:
          - name: http
            containerPort: 80
        imagePullPolicy: IfNotPresent
EOF
```

```bash
kubectl create -f rs.yml 
kubectl get replicasets.apps,pods -o wide
```

```bash
NAME                          DESIRED   CURRENT   READY   AGE    CONTAINERS   IMAGES   SELECTOR
replicaset.apps/nginxrstest   3         3         3       2m4s   nginx        nginx    app=nginxrstest

NAME                    READY   STATUS    RESTARTS   AGE   IP              NODE                    NOMINATED NODE   READINESS GATES
pod/nginxrstest-chtkc   1/1     Running   0          62s   172.17.93.196   k8s-worker1             <none>           <none>
pod/nginxrstest-scvhv   1/1     Running   0          62s   172.17.245.4    k8s-worker2             <none>           <none>
pod/nginxrstest-zqllq   1/1     Running   0          62s   172.17.193.2    k8s-master              <none>           <none>
```

```bash
curl http://172.17.93.196
...
<title>Welcome to nginx!</title>
```

```bash
kubectl delete replicasets nginxrstest
```

## Deployment

使用nginx镜像创建具有3个副本的Deployment，并分配合适的属性

```bash
cat > deployment.yml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
EOF
```

我们发现deployment管理了一个RS，而RS又实现了3个pod

```bash
kubectl create -f deployment.yml
kubectl get deployments.apps,replicasets.apps,pods -l app=nginx
```

```bash
NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deployment   3/3     3            3           13s

NAME                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-deployment-69795dd799   3         3         3       13s

NAME                                    READY   STATUS    RESTARTS   AGE
pod/nginx-deployment-69795dd799-7cgwp   1/1     Running   0          13s
pod/nginx-deployment-69795dd799-vm5p4   1/1     Running   0          13s
pod/nginx-deployment-69795dd799-zx9g9   1/1     Running   0          13s
```

## 更新Deployment

将deployment的镜像更改一次

```bash
kubectl set image deployments/nginx-deployment nginx=registry.cn-shanghai.aliyuncs.com/cnlxh/nginx:1.16.1 --record

查看更新进度
kubectl rollout status deployment/nginx-deployment
```

```bash
Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "nginx-deployment" rollout to finish: 1 old replicas are pending termination...
deployment "nginx-deployment" successfully rolled out
```

更新过程是多了一个replicaset

```bash
kubectl get deployments.apps,replicasets.apps,pods -l app=nginx
```

```bash
NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deployment   3/3     3            3           2m55s

NAME                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-deployment-66b957f9d    3         3         3       2m16s
replicaset.apps/nginx-deployment-69795dd799   0         0         0       2m55s

NAME                                   READY   STATUS    RESTARTS   AGE
pod/nginx-deployment-66b957f9d-9cwgq   1/1     Running   0          116s
pod/nginx-deployment-66b957f9d-9zn4p   1/1     Running   0          98s
pod/nginx-deployment-66b957f9d-zvgzd   1/1     Running   0          2m16s
```

## 回滚 Deployment

故意将镜像名称命名设置为 nginx:1.161 而不是nginx:1.16.1，发现永远无法更新成功，此时就需要回退

```bash
kubectl set image deployments/nginx-deployment nginx=nginx:1.161 --record
kubectl rollout status deployment/nginx-deployment
```

```bash
Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 3 new replicas have been updated...
```

查看历史版本

```bash
kubectl rollout history deployments/nginx-deployment
```

```bash
deployment.apps/nginx-deployment 
REVISION  CHANGE-CAUSE
1         <none>
2         kubectl set image deployments/nginx-deployment nginx=registry.cn-shanghai.aliyuncs.com/cnlxh/nginx:1.16.1 --record=true
3         kubectl set image deployments/nginx-deployment nginx=nginx:1.161 --record=true
```

```bash
kubectl rollout history deployment.v1.apps/nginx-deployment --revision=3
```

```bash
deployment.apps/nginx-deployment with revision #3
Pod Template:
  Labels:    app=nginx
    pod-template-hash=64bd4564c8
  Annotations:    kubernetes.io/change-cause: kubectl set image deployments/nginx-deployment nginx=nginx:1.161 --record=true
  Containers:
   nginx:
    Image:    nginx:1.161
    Port:    80/TCP
    Host Port:    0/TCP
    Environment:    <none>
    Mounts:    <none>
  Volumes:    <none>
```

回退到版本2

```bash
kubectl rollout undo deployments/nginx-deployment --to-revision=2
kubectl rollout status deployment/nginx-deployment
```

## 伸缩 Deployment

将指定的deployment副本更改为5

```bash
kubectl scale deployments/nginx-deployment --replicas=5
kubectl get deployments.apps,replicasets.apps -l app=nginx
```

```bash
NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deployment   5/5     5            5           5m6s

NAME                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-deployment-64bd4564c8   0         0         0       113s
replicaset.apps/nginx-deployment-66b957f9d    5         5         5       4m27s
replicaset.apps/nginx-deployment-69795dd799   0         0         0       5m6s
```

```bash
kubectl delete deployments.apps nginx-deployment
```

## DaemonSet

使用busybox镜像，在每一个节点上都运行一个pod

```bash
cat > daemonset.yml <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: lixiaohui
  labels:
    daemonset: test
spec:
  selector:
    matchLabels:
      name: testpod
  template:
    metadata:
      labels:
        name: testpod
    spec:
      containers:
      - name: hello
        image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
        imagePullPolicy: IfNotPresent
        command: ['sh', '-c', 'sleep 3600']
EOF
```

```bash
kubectl create -f daemonset.yml
kubectl get daemonsets.apps
```

```bash
NAME        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
lixiaohui   2         2         2       2            2           <none>          24s
```

```bash
kubectl delete -f daemonset.yml
```

## StatefulSet

使用nginx镜像，创建一个副本数为3的有状态应用，并挂载本地目录到容器中

```bash
cat > statefulset.yml <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  selector:
    matchLabels:
      app: nginx
  serviceName: "nginx"
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
      volumes:
         - name: www
           emptyDir: {}
EOF
```

发现创建的过程是有次序的，这也验证了有状态应用的启动顺序

```bash
kubectl create -f statefulset.yml
kubectl get pods -w
```

```bash
NAME    READY   STATUS             RESTARTS   AGE
web-0   1/1     Running            0          41s
web-1   0/1     Pending            0          0s
web-1   0/1     Pending            0          0s
web-1   0/1     ContainerCreating   0          0s
web-1   0/1     ContainerCreating   0          0s
web-1   1/1     Running             0          4s
web-2   0/1     Pending             0          0s
web-2   0/1     Pending             0          0s
web-2   0/1     ContainerCreating   0          0s
web-2   0/1     ContainerCreating   0          0s
web-2   1/1     Running             0          4s
```

```bash
kubectl get pod
NAME    READY   STATUS    RESTARTS   AGE
web-0   1/1     Running   0          2m47s
web-1   1/1     Running   0          2m6s
web-2   1/1     Running   0          2m2s
```

```bash
kubectl delete -f statefulset.yml
```

## Job与CronJob

### Job

不断打印CKA JOB字符串，失败最多重试4次

```bash
cat > job.yml <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  template:
    spec:
      containers:
      - name: pi
        image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
        imagePullPolicy: IfNotPresent
        command: ["sh",  "-c", "while true;do echo CKA JOB;done"]
      restartPolicy: Never
  backoffLimit: 4
EOF
```

```bash
kubectl create -f job.yml
kubectl get jobs,pods
```

```bash
NAME           COMPLETIONS   DURATION   AGE
job.batch/pi   0/1           82s        82s

NAME           READY   STATUS    RESTARTS   AGE
pod/pi-66qbm   1/1     Running   0          82s
```

```bash
kubectl logs pi-66qbm
```

```bash
CKA JOB
CKA JOB
CKA JOB

```

```bash
kubectl delete -f job.yml
```

### CronJob

每分钟打印一次指定字符串

```bash
cat > cronjob.yml <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cronjobtest
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
            imagePullPolicy: IfNotPresent
            command:
            - /bin/sh
            - -c
            - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure
EOF
```

```bash
kubectl create -f cronjob.yml
# 这里需要等待一分钟再去get
kubectl get cronjobs,pod
```

```bash
NAME                        SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
cronjob.batch/cronjobtest   */1 * * * *   False     0        23s             83s
NAME                                   READY   STATUS      RESTARTS   AGE
pod/cronjobtest-27444239-kqcjc         0/1     Completed   0          23s
```

```bash
kubectl logs cronjobtest-27444239-kqcjc 
```

```bash
Wed Mar  2 11:45:00 UTC 2022
Hello from the Kubernetes cluster
```

```bash
kubectl delete -f crobjob.yml
```

# Service 服务发现

用nginx镜像准备一个3副本的deployment作为后端，并开放80端口

```bash
cat > deployment-service.yml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment-servicetest
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
EOF
```

然后用kubectl expose的命令创建一个针对deployment的服务，并查询endpoint是否准备就绪

```bash
kubectl create -f deployment-service.yml
kubectl expose deployment nginx-deployment-servicetest --port=9000 --name=lxhservice --target-port=80 --type=NodePort
kubectl get service,endpoints
```

```bash
NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
service/kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP          27m
service/lxhservice   NodePort    10.96.213.26   <none>        9000:31919/TCP   28s

NAME                   ENDPOINTS                                                        AGE
endpoints/kubernetes   192.168.8.3:6443                                              27m
endpoints/lxhservice   172.16.152.69:80,172.16.152.72:80,172.16.152.73:80 + 8 more...   28s
```

```bash
curl http://192.168.8.3:31919
```

```bash
...
<title>Welcome to nginx!</title>
```

```bash
kubectl delete service lxhservice 
```

## ClusterIP类型的Service

ClusterIP是默认的Service类型，对外提供8000端口，并把流量引流到具有app: nginx的后端80端口上

```bash
cat > clusterip.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 8000
      targetPort: 80
EOF
```

```bash
kubectl create -f clusterip.yml
kubectl get service
```

```bash
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
my-service   ClusterIP   10.102.224.203   <none>        8000/TCP   88s
```

```bash
curl http://10.102.224.203:8000
```

```bash
...
<title>Welcome to nginx!</title>
```

```bash
kubectl delete -f clusterip.yml
```

## NodePort类型的Service

Type: NodePort将会在节点的特定端口上开通服务，本实验中，我们指定了端口为31788

```bash
cat > nodeport.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nodeservice
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 8000
      targetPort: 80
      nodePort: 31788
EOF
```

```bash
kubectl create -f nodeport.yml
kubectl get service
```

```bash
NAME          TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
nodeservice   NodePort   10.100.234.83   <none>        8000:31788/TCP   11s
```

```bash
# 因为是nodeport，所以用节点IP
curl http://192.168.8.3:31788
```

```bash
...
<title>Welcome to nginx!</title>
```

```bash
kubectl delete -f nodeport.yml
```

## Headless类型的Service

在此类型的Service中，将不会只返回Service IP，会直接返回众多Pod 的IP地址，所以需要进入pod中用集群内DNS进行测试

```bash
cat > headless.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: headless
spec:
  clusterIP: None
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 8000
      targetPort: 80
EOF
```

```bash
kubectl create -f headless.yml
kubectl get service
```

```bash
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
headless   ClusterIP   None         <none>        8000/TCP   4s
```

```bash
kubectl run --rm --image=registry.cn-shanghai.aliyuncs.com/cnlxh/busybox:1.28 -it testpod
```

```bash
If you don't see a command prompt, try pressing enter.
/ # nslookup headless
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      headless
Address 1: 172.16.127.16 172-16-127-16.headless.lixiaohui.svc.cluster.local
Address 2: 172.16.125.86 172-16-125-86.headless.lixiaohui.svc.cluster.local
Address 3: 172.16.125.85 172-16-125-85.headless.lixiaohui.svc.cluster.local
```

```bash
kubectl delete -f headless.yml
kubectl delete deployments.apps nginx-deployment-servicetest
```

## LoadBalancer类型的Service

### 部署metallb负载均衡

先部署一个`metallb controller和Speaker`

1. `metallb controller`用于负责监听 Kubernetes Service 的变化，当服务类型被设置为 LoadBalancer 时，Controller 会从一个预先配置的 IP 地址池中分配一个 IP 地址给该服务，并管理这个 IP 地址的生命周期。

2. `Speaker`负责将服务的 IP 地址通过标准的路由协议广播到网络中，确保外部流量能够正确路由到集群中的服务。

```bash
kubectl apply -f https://gitee.com/cnlxh/Kubernetes/raw/master/cka-yaml/metallb-native.yaml
```

定义一组由负载均衡对外分配的IP地址范围

```yaml
cat > ippool.yml <<-EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lxh-ip-pool-192-168-8-10-100
  namespace: metallb-system
spec:
  addresses:
  - 192.168.8.10-192.168.8.100
EOF
```

```bash
kubectl apply -f ippool.yml
```

在 Layer 2 模式下用于控制如何通过 ARP（Address Resolution Protocol）或 NDP（Neighbor Discovery Protocol）协议宣告服务的 IP 地址，使得这些 IP 地址在本地网络中可解析

```yaml
cat > l2Advertisement.yml <<-EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-myippool
  namespace: metallb-system
spec:
  ipAddressPools:
  - lxh-ip-pool-192-168-8-10-100
EOF
```
```bash
kubectl apply -f l2Advertisement.yml
```

### 部署LoadBalancer 服务

负载均衡准备好之后，创建LoadBalancer类型的服务

```bash
cat > loadbalancer.yml <<-EOF
apiVersion: v1
kind: Service
metadata:
  name: loadbalance-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
EOF
```

```bash
kubectl apply -f loadbalancer.yml
```

获取服务看看是否分配到了负载均衡IP

```bash
kubectl get service
```

从输出上看，分配到了192.168.8.10

```text
NAME                  TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)          AGE
loadbalance-service   LoadBalancer   10.110.113.122   192.168.8.10   80:30214/TCP     4s
```

用负载均衡IP访问一下试试

```bash
curl 192.168.8.10
```

```text
<title>Welcome to nginx!</title>
```

删除service资源

```bash
kubectl delete -f loadbalancer.yml
```


## Ingress

Ingress 需要Ingress控制器支持，先部署控制器

```bash
kubectl apply -f https://gitee.com/cnlxh/Kubernetes/raw/master/cka-yaml/ingressdeploy.yaml

```

```bash
kubectl get pod -n ingress-nginx
```

```bash
NAME                                        READY   STATUS      RESTARTS   AGE
NAME                                   READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-cv22n   0/1     Completed   0          92s
ingress-nginx-admission-patch-lbr2v    0/1     Completed   1          92s
ingress-nginx-controller-tdpb2         1/1     Running     0          92s
ingress-nginx-controller-w2q4g         1/1     Running     0          92s
```

用nginx镜像生成一个3副本的Pod，并通过Service提供服务，然后再用ingress，以特定域名的方式对外暴露

```bash
cat > ingress.yml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment-ingress
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: ingressservice
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: lixiaohui
spec:
  ingressClassName: nginx
  rules:
    - host: www.lixiaohui.com
      http:
        paths:
          - pathType: Prefix
            path: "/"
            backend:
              service:
                name: ingressservice
                port:
                  number: 80
EOF
```

```bash
kubectl create -f ingress.yml
kubectl get deployments,service,ingress
```

```bash
NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment-ingress   3/3     3            3           2m

NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
ingressservice   ClusterIP   10.110.117.37   <none>        80/TCP    2m7

NAME        CLASS   HOSTS               ADDRESS                         PORTS   AGE
lixiaohui   nginx   www.lixiaohui.com   192.168.8.4,192.168.8.5   80      2m26s
```

```bash
把上述ADDRESS部分的IP和域名绑定解析

echo 192.168.8.4 www.lixiaohui.com >> /etc/hosts

curl http://www.lixiaohui.com
```

```bash
kubectl delete -f ingress.yml
```

## Gateway API

### Gateway API 基本介绍

Kubernetes Gateway API 是一种新的 API 规范，旨在提供一种在 Kubernetes 中管理网关和负载均衡器的标准方法。它被设计为 Ingress API 的替代方案，提供更丰富的功能和更好的扩展性,Gateway API 的核心思想是通过使用可扩展的、角色导向的、协议感知的配置机制来提供网络服务。

核心组件：

Gateway API 包括几个核心组件：

1. `GatewayClass`：定义一组具有配置相同的网关，由实现该类的控制器管理。
2. `Gateway`：定义流量处理基础设施（例如云负载均衡器）的一个实例。
3. `Route`：描述了特定协议的规则，用于将请求从 Gateway 映射到 Kubernetes 服务。目前，HTTPRoute 是比较稳定的版本，而 TCPRoute、UDPRoute、GRPCRoute、TLSRoute 等也在开发中。

以下是使用 Gateway 和 HTTPRoute 将 HTTP 流量路由到服务的简单示例：

![](https://gitee.com/cnlxh/Kubernetes/raw/master/images/k8s-gatewayapi/gateway-request-flow.svg)

在此示例中，实现为反向代理的 Gateway 的请求数据流如下：

1. 客户端开始准备 URL 为 http://test.lixiaohui.com 的 HTTP 请求
2. 客户端的 DNS 解析器查询目标名称并了解与 Gateway 关联的一个或多个 IP 地址的映射。
3. 客户端向 Gateway IP 地址发送请求；反向代理接收 HTTP 请求并使用 Host: 标头来匹配基于 Gateway 和附加的 HTTPRoute 所获得的配置。
4. 可选的，反向代理可以根据 HTTPRoute 的匹配规则进行请求头和（或）路径匹配。
5. 可选地，反向代理可以修改请求；例如，根据 HTTPRoute 的过滤规则添加或删除标头。
6. 最后，反向代理将请求转发到一个或多个后端。

### Gateway API实验

1. 需要先做metallb，由metalb给istio控制器提供外部负载均衡IP
2. 部署istio，为GatewayAPI做后端流量处理组件
3. 创建一个基于istio的gatewayClass
4. 创建一个gateway，并监听在80端口，并关联刚创建的gatewayClass
5. 创建一个httpRoute，此处定义客户端访问的域名和路径

实验效果：

外部客户端可以用浏览器打开`http://test.lixiaohui.com` 并返回我们的nginx业务网站内容

**部署 Gateway API CRD**

这一步用于扩展K8S功能，以便于支持Gateway API
```bash
kubectl kustomize "https://gitee.com/cnlxh/gateway-api/config/crd?ref=v1.1.0" | kubectl apply -f -
```

**部署istio**

这一步部署的istio用于处理后端流量处理，istioctl是istio的部署工具

```bash
wget https://class-git.myk8s.cn/istio/istio/releases/download/1.23.2/istioctl-1.23.2-linux-amd64.tar.gz
tar xf istioctl-1.23.2-linux-amd64.tar.gz -C /usr/local/bin
```

下方的镜像set操作，是因为在中国无法访问镜像才需要做，如果可以访问国外镜像，这一步就不用，而resources的部分是因为我们的机器没那么高性能，将内存请求由2Gi改成了1Gi

```bash
kubectl create namespace istio-system
istioctl manifest generate --set profile=minimal > minimal.yaml
kubectl create -f minimal.yaml
kubectl set image deployment/istiod -n istio-system discovery=registry.cn-shanghai.aliyuncs.com/cnlxh/pilot:1.23.2
kubectl set resources deployment/istiod -n istio-system --requests=memory=1Gi
```

这里将会自动创建基于istio的GatewayClass

```bash
kubectl get gatewayclasses.gateway.networking.k8s.io

NAME           CONTROLLER                    ACCEPTED   AGE
istio          istio.io/gateway-controller   True       37m
istio-remote   istio.io/unmanaged-gateway    True       37m
```

部署应用，这里的应用是模拟公司的常规业务，稍后用于对外提供服务

```yaml
cat > deployment-service.yml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8sgateway-lxhtest
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
EOF
```

为了稳定pod的访问，这里用service的方式做了一个内部暴露

```bash
kubectl create -f deployment-service.yml
kubectl expose deployment k8sgateway-lxhtest --port=9000 --name=lxhservice --target-port=80
```

1. 创建一个名为lxh-gateway的gateway并关联了一个名为istio的gatewayClass，这个gateway提供了一个监听在80端口的http协议的监听器，这个监听器接收来自任何namespace以lixiaohui.com为后缀的所有请求。
2. 创建一个名为lxh-http的httpRoute，并关联我们的gateway，本次httpRoute提供了test.lixiaohui.com的域名根目录的请求入口，并将流量导入到一个名为lxhservice的9000端口

```yaml
cat > gatewayandhttproute.yml <<-EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: lxh-gateway
spec:
  gatewayClassName: istio
  listeners:
  - name: default
    hostname: "*.lixiaohui.com"
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: lxh-http
spec:
  parentRefs:
  - name: lxh-gateway
  hostnames: ["test.lixiaohui.com"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: lxhservice
      port: 9000
EOF
```

国内需要将镜像指向我的仓库，或者配置加速器，不然无法拉取镜像会导致deployment的pod无法启动

```bash
kubectl apply -f gatewayandhttproute.yml
kubectl set image deployment/lxh-gateway-istio istio-proxy=registry.cn-shanghai.aliyuncs.com/cnlxh/proxyv2:1.23.2
```

创建了上面的gateway之后，istio会自动创建一个对应的deployment和service用于代理我们的流量

```bash
kubectl get deployments.apps
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
lxh-gateway-istio              1/1     1            1           2m49s
```
可以看到，我们的gateway，已经从负载均衡中，拿到了外部IP地址

```bash
kubectl get service
NAME                 TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)                        AGE
lxh-gateway-istio   LoadBalancer   10.98.60.99     192.168.8.10   15021:31731/TCP,80:32282/TCP   3m59s
```

服务后端也有endpoint

```bash
kubectl get endpoints
NAME                ENDPOINTS                                          AGE
lxh-gateway-istio   172.16.126.8:80,172.16.126.8:15021                 5m2s
```

用以下方法来确认一下pod起来了没有

```bash
kubectl get pod -o wide

NAME                              READY   STATUS    RESTARTS        AGE     IP              NODE          NOMINATED NODE   READINESS GATES
lxh-gateway-istio-f9b44b6c-4528z  1/1     Running   0               117s    172.16.126.7    k8s-worker2   <none>           <none>
```

查看我们的gateway和httproute

```bash
kubectl get gateways.gateway.networking.k8s.io
NAME          CLASS   ADDRESS        PROGRAMMED   AGE
lxh-gateway   istio   192.168.8.10   True         7m30s

kubectl get httproutes.gateway.networking.k8s.io
NAME        HOSTNAMES                 AGE
lxh-http   ["test.lixiaohui.com"]   2m46s
```

访问测试

```bash
echo 192.168.8.10 test.lixiaohui.com >> /etc/hosts
curl http://test.lixiaohui.com
```

```text
<title>Welcome to nginx!</title>
```

# 健康检查

## Liveness Probes

### 文件存活检测

创建一个名为liveness的容器，并在其中执行文件的创建，休眠，然后再删除文件的操作，然后用livenessProbe来检测

```bash
cat > liveness.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-exec
spec:
  containers:
  - name: liveness
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
    imagePullPolicy: IfNotPresent
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
EOF
```

1.periodSeconds 字段指定了 kubelet 应该每 5 秒执行一次存活探测。

2.initialDelaySeconds 字段告诉 kubelet 在执行第一次探测前应该等待 5 秒。

3.kubelet 在容器内执行命令 cat /tmp/healthy 来进行探测。

4.如果命令执行成功并且返回值为 0，kubelet 就会认为这个容器是健康存活的。

5.如果这个命令返回非 0 值，kubelet 会杀死这个容器并重新启动它。

这个容器生命周期的前 30 秒， /tmp/healthy 文件是存在的。 所以在这最开始的 30 秒内，执行命令 cat /tmp/healthy 会返回成功代码。 30 秒之后，执行命令 cat /tmp/healthy 就会返回失败代码。

```bash
kubectl create -f liveness.yml 
kubectl describe pod liveness-exec
```

```bash
Events:
  Type     Reason     Age                  From               Message
  ----     ------     ----                 ----               -------
  Normal   Scheduled  3m16s                default-scheduler  Successfully assigned lixiaohui/liveness-exec to k8s-worker1
  Normal   Pulled     3m11s                kubelet            Successfully pulled image "busybox" in 3.821847462s
  Normal   Pulled     117s                 kubelet            Successfully pulled image "busybox" in 3.615149362s
  Normal   Pulling    45s (x3 over 3m15s)  kubelet            Pulling image "busybox"
  Normal   Created    43s (x3 over 3m11s)  kubelet            Created container liveness
  Normal   Started    43s (x3 over 3m11s)  kubelet            Started container liveness
  Normal   Pulled     43s                  kubelet            Successfully pulled image "busybox" in 2.73613205s
  Warning  Unhealthy  0s (x9 over 2m40s)   kubelet            Liveness probe failed: cat: can't open '/tmp/healthy': No such file or directory
  Normal   Killing    0s (x3 over 2m30s)   kubelet            Container liveness failed liveness probe, will be restarted
```

每30秒在pod事件中就会显示存活探测器失败了，下方信息显示这个容器被杀死并且被重建了3次

```bash
kubectl get pods
```

```bash
NAME            READY   STATUS    RESTARTS      AGE
liveness-exec   1/1     Running   3 (63s ago)   4m49s
```

```bash
kubectl delete -f liveness.yml
```

### HTTP存活检测

以httpget的形式访问容器中的/lixiaohui页面，根据返回代码来判断是否正常

```bash
cat > httpget.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: http
spec:
  containers:
  - name: httpd
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/httpd
    imagePullPolicy: IfNotPresent
    livenessProbe:
      httpGet:
        path: /lixiaohui
        port: 80
        httpHeaders:
        - name: Custom-Header
          value: Awesome
      initialDelaySeconds: 3
      periodSeconds: 3
  restartPolicy: OnFailure
EOF
```

1. kubelet 会向容器内运行的服务发送一个 HTTP GET 请求来执行探测。 如果服务器上 /lixiaohui路径下的处理程序返回成功代码，则 kubelet 认为容器是健康存活的。
2. 如果处理程序返回失败代码，则 kubelet 会杀死这个容器并且重新启动它。
3. 任何大于或等于 200 并且小于 400 的返回代码标示成功，其它返回代码都标示失败。

```bash
kubectl create -f httpget.yml 
kubectl get pods
```

```bash
NAME   READY   STATUS      RESTARTS   AGE
http   0/1     Completed   3          3m6s
```

```bash
kubectl describe pod http
```

```bash
Events:
  Type     Reason     Age                    From               Message
  ----     ------     ----                   ----               -------
  Normal   Scheduled  3m28s                  default-scheduler  Successfully assigned lixiaohui/http to k8s-worker1
  Normal   Pulled     3m23s                  kubelet            Successfully pulled image "httpd" in 4.365187879s
  Normal   Pulled     3m9s                   kubelet            Successfully pulled image "httpd" in 2.794325055s
  Normal   Created    2m54s (x3 over 3m23s)  kubelet            Created container httpd
  Normal   Started    2m54s (x3 over 3m23s)  kubelet            Started container httpd
  Normal   Pulled     2m54s                  kubelet            Successfully pulled image "httpd" in 2.497771235s
  Warning  Unhealthy  2m43s (x9 over 3m19s)  kubelet            Liveness probe failed: HTTP probe failed with statuscode: 404
  Normal   Killing    2m43s (x3 over 3m13s)  kubelet            Container httpd failed liveness probe, will be restarted
```

```bash
kubectl delete -f httpget.yml 
```

## ReadinessProbe

### TCP存活检测

kubelet 会在容器启动 5 秒后发送第一个就绪探测。 这会尝试连接容器的 800 端口。如果探测成功，这个 Pod 会被标记为就绪状态，kubelet 将继续每隔 10 秒运行一次检测。

除了就绪探测，这个配置包括了一个存活探测。 kubelet 会在容器启动 15 秒后进行第一次存活探测。 与就绪探测类似，会尝试连接 器的 800 端口。 如果存活探测失败，这个容器会被重新启动。

```bash
cat > readiness.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: tcpcheck
spec:
  containers:
  - name: httpd
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/httpd
    imagePullPolicy: IfNotPresent
    ports:
      - name: webport
        protocol: TCP
        containerPort: 80
    readinessProbe:
      tcpSocket:
        port: 800
      initialDelaySeconds: 5
      periodSeconds: 10
    livenessProbe:
      tcpSocket:
        port: 800
      initialDelaySeconds: 15
      periodSeconds: 20
  restartPolicy: OnFailure
EOF
```

```bash
kubectl create -f readiness.yml 
kubectl get pods
```

```bash
NAME       READY   STATUS    RESTARTS     AGE
tcpcheck   0/1     Running   1 (6s ago)   67s
```

```bash
kubectl describe pod tcpcheck
```

```bash
...
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  60s               default-scheduler  Successfully assigned lixiaohui/tcpcheck to k8s-worker1
  Normal   Pulling    60s               kubelet            Pulling image "httpd"
  Normal   Pulled     57s               kubelet            Successfully pulled image "httpd" in 2.730390747s
  Normal   Created    57s               kubelet            Created container httpd
  Normal   Started    57s               kubelet            Started container httpd
  Warning  Unhealthy  0s (x7 over 50s)  kubelet            Readiness probe failed: dial tcp 172.16.125.74:800: connect: connection refused
  Warning  Unhealthy  0s (x3 over 40s)  kubelet            Liveness probe failed: dial tcp 172.16.125.74:800: connect: connection refused
  Normal   Killing    0s                kubelet            Container httpd failed liveness probe, will be restarted
```

可以看到，我们的pod对外提供了80端口，但是我们一直在检测800端口，所以这个pod的检测是失败的

```bash
kubectl delete -f readiness.yml 
```

## StartupProbe

### 启动探测器

有时候，会有一些现有的应用程序在启动时需要较多的初始化时间。 要不影响对引起探测死锁的快速响应，这种情况下，设置存活探测参数是要技巧的。 技巧就是使用一个命令来设置启动探测，针对HTTP 或者 TCP 检测，可以通过设置 failureThreshold * periodSeconds 参数来保证有足够长的时间应对糟糕情况下的启动时间。
应用程序将会有最多 30秒(3 * 10 = 30s) 的时间来完成它的启动。 一旦启动探测成功一次，存活探测任务就会接管对容器的探测，对容器死锁可以快速响应。 如果启动探测一直没有成功，容器会在 30 秒后被杀死，并且根据 restartPolicy 来设置 Pod 状态。

```bash
cat > startup.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: startprobe
spec:
  containers:
  - name: httpd
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/httpd
    imagePullPolicy: IfNotPresent
    ports:
      - name: webport
        protocol: TCP
        containerPort: 80
    readinessProbe:
      tcpSocket:
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
    startupProbe:
      httpGet:
        path: /
        port: 800
      initialDelaySeconds: 5
      failureThreshold: 3
      periodSeconds: 10
  restartPolicy: OnFailure
EOF
```

Probe参数

Probe 有很多配置字段，可以使用这些字段精确的控制存活和就绪检测的行为：

1.initialDelaySeconds：容器启动后要等待多少秒后存活和就绪探测器才被初始化，默认是 0 秒，最小值是 0。

2.periodSeconds：执行探测的时间间隔（单位是秒）。默认是 10 秒。最小值是 1。

3.timeoutSeconds：探测的超时后等待多少秒。默认值是 1 秒。最小值是 1。

4.successThreshold：探测器在失败后，被视为成功的最小连续成功数。默认值是 1。 存活和启动探测的这个值必须是 1。最小值是 1。

5.failureThreshold：当探测失败时，Kubernetes 的重试次数。 存活探测情况下的放弃就意味着重新启动容器。 就绪探测情况下的放弃 Pod 会被打上未就绪的标签。默认值是 3。最小值是 1。

```bash
kubectl create -f startup.yml
kubectl describe -f startup.yml
```

```bash
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  24s               default-scheduler  Successfully assigned default/startprobe to k8s-worker2
  Normal   Pulled     23s               kubelet            Container image "httpd" already present on machine
  Normal   Created    23s               kubelet            Created container httpd
  Normal   Started    23s               kubelet            Started container httpd
  Warning  Unhealthy  3s (x2 over 13s)  kubelet            Startup probe failed: Get "http://192.168.20.20:800/": dial tcp 192.168.20.20:800: connect: connection refused
```

可以发现由于我们故意写成了800端口，检测失败，容器一直无法就绪

```bash
kubectl delete -f startup.yml
```

## Kubernetes 探针检测顺序与优先级

在 Kubernetes 中，`startupProbe`、`livenessProbe` 和 `readinessProbe` 是用于监控和管理容器健康状况的探针，每种探针在容器生命周期中的不同阶段发挥不同的作用。以下是这三种探针的检测顺序和优先级：

### 1. `startupProbe`

- **检测顺序**：`startupProbe` 是在容器启动时首先执行的探针。它用于判断应用是否已成功启动，并且只在启动期间运行。
- **优先级**：如果配置了 `startupProbe`，Kubernetes 会忽略 `livenessProbe` 和 `readinessProbe` 直到 `startupProbe` 成功。`startupProbe` 成功后，`livenessProbe` 和 `readinessProbe` 才会开始运行。
- **目的**：用于处理启动时间较长的应用程序，确保应用在完全启动之前不会因 `livenessProbe` 的失败而被重启。

### 2. `livenessProbe`

- **检测顺序**：在 `startupProbe` 成功之后，`livenessProbe` 开始执行。它定期检查容器是否处于健康状态。
- **优先级**：如果配置了 `startupProbe`，`livenessProbe` 只有在 `startupProbe` 成功之后才开始运行。如果未配置 `startupProbe`，`livenessProbe` 在容器启动后立即开始运行。
- **目的**：用于检测容器是否仍然处于健康状态。如果 `livenessProbe` 失败，Kubernetes 会重启该容器。

### 3. `readinessProbe`

- **检测顺序**：在 `startupProbe` 成功之后，`readinessProbe` 开始执行。它定期检查容器是否已准备好接收流量。
- **优先级**：如果配置了 `startupProbe`，`readinessProbe` 只有在 `startupProbe` 成功之后才开始运行。如果未配置 `startupProbe`，`readinessProbe` 在容器启动后立即开始运行。
- **目的**：用于判断容器是否可以接收请求。如果 `readinessProbe` 失败，容器将从服务的端点列表中移除，不再接收新的流量。

### 总结

- **顺序**：`startupProbe` -> `livenessProbe` -> `readinessProbe`
- **优先级**：
  - `startupProbe` 优先于其他两个探针。如果配置了 `startupProbe`，必须先通过 `startupProbe` 检测，`livenessProbe` 和 `readinessProbe` 才会启动。
  - `livenessProbe` 和 `readinessProbe` 在 `startupProbe` 成功后同时开始运行，没有严格的优先级区分，但它们的作用不同，`livenessProbe` 用于重启失败的容器，`readinessProbe` 用于控制流量。

## 优雅关闭

从 Kubernetes 1.22 开始，terminationGracePeriodSeconds 特性被开启，在杀死容器时，Pod停止获得新的流量。但在Pod中运行的容器不会受到影响。直到超时发生。可以在Pod级别或者容器下具体的探针级别设定，探针会优先和覆盖Pod级别

下面的例子中，容器将在收到结束需求是沉睡2分钟来代表业务的正常关闭，然后整个pod最多等待200秒，超过200秒，就会强制删除

```bash
cat > grace.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: httpgrace
spec:
  terminationGracePeriodSeconds: 200
  containers:
  - name: httpd
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/httpd
    imagePullPolicy: IfNotPresent
    ports:
      - name: webport
        protocol: TCP
        containerPort: 80
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh","-c","sleep 2m"]
  restartPolicy: OnFailure
EOF
```

```bash
kubectl create -f grace.yml 
kubectl get -f grace.yml
```

```bash
NAME   READY   STATUS    RESTARTS   AGE
httpgrace    1/1     Running   0          7s
```

```bash
kubectl delete -f grace.yml &
kubectl get pod
```

```bash
NAME                                        READY   STATUS        RESTARTS   AGE
httpgrace                                       1/1     Terminating   0          18s
```

# 配置存储卷

## emptyDir

当 Pod 分派到某个 Node 上时，emptyDir 卷会被创建，并且在 Pod 在该节点上运行期间，卷一直存在。 就像其名称表示的那样，卷最初是空的。 尽管 Pod 中的容器挂载 emptyDir 卷的路径可能相同也可能不同，这些容器都可以读写 emptyDir 卷中相同的文件。 当 Pod 因为某些原因被从节点上删除时，emptyDir 卷中的数据也会被永久删除。
容器崩溃并不会导致 Pod 被从节点上移除，因此容器崩溃期间 emptyDir 卷中的数据是安全的

```bash
cat > emptydir.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: emptydir
spec:
  containers:
  - image: registry.cn-shanghai.aliyuncs.com/cnlxh/httpd
    imagePullPolicy: IfNotPresent
    name: test-container
    volumeMounts:
    - mountPath: /cache
      name: cache-volume
  volumes:
  - name: cache-volume
    emptyDir:
      sizeLimit: 2G
EOF
```

此时sizeLimit要注意内容量的单位，如果是单位是M，那就是以1000为进制，如果是Mi就是1024进制

```bash
kubectl create -f emptydir.yml 
kubectl get -f emptydir.yml -o wide
```

```bash
NAME       READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
emptydir   1/1     Running   0          29s   172.16.200.228   k8s-worker1 <none>           <none>
```

```bash
# 根据上面的提示，在指定的机器上完成这个步骤
crictl ps | grep -i test-container
```

```bash
d27c066d7acc3       faed93b288591       2 minutes ago       Running             test-container            0                   6f045542048c9
```

```bash
crictl inspect d27c066d7acc3 | grep cache
```

```bash
        "containerPath": "/cache",
        "hostPath": "/var/lib/kubelet/pods/baa08250-5800-4828-a3cd-bfcd0789af37/volumes/kubernetes.io~empty-dir/cache-volume",
          "container_path": "/cache",
          "host_path": "/var/lib/kubelet/pods/baa08250-5800-4828-a3cd-bfcd0789af37/volumes/kubernetes.io~empty-dir/cache-volume"
          "destination": "/cache",
          "source": "/var/lib/kubelet/pods/baa08250-5800-4828-a3cd-bfcd0789af37/volumes/kubernetes.io~empty-dir/cache-volume",
```

可以看到我们的数据卷被创建到了/var/lib/kubelet/pods/baa08250-5800-4828-a3cd-bfcd0789af37/volumes/kubernetes.io~empty-dir/cache-volume

```bash
kubectl delete -f emptydir.yml
```

## HostPath

hostPath 卷能将主机节点文件系统上的文件或目录挂载到你的 Pod 中，但要注意的是要尽可能避免使用这个类型的卷，会限制pod的迁移性

下面的例子中，我们挂载了一个目录到容器中，并通过nginx对外展示其中的index.html

```bash
cat > hostpath.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hostpathtest
spec:
  containers:
  - image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
    imagePullPolicy: IfNotPresent
    name: hostpathpod
    ports:
      - name: web
        containerPort: 80
    volumeMounts:
    - mountPath: /usr/share/nginx/html
      name: test-volume
  volumes:
  - name: test-volume
    hostPath:
      path: /data
      type: DirectoryOrCreate
EOF
```

| **取值**            | **行为**                                                           |
| ----------------- | ---------------------------------------------------------------- |
|                   | 空字符串（默认）用于向后兼容，这意味着在安装 hostPath  卷之前不会执行任何检查。                    |
| DirectoryOrCreate | 如果在给定路径上什么都不存在，那么将根据需要创建空目录，权限设置为  0755，具有与 kubelet 相同的组和属主信息。   |
| Directory         | 在给定路径上必须存在的目录。                                                   |
| FileOrCreate      | 如果在给定路径上什么都不存在，那么将在那里根据需要创建空文件，权限设置为  0644，具有与 kubelet 相同的组和所有权。 |
| File              | 在给定路径上必须存在的文件。                                                   |
| Socket            | 在给定路径上必须存在的 UNIX  套接字。                                           |
| CharDevice        | 在给定路径上必须存在的字符设备。                                                 |
| BlockDevice       | 在给定路径上必须存在的块设备。                                                  |

```bash
kubectl create -f hostpath.yml 
kubectl get -f hostpath.yml -o wide
```

```bash
NAME           READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
hostpathtest   1/1     Running   0          3s    172.16.200.223   k8s-worker2   <none>           <none>
```

```bash
# 根据提示，在work02上完成这个步骤
echo hostwrite > /data/index.html

curl http://172.16.200.223
```

```bash
hostwrite
```

```bash
kubectl delete -f hostpath.yml
```

## 持久卷概述

持久卷（PersistentVolume，PV）是集群中的一块存储，可以由管理员事先供应，或者 使用存储类（Storage Class）来动态供应。 持久卷是集群资源，就像节点也是集群资源一样。PV 持久卷和普通的 Volume 一样，也是使用 卷插件来实现的，只是它们拥有独立于任何使用 PV 的 Pod 的生命周期
持久卷申请（PersistentVolumeClaim，PVC）表达的是用户对存储的请求。概念上与 Pod 类似。 Pod 会耗用节点资源，而 PVC 申领会耗用 PV 资源

## 构建简易NFS服务器

在master上模拟一个nfs服务器，将本地的/nfsshare共享出来给所有人使用

```bash
apt install nfs-kernel-server -y
mkdir /nfsshare
chmod 777 /nfsshare -R
echo /nfsshare *(rw) >> /etc/exports
systemctl enable nfs-server --now
exportfs -rav
```

## PV

创建一个名为nfspv大小为5Gi卷，并以ReadWriteOnce的方式申明，且策略为Recycle

```bash
cat > pv.yml <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfspv
  labels:
    pvname: nfspv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: slow
  mountOptions:
    - hard
    - nfsvers=4.1
  nfs:
    path: /nfsshare
    server: 192.168.8.3
EOF
```

Kubernetes 支持两种卷模式（volumeModes）：Filesystem（文件系统） 和 Block（块），volumeMode 属性设置为 Filesystem 的卷会被 Pod 挂载（Mount） 到某个目录。 如果卷的存储来自某块设备而该设备目前为空，Kuberneretes 会在第一次挂载卷之前 在设备上创建文件系统。

| 访问模式             | 描述                                                                              |
| ---------------- | ------------------------------------------------------------------------------- |
| ReadWriteOnce    | 卷可以被一个节点以读写方式挂载。 ReadWriteOnce 访问模式也允许运行在同一节点上的多个 Pod 访问卷。                      |
| ReadOnlyMany     | 卷可以被多个节点以只读方式挂载。                                                                |
| ReadWriteMany    | 卷可以被多个节点以读写方式挂载。                                                                |
| ReadWriteOncePod | 卷可以被单个 Pod 以读写方式挂载。 如果你想确保整个集群中只有一个 Pod 可以读取或写入该 PVC， 请使用ReadWriteOncePod 访问模式。 |

在创建pv前，需要确保在3个节点上都安装了nfs客户端
```bash
apt install nfs-common -y
```
```bash
kubectl create -f pv.yml 
kubectl get pv
```

```bash
NAME    CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
nfspv   5Gi        RWO            Recycle          Available           slow                    4s
```

| 回收策略    | 描述                                                                                                                                                  |
| ------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Retain  | 手动回收                                                                                                                                                |
| Recycle | 基本擦除 (rm -rf /thevolume/*)                                                                                                                          |
| Delete  | 诸如 AWS EBS、GCE PD、Azure Disk 或 OpenStack Cinder 卷这类关联存储资产也被删除，目前，仅 NFS 和 HostPath 支持回收（Recycle）。 AWS EBS、GCE PD、Azure Disk 和 Cinder 卷都支持删除（Delete）。 |

| PV卷状态         | 描述                      |
| ------------- | ----------------------- |
| Available（可用） | 卷是一个空闲资源，尚未绑定到任何申领；     |
| Bound（已绑定）    | 该卷已经绑定到某申领；             |
| Released（已释放） | 所绑定的申领已被删除，但是资源尚未被集群回收； |
| Failed（失败）    | 卷的自动回收操作失败。             |

## PVC

```bash
cat > pvc.yml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myclaim
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 1Gi
  storageClassName: slow
  selector:
    matchLabels:
      pvname: "nfspv"
EOF
```

```bash
kubectl create -f pvc.yml 
kubectl get pvc
```

```bash
NAME      STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
myclaim   Bound    nfspv    5Gi        RWO            slow           8s
```

| 参数          | 描述                                             |
| ----------- | ---------------------------------------------- |
| accessModes | 申领在请求具有特定访问模式的存储时，使用与卷相同的访问模式约定。               |
| volumeMode  | 申领使用与卷相同的约定来表明是将卷作为文件系统还是块设备来使用。               |
| resources   | 申领和 Pod 一样，也可以请求特定数量的资源。                       |
| selector    | 申领可以设置标签选择算符 来进一步过滤卷集合。只有标签与选择算符相匹配的卷能够绑定到申领上。 |

selector 参数选择：

matchLabels - 卷必须包含带有此值的标签
matchExpressions - 通过设定键（key）、值列表和操作符（operator） 来构造的需求。合法的操作符有 In、NotIn、Exists 和 DoesNotExist。
来自 matchLabels 和 matchExpressions 的所有需求都按逻辑与的方式组合在一起。 这些需求都必须被满足才被视为匹配。

## 使用PV和PVC

创建一个pod并尝试使用PVC

```bash
apt install nfs-common -y
cat > pvcuse.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  containers:
    - name: myfrontend
      image: registry.cn-shanghai.aliyuncs.com/cnlxh/httpd
      imagePullPolicy: IfNotPresent
      ports:
        - name: web
          containerPort: 80
      volumeMounts:
      - mountPath: "/usr/local/apache2/htdocs"
        name: mypd
  volumes:
    - name: mypd
      persistentVolumeClaim:
        claimName: myclaim
EOF
```

```bash
kubectl create -f pvcuse.yml 
kubectl get -f pvcuse.yml -o wide
```

```bash
NAME    READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
mypod   1/1     Running   0          8s    172.16.200.225   k8s-worker2   <none>           <none>
```

```bash
# 在NFS服务器上(192.168.8.3)创建出index.html网页

echo pvctest > /nfsshare/index.html

# 这里要看一下调度到哪个机器，这个机器必须执行apt install nfs-common -y

curl http://172.16.200.225
```

```bash
pvctest
```

```bash
kubectl delete -f pvcuse.yml
```

# 配置存储类

## NFS外部供应

### 下载外部供应代码

```bash
git clone https://gitee.com/cnlxh/nfs-subdir-external-provisioner.git
cd nfs-subdir-external-provisioner
```

本次采用default命名空间，如果需要别的命名空间，请执行以下替换

```bash
NS=$(kubectl config get-contexts|grep -e "^\*" |awk '{print $5}')
NAMESPACE=${NS:-default}
sed -i'' "s/namespace:.*/namespace: $NAMESPACE/g" ./deploy/rbac.yaml ./deploy/deployment.yaml
```

如果集群采用了RBAC，请授权一下

```bash
kubectl create -f deploy/rbac.yaml
```

### 配置NFS外部供应

根据实际情况在deploy/deployment中修改镜像、名称、nfs地址和挂载
```bash
kubectl create -f deploy/deployment.yaml
```

## 部署存储类

要支持nfs挂载，所有节点都需要安装nfs-common安装包

```bash
apt install nfs-common -y
```

```bash
cat > storageclassdeploy.yml <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
provisioner: cnlxh/nfs-storage
allowVolumeExpansion: true
parameters:
  pathPattern: "${.PVC.namespace}-${.PVC.name}"
  onDelete: delete
EOF
```

```bash
kubectl create -f storageclassdeploy.yml
```

## 标记默认存储类

```bash
kubectl get storageclass
```

```bash
NAME                   PROVISIONER         RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs-client           cnlxh/nfs-storage   Delete          Immediate           false                  22m
```

```bash
kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## 使用存储类

只需要在pvc.spec中执行storageClassName: nfs-client就可以了

```bash
kubectl create -f deploy/test-claim.yaml -f deploy/test-pod.yaml
```

打开test-pod.yaml就会发现，它向我们的pvc也就是nfs服务器写入了名为SUCCESS文件，在nfs服务器上执行：

```bash
ls /nfsshare/default-test-claim/
```

```bash
SUCCESS
```

删除pod和pvc，会删除我们的资源，测试一下，执行后，会删除pod、pvc、pv，再去nfs服务器查看，数据就没了

```bash
kubectl delete -f deploy/test-pod.yaml -f deploy/test-claim.yaml
```

# Pod调度

## nodeSelector

给k8s-worker2节点打一个标签name=lixiaohui

```bash
kubectl label nodes k8s-worker2 name=lixiaohui
```

如果需要删除标签可以用：

```bash
kubectl label nodes k8s-worker2 name-
```


将pod仅调度到具有name=lixiaohui标签的节点上

```bash
cat > assignpod.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cnlxhtest
spec:
  containers:
  - name: nginx
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
    imagePullPolicy: IfNotPresent
  nodeSelector:
    name: lixiaohui
EOF
```

```bash
kubectl create -f assignpod.yml 
kubectl get pod cnlxhtest -o wide
```

```bash
NAME        READY   STATUS    RESTARTS   AGE   IP               NODE               NOMINATED NODE   READINESS GATES
cnlxhtest   1/1     Running   0          10s   172.16.125.120   k8s-worker2   <none>           <none>
```

```bash
kubectl delete -f assignpod.yml
```

## nodeName

将Pod仅调度到具有特定名称的节点上，例如仅调度到k8s-worker1上

```bash
cat > nodename.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: lxhnodename
spec:
  containers:
  - name: nginx
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
    imagePullPolicy: IfNotPresent
  nodeName:
    k8s-worker1
EOF
```

```bash
kubectl create -f nodename.yml 
kubectl get pod lxhnodename -o wide
```

```bash
NAME          READY   STATUS    RESTARTS   AGE   IP             NODE               NOMINATED NODE   READINESS GATES
lxhnodename   1/1     Running   0          9s    172.16.127.5   k8s-worker1   <none>           <none>
```

```bash
kubectl delete -f nodename.yml
```

## tolerations

master节点默认不参与调度的原因就是因为其上有taint，而toleration就是容忍度

```bash
kubectl describe nodes k8s-master | grep -i taint
```
```text
node-role.kubernetes.io/control-plane:NoSchedule
```

添加一个磁盘类型为hdd就不调度的污点

```
kubectl taint node k8s-worker2 disktype=hdd:NoSchedule
```

如需删除以上污点，可用以下命令实现：

```
kubectl taint node k8s-worker2 disktype-
```

创建一个可以容忍具有master taint的pod

```bash
cat > tolerations.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: tolerations
spec:
  containers:
  - name: nginx
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
    imagePullPolicy: IfNotPresent
  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
EOF
```

```bash
kubectl create -f tolerations.yml 
kubectl get pod tolerations -o wide
```

```bash
NAME          READY   STATUS    RESTARTS   AGE   IP              NODE               NOMINATED NODE   READINESS GATES
tolerations   1/1     Running   0          7s    172.16.125.65   k8s-worker1   <none>           <none>
```

此时我们发现，并没有调度到k8s-master上，由此我们得出来一个结果，容忍不代表必须，如果必须要调度到k8s-master，需要用以下例子

```bash
cat > mustassign.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: tolerationsmust
spec:
  containers:
  - name: nginx
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
    imagePullPolicy: IfNotPresent
  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
  nodeSelector:
    node-role.kubernetes.io/control-plane: "" 
EOF
```

```bash
kubectl create -f mustassign.yml 
kubectl get -f mustassign.yml -o wide
```

```bash
NAME          READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
tolerations   1/1     Running   0          3s    172.16.119.16   k8s-master   <none>           <none>
```

```bash
kubectl delete -f tolerations.yml
kubectl delete -f mustassign.yml
```

## affinity

本实验展示在 Kubernetes 集群中，如何使用节点亲和性把 Kubernetes Pod 分配到特定节点

首先需要给节点打上一个合适的标签

```bash
kubectl label nodes k8s-worker2 disktype=ssd
```

查看节点是否具有标签

```bash
kubectl get nodes --show-labels | grep -i disktype
```

删除k8s-worker2上的污点，避免干扰

```bash
kubectl taint node k8s-worker2 disktype-
```

强制调度到具有特定标签的节点上

```bash
cat > required.yml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: require
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd            
  containers:
  - name: nginx
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
    imagePullPolicy: IfNotPresent
EOF
```

可以看到的确调度到了k8s-worker2

```bash
kubectl create -f required.yml
kubectl get -f required.yml -o wide
NAME      READY   STATUS    RESTARTS   AGE   IP             NODE          NOMINATED NODE   READINESS GATES
require   1/1     Running   0          57s   172.16.126.6   k8s-worker2   <none>           <none>

```

再来试试优先但不强制的调度

```bash
cat > preferred.yml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd          
  containers:
  - name: nginx
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
    imagePullPolicy: IfNotPresent
EOF
```

可以看到依旧被调度到k8s-worker2上

```bash
kubectl create -f preferred.yml
kubectl get -f preferred.yml -o wide
NAME    READY   STATUS    RESTARTS   AGE   IP             NODE          NOMINATED NODE   READINESS GATES
nginx   1/1     Running   0          10s   172.16.126.7   k8s-worker2   <none>           <none>
```

你可以测试一下把k8s-worker2机器关机，再从yaml中把pod改个名防止冲突，在关机后重新创建，会看到也可以调度到其他节点

# ConfigMaps

## YAML文件创建

在Data节点创建了一些键值

```bash
cat > cmyaml.yml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: game-demo
data:
  player_initial_lives: "3"
  ui_properties_file_name: "lixiaohui"
  game.properties: |
    enemy.types=aliens,monsters
    player.maximum-lives=5
EOF
```

```bash
kubectl create -f cmyaml.yml 
kubectl get configmaps 
```

```bash
NAME               DATA   AGE
game-demo          3      18s
kube-root-ca.crt   1      49d
```

```bash
kubectl describe configmaps game-demo 
```

```bash
Name:         game-demo
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
game.properties:
----
enemy.types=aliens,monsters
player.maximum-lives=5

player_initial_lives:
----
3
ui_properties_file_name:
----
lixiaohui

BinaryData
====

Events:  <none>
```

## 命令行创建

创建了一个名为lixiaohui的键值

```bash
kubectl create configmap lixiaohui  --from-literal=username=lixiaohui  --from-literal=age=18
kubectl describe configmaps lixiaohui 
```

```bash
Name:         lixiaohui
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
age:
----
18
username:
----
lixiaohui

BinaryData
====

Events:  <none>
```

创建了一个index.html文件，然后用--from-file来引用

```bash
echo hello world > index.html
kubectl create configmap indexcontent --from-file=index.html
kubectl describe configmaps indexcontent 
```

```bash
Name:         indexcontent
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
index.html:
----
hello world


BinaryData
====

Events:  <none>
```

## Volume 挂载ConfigMap

创建一个Pod，其挂载的内容，将来自于我们的configmap

```bash
cat > cmvolume.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: configmapvolume
  labels:
    app: configmaptest
spec:
  containers:
    - name: test
      image: registry.cn-shanghai.aliyuncs.com/cnlxh/httpd
      imagePullPolicy: IfNotPresent
      volumeMounts:
        - name: index
          mountPath: /usr/local/apache2/htdocs
  volumes:
    - name: index
      configMap:
        name: indexcontent
EOF
```

```bash
kubectl create -f cmvolume.yml 
kubectl get -f cmvolume.yml -o wide
```

```bash
NAME              READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
configmapvolume   1/1     Running   0          63s   172.16.200.237   k8s-worker1 <none>           <none>
```

```bash
curl http://172.16.200.237
hello world
```

```bash
kubectl delete -f cmvolume.yml 
```

## 环境变量ConfigMap

创建一个名为mysqlpass且包含password=ABCabc123的configmap

```bash
kubectl create configmap mysqlpass --from-literal=password=ABCabc123
```

```bash
cat > cmenv.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mysql
spec:
  containers:
    - name: mysqlname
      image: registry.cn-shanghai.aliyuncs.com/cnlxh/mysql
      imagePullPolicy: IfNotPresent
      env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: mysqlpass
              key: password
EOF
```

我们用环境变量的方法引用了configmap

```bash
kubectl create -f cmenv.yml 
kubectl exec -it mysql -- mysql -uroot -pABCabc123
```

```bash
mysql: [Warning] Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 9
Server version: 8.0.28 MySQL Community Server - GPL

Copyright (c) 2000, 2022, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> exit
Bye
```

此时我们要注意，用configMap来引用密码是不太靠谱的，通常用于配置文件等明文场景，密文应该使用下一个实验的secret，因为configMap是明文的，见如下示例

```bash
kubectl describe configmaps mysqlpass 
```

```bash
Name:         mysqlpass
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
password:
----
ABCabc123

BinaryData
====

Events:  <none>
```

```bash
kubectl delete -f cmenv.yml 
```

# Secrets

刚才我们说过，用configMaps不方便存储密码类的敏感信息，此时我们可以改用Secret

## 命令行创建

```bash
kubectl create secret generic mysqlpass --from-literal=password=ABCabc123
```

查看时，会发现已经加密

```bash
kubectl describe secrets mysqlpass 
```

```bash
Name:         mysqlpass
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
password:  9 bytes
```

## 环境变量Secret

使用刚才创建的密码，创建Pod并进行尝试

```bash
cat > stenv.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mysql-secret
spec:
  containers:
    - name: mysqlname
      image: registry.cn-shanghai.aliyuncs.com/cnlxh/mysql
      imagePullPolicy: IfNotPresent
      env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysqlpass
              key: password
EOF
```

```bash
kubectl create -f stenv.yml 
```

```bash
kubectl exec -it mysql-secret -- mysql -uroot -pABCabc123
```

```bash
mysql: [Warning] Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 8
Server version: 8.0.28 MySQL Community Server - GPL

Copyright (c) 2000, 2022, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> exit;
Bye
```

```bash
kubectl delete -f stenv.yml 
```

# 资源配额

## Pod 资源配额

内存申请64Mi，CPU申请100m，上限为内存128Mi，CPU100m

```bash
cat > quota.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  labels:
    name: frontend
spec:
  containers:
  - name: app
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
    imagePullPolicy: IfNotPresent
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "100m"
EOF
```

1个逻辑CPU等于1000m，如果不带单位就是核心数，可以带小数点，例如0.1。
内存的单位：100M等于100 \* 1000，100Mi等于100 \* 1024

```bash
kubectl create -f quota.yml
kubectl describe -f quota.yml | grep -A 5 Limits
```

```bash
    Limits:
      cpu:     100m
      memory:  128Mi
    Requests:
      cpu:        100m
      memory:     64Mi
```

```bash
kubectl delete -f quota.yml
```

## NameSpace 资源配额

新建namespace

```bash
kubectl create namespace test
```
在ResourceQuota中，requests.cpu: "1" 就代表1000m，requests.memory后面，如果只是一个数字，没有Mi等单位时，默认使用的是字节单位

```bash
cat > nmquota.yml <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: lixiaohuiquota
  namespace: test
spec:
  hard:
    pods: "1"
    requests.cpu: "1"
    requests.memory: "1"
    limits.cpu: "2"
    limits.memory: "2Gi"
EOF
```

```bash
kubectl create -f nmquota.yml 
```

新建一个Pod尝试申请资源

```bash
cat > nmpod.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: test
spec:
  containers:
  - name: app
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
    imagePullPolicy: IfNotPresent
    resources:
      requests:
        memory: "64Mi"
        cpu: "15000m"
      limits:
        memory: "128Mi"
        cpu: "15000m"
EOF
```

我们发现由于限制无法申请成功

```bash
kubectl create -f nmpod.yml 
```

```bash
Error from server (Forbidden): error when creating "nmpod.yml": pods "frontend" is forbidden: exceeded quota: lixiaohuiquota, requested: limits.cpu=15,requests.cpu=15,requests.memory=64Mi, used: limits.cpu=0,requests.cpu=0,requests.memory=0, limited: limits.cpu=2,requests.cpu=1,requests.memory=1
```

# 访问控制

## ServiceAaccount

在一个名为test的namespace中，创建一个名为lixiaohui的ServiceAccount

```bash
kubectl create namespace test
kubectl -n test create serviceaccount lixiaohui
kubectl -n test get serviceaccounts lixiaohui
```

```bash
NAME        SECRETS   AGE
lixiaohui   0         63s
```

```bash
kubectl -n test describe serviceaccounts lixiaohui
```

```bash
Name:                lixiaohui
Namespace:           test
Labels:              <none>
Annotations:         <none>
Image pull secrets:  <none>
Mountable secrets:   <none>
Tokens:              <none>
Events:              <none>
```

## Role和ClusterRole

在名为test的namespace中创建一个名为test-role的角色，以及创建一个名为test-clusterrole的集群角色

创建一个名为test-role仅有查看pod的角色

命令行方法

```bash
kubectl -n test create role --resource=pod --verb=get test-role
```

```bash
kubectl -n test delete role test-role
```

YAML 方法

```bash
cat > role.yml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: test-role
  namespace: test
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
EOF
```

```bash
kubectl create -f role.yml
kubectl describe role -n test test-role
```

```bash
Name:         test-role
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
  pods       []                 []              [get]
```

将上述创建的lixiaohui服务账号和本role绑定

```bash
kubectl -n test create rolebinding --role=test-role --serviceaccount=test:lixiaohui lixiaohui-binding
kubectl -n test describe rolebinding lixiaohui-binding
```

```bash
Name:         lixiaohui-binding
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  Role
  Name:  test-role
Subjects:
  Kind            Name       Namespace
  ----            ----       ---------
  ServiceAccount  lixiaohui  test
```

测试权限

```bash
kubectl -n test auth can-i create pods --as=system:serviceaccount:test:lixiaohui
no
kubectl -n test auth can-i get pods --as=system:serviceaccount:test:lixiaohui
yes
```

ClusterRole

创建一个名为test-clusterrole仅有创建pod和deployment的角色

命令行创建

```bash
kubectl create clusterrole --resource=pod,deployment --verb=create test-clusterrole
kubectl describe clusterrole test-clusterrole
```

```bash
Name:         test-clusterrole
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources         Non-Resource URLs  Resource Names  Verbs
  ---------         -----------------  --------------  -----
  pods              []                 []              [create get]
  deployments.apps  []                 []              [create get]
```

```bash
kubectl delete clusterrole test-clusterrole
```

YAML 文件创建

```bash
cat > clusterrole.yml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: test-clusterrole
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - create
  - get
- apiGroups:
  - apps
  resources:
  - deployments
  verbs:
  - create
  - get
EOF
```

```bash
kubectl create -f clusterrole.yml
kubectl describe clusterrole test-clusterrole
```

```bash
Name:         test-clusterrole
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources         Non-Resource URLs  Resource Names  Verbs
  ---------         -----------------  --------------  -----
  pods              []                 []              [create get]
  deployments.apps  []                 []              [create get]
```

将lixiaohui用户和clusterrole绑定，并测试权限

```bash
kubectl create clusterrolebinding --clusterrole=test-clusterrole --serviceaccount=test:lixiaohui lixiaohui-clusterbind
kubectl describe clusterrolebinding lixiaohui-clusterbind
```

```bash
Name:         lixiaohui-clusterbind
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  ClusterRole
  Name:  test-clusterrole
Subjects:
  Kind            Name       Namespace
  ----            ----       ---------
  ServiceAccount  lixiaohui  test
```

```bash
kubectl auth can-i get pods --as=system:serviceaccount:test:lixiaohui
yes

kubectl auth can-i create pods --as=system:serviceaccount:test:lixiaohui
yes

kubectl auth can-i create deployments --as=system:serviceaccount:test:lixiaohui
yes

kubectl auth can-i create secret --as=system:serviceaccount:test:lixiaohui
no

kubectl auth can-i create service --as=system:serviceaccount:test:lixiaohui
no
```

## 网络策略

在名为zhangsan的namespace中，创建一个仅允许来自名为lixiaohui的namespace连接的网络策略

创建两个namesapce

```bash
kubectl create namespace zhangsan
kubectl create namespace lixiaohui
```

在zhangsan的namespace中，新建一个pod

```bash
cat > nppod.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod
  namespace: zhangsan
  labels:
    app: httpd
spec:
  containers:
  - name: httpd
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/httpd
    ports:
      - name: web
        containerPort: 80
  restartPolicy: OnFailure
EOF
```

```bash
kubectl create -f nppod.yml
kubectl get pod -n zhangsan  -o wide
```

```bash
NAME   READY   STATUS    RESTARTS   AGE   IP              NODE               NOMINATED NODE   READINESS GATES
pod    1/1     Running   0          83s   172.16.152.73   k8s-worker2        <none>           <none>
```

在lixiaohui的namespace中，新建一个pod

```bash
cat > nppod1.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod1
  namespace: lixiaohui
  labels:
    app: nginx
spec:
  containers:
  - name: httpd
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/httpd
    ports:
      - name: web
        containerPort: 80
  restartPolicy: OnFailure
EOF
```

```bash
kubectl create -f nppod1.yml
kubectl get pod -n lixiaohui -o wide
```

```bash
NAME   READY   STATUS    RESTARTS   AGE   IP              NODE               NOMINATED NODE   READINESS GATES
pod1   1/1     Running   0          14s   172.16.152.74   k8s-worker2          <none>           <none>
```

新建网络策略

```bash
cat > np.yml <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-namesapce-lixiaohui
  namespace: zhangsan
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: lixiaohui
    ports:
    - protocol: TCP
      port: 80
EOF
```

```bash
kubectl create -f np.yml
```

测试效果

```bash
cat > nptest.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-default
spec:
  containers:
  - name: busybox
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
    command:
      - /bin/sh
      - -c
      - "sleep 10m"
  restartPolicy: OnFailure
EOF
kubectl create -f nptest.yml
```

从default namespace中访问没有被网络策略选中的pod，发现成功访问

```bash
kubectl exec -it pod-default -- wget 172.16.152.74
```

```bash
Connecting to 172.16.152.74 (172.16.152.74:80)
saving to 'index.html'
index.html           100% |********************************|    45  0:00:00 ETA
'index.html' saved
```

从default namespace中访问被网络策略选中的pod，发现无法访问

```bash
kubectl exec -it pod-default -- wget 172.16.152.73
```

```bash
Connecting to 172.16.152.73 (172.16.152.73:80)
```
新建一个lixiaohui namespace的pod，测试是否可以访问被隔离的pod，由于网络策略的原因，一定是可以访问的

```bash
cat > nplixiaohuitest.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-lixiaohui-test
  namespace: lixiaohui
spec:
  containers:
  - name: busybox
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
    command:
      - /bin/sh
      - -c
      - "sleep 10m"
  restartPolicy: OnFailure
EOF
kubectl create -f nplixiaohuitest.yml
```

以下测试中，发现可以正常访问zhangsan namesapce中的pod
```bash
kubectl -n lixiaohui exec -it pod-lixiaohui-test -- wget 172.16.152.73
```

```bash
saving to 'index.html'
index.html           100% |********************************|    45  0:00:00 ETA
'index.html' saved
```

# 监控与升级

## 部署Metrics

```bash
kubectl apply -f https://gitee.com/cnlxh/Kubernetes/raw/master/cka-yaml/metrics-components.yaml
```

部署好之后，执行kubectl top 命令时就会返回结果了

```bash
kubectl top nodes
```

```bash
NAME                    CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
k8s-master              142m         3%     1725Mi          45%       
k8s-worker1             150m         3%     1024Mi          27%       
k8s-worker2             53m          1%     995Mi           26%       
```

```bash
kubectl top pod
```

```bash
NAME                               CPU(cores)   MEMORY(bytes)   
lixiaohui-mq4sp                    0m           0Mi             
lixiaohui-qjlwt                    0m           0Mi             
lixiaohui-sm6pp                    0m           0Mi             
```

## 部署Prometheus

手工部署较为复杂，我们采用operator进行部署，先克隆它的operator，本次采用的是0.14.0版本

```bash
wget https://gitee.com/cnlxh/Kubernetes/raw/master/files/kube-prometheus-0.14.0.tar
tar xf kube-prometheus-0.14.0.tar
cd kube-prometheus-0.14.0
kubectl create -f manifests/setup/
```

测试是否符合条件，如果上一步全部成功，这里会显示全部符合

```bash
kubectl wait --for condition=Established --all CustomResourceDefinition --namespace=monitoring
```

在master上自动给所有节点准备容器镜像，此处会产生大量网络流量，需要较长时间，请耐心等待

```bash
cat > dockerimage <<'EOF'
#!/bin/bash

function sshcmd {
  sshpass -p vagrant ssh root@$1 $2
}

echo
echo Pulling images on $(hostname)
echo

docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/alertmanager:v0.27.0
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/blackbox-exporter:v0.25.0
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/configmap-reload:v0.13.1
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/kube-rbac-proxy:v0.18.1
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/grafana:11.2.0
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/kube-state-metrics:v2.13.0
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/node-exporter:v1.8.2
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus-adapter:v0.12.0
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus-operator:v0.76.2
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus:v2.54.1

docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/alertmanager:v0.27.0 quay.io/prometheus/alertmanager:v0.27.0
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/blackbox-exporter:v0.25.0 quay.io/prometheus/blackbox-exporter:v0.25.0
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/configmap-reload:v0.13.1 ghcr.io/jimmidyson/configmap-reload:v0.13.1
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/kube-rbac-proxy:v0.18.1 quay.io/brancz/kube-rbac-proxy:v0.18.1
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/grafana:11.2.0 grafana/grafana:11.2.0
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/kube-state-metrics:v2.13.0 registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.13.0
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/node-exporter:v1.8.2 quay.io/prometheus/node-exporter:v1.8.2
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus-adapter:v0.12.0 registry.k8s.io/prometheus-adapter/prometheus-adapter:v0.12.0
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus-operator:v0.76.2 quay.io/prometheus-operator/prometheus-operator:v0.76.2
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus:v2.54.1 quay.io/prometheus/prometheus:v2.54.1

docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/alertmanager:v0.27.0
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/blackbox-exporter:v0.25.0
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/configmap-reload:v0.13.1
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/kube-rbac-proxy:v0.18.1
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/grafana:11.2.0
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/kube-state-metrics:v2.13.0
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/node-exporter:v1.8.2
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus-adapter:v0.12.0
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus-operator:v0.76.2
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus:v2.54.1

echo
echo Saving images to file
echo

docker save -o alertmanager.tar quay.io/prometheus/alertmanager:v0.27.0
docker save -o blackbox-exporter.tar quay.io/prometheus/blackbox-exporter:v0.25.0
docker save -o configmap-reload.tar ghcr.io/jimmidyson/configmap-reload:v0.13.1
docker save -o kube-rbac-proxy.tar quay.io/brancz/kube-rbac-proxy:v0.18.1
docker save -o grafana.tar grafana/grafana:11.2.0
docker save -o kube-state-metrics.tar registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.13.0
docker save -o node-exporter.tar quay.io/prometheus/node-exporter:v1.8.2
docker save -o prometheus-adapter.tar registry.k8s.io/prometheus-adapter/prometheus-adapter:v0.12.0
docker save -o prometheus-operator.tar quay.io/prometheus-operator/prometheus-operator:v0.76.2
docker save -o prometheus.tar quay.io/prometheus/prometheus:v2.54.1

echo
echo Copying images file to k8s-worker1 and import it
echo

scp alertmanager.tar root@k8s-worker1:/root
scp blackbox-exporter.tar root@k8s-worker1:/root
scp configmap-reload.tar root@k8s-worker1:/root
scp kube-rbac-proxy.tar root@k8s-worker1:/root
scp grafana.tar root@k8s-worker1:/root
scp kube-state-metrics.tar root@k8s-worker1:/root
scp node-exporter.tar root@k8s-worker1:/root
scp prometheus-adapter.tar root@k8s-worker1:/root
scp prometheus-operator.tar root@k8s-worker1:/root
scp prometheus.tar root@k8s-worker1:/root

sshcmd k8s-worker1 'docker load -i /root/alertmanager.tar'
sshcmd k8s-worker1 'docker load -i /root/blackbox-exporter.tar'
sshcmd k8s-worker1 'docker load -i /root/configmap-reload.tar'
sshcmd k8s-worker1 'docker load -i /root/kube-rbac-proxy.tar'
sshcmd k8s-worker1 'docker load -i /root/grafana.tar'
sshcmd k8s-worker1 'docker load -i /root/kube-state-metrics.tar'
sshcmd k8s-worker1 'docker load -i /root/node-exporter.tar'
sshcmd k8s-worker1 'docker load -i /root/prometheus-adapter.tar'
sshcmd k8s-worker1 'docker load -i /root/prometheus-operator.tar'
sshcmd k8s-worker1 'docker load -i /root/prometheus.tar'

echo
echo Copying images file to k8s-worker2 and import it
echo

scp alertmanager.tar root@k8s-worker2:/root
scp blackbox-exporter.tar root@k8s-worker2:/root
scp configmap-reload.tar root@k8s-worker2:/root
scp kube-rbac-proxy.tar root@k8s-worker2:/root
scp grafana.tar root@k8s-worker2:/root
scp kube-state-metrics.tar root@k8s-worker2:/root
scp node-exporter.tar root@k8s-worker2:/root
scp prometheus-adapter.tar root@k8s-worker2:/root
scp prometheus-operator.tar root@k8s-worker2:/root
scp prometheus.tar root@k8s-worker2:/root

sshcmd k8s-worker2 'docker load -i /root/alertmanager.tar'
sshcmd k8s-worker2 'docker load -i /root/blackbox-exporter.tar'
sshcmd k8s-worker2 'docker load -i /root/configmap-reload.tar'
sshcmd k8s-worker2 'docker load -i /root/kube-rbac-proxy.tar'
sshcmd k8s-worker2 'docker load -i /root/grafana.tar'
sshcmd k8s-worker2 'docker load -i /root/kube-state-metrics.tar'
sshcmd k8s-worker2 'docker load -i /root/node-exporter.tar'
sshcmd k8s-worker2 'docker load -i /root/prometheus-adapter.tar'
sshcmd k8s-worker2 'docker load -i /root/prometheus-operator.tar'
sshcmd k8s-worker2 'docker load -i /root/prometheus.tar'

EOF

bash dockerimage

```

默认情况下，grafana等各个组件都提供了网络策略，无法被外部访问，我们先删除grafana的策略，并修改它的服务暴露方式为NodePort，因为我们要从外部访问它的图表面板

```bash
rm -rf manifests/grafana-networkPolicy.yaml
sed -i '/spec:/a\  type: NodePort' manifests/grafana-service.yaml
sed -i '/targetPort/a\    nodePort: 32000' manifests/grafana-service.yaml
sed -i '/        image: /a\        imagePullPolicy: IfNotPresent' manifests/nodeExporter-daemonset.yaml
sed -i '/        image: /a\        imagePullPolicy: IfNotPresent' manifests/blackboxExporter-deployment.yaml
sed -i '/        image: /a\        imagePullPolicy: IfNotPresent' manifests/grafana-deployment.yaml
sed -i '/        image: /a\        imagePullPolicy: IfNotPresent' manifests/kubeStateMetrics-deployment.yaml
sed -i '/        image: /a\        imagePullPolicy: IfNotPresent' manifests/prometheusAdapter-deployment.yaml
sed -i '/        image: /a\        imagePullPolicy: IfNotPresent' manifests/prometheusOperator-deployment.yaml
sed -i '/        image: /a\        imagePullPolicy: IfNotPresent' manifests/alertmanager-alertmanager.yaml
sed -i '/        image: /a\        imagePullPolicy: IfNotPresent' manifests/prometheus-prometheus.yaml

kubectl apply -f manifests/
```

确定grafana已经定义了32000端口，直接在浏览器打开任意节点的IP地址访问

```bash
kubectl get service -n monitoring grafana
```

```bash
NAME      TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
grafana   NodePort   10.99.168.64   <none>        3000:32000/TCP   30m
```

配置好解析后，在浏览器中打开http://k8s-worker1:32000，或者不配置解析用IP也可以

用户名和密码都是admin，点击login之后会让你修改新密码，进行修改后点击submit或直接点击skip不修改

![](https://gitee.com/cnlxh/Kubernetes/raw/master/images/Prometheus/grafana-login.png)

点击左侧或右上角的+号，选择import导入k8s模板

![](https://gitee.com/cnlxh/Kubernetes/raw/master/images/Prometheus/grafana-index.png)

点击 [模板链接]([Dashboards | Grafana Labs](https://grafana.com/grafana/dashboards/)) 选一个模板，把ID填进来，点击load即可

category选择Docker，Data Source选择Prometheus可以更好的筛选
![](https://gitee.com/cnlxh/Kubernetes/raw/master/images/Prometheus/grafana-template.png)

自己可以挑选喜欢的模板，点击进去可以看到图示，选好之后点击Copy ID，填到我们的系统中即可

![](https://gitee.com/cnlxh/Kubernetes/raw/master/images/Prometheus/grafana-template-id.png)

填好ID之后，点击ID后侧的load按钮进行加载，在最下侧的Prometheus处，选择Prometheus，然后点击import

![](https://gitee.com/cnlxh/Kubernetes/raw/master/images/Prometheus/grafana-template-import.png)

![](https://gitee.com/cnlxh/Kubernetes/raw/master/images/Prometheus/grafana-monitor.png)

## 升级控制平面

先确定要升级的版本

```bash
apt update
apt list kubeadm -a
```

这里的升级以具体课程时的版本为准，只需要参考步骤

```bash
kubeadm/unknown 1.31.1-1.1 amd64 [upgradable from: 1.31.0-1.1]
kubeadm/unknown,now 1.31.0-1.1 amd64 [installed,upgradable to: 1.31.1-1.1]
```

在上一步可以看到一个可用的列表，假设我们要升级的目标为1.31.1-1.1的版本

禁止Master节点接收新调度

```bash
kubectl cordon k8s-master
kubectl get nodes
```

```bash
NAME          STATUS                     ROLES           AGE     VERSION
k8s-master    Ready,SchedulingDisabled   control-plane   119d   v1.31.0
k8s-worker1   Ready                      worker          119d   v1.31.0
k8s-worker2   Ready                      worker          119d   v1.31.0
```

驱逐Master节点上的现有任务

```bash
kubectl drain k8s-master --ignore-daemonsets --delete-emptydir-data
```

```bash
node/k8s-master already cordoned
Warning: ignoring DaemonSet-managed Pods: kube-system/calico-node-gd44x, kube-system/kube-proxy-zxxgg, monitoring/node-exporter-x7h7l
evicting pod kube-system/coredns-7c445c467-prx7f
evicting pod kube-system/calico-kube-controllers-5b9b456c66-mf6r4
evicting pod kube-system/coredns-7c445c467-k6njz
pod/calico-kube-controllers-5b9b456c66-mf6r4 evicted
pod/coredns-7c445c467-prx7f evicted
pod/coredns-7c445c467-k6njz evicted
node/k8s-master drained
```

安装目标的kubeadm、kubelet、kubectl

```bash
apt-get update
apt-get install -y kubelet=1.31.1-1.1 kubeadm=1.31.1-1.1 kubectl=1.31.1-1.1
```

查看可升级的列表并升级

```bash
kubeadm upgrade plan
kubeadm upgrade apply v1.31.1 --etcd-upgrade=false
```

```bash
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.31.1"
[upgrade/versions] Cluster version: v1.31.0
[upgrade/versions] kubeadm version: v1.31.1
[upgrade] Are you sure you want to proceed? [y/N]: y

[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.31.1". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.

```

恢复Master节点的调度能力

```bash
systemctl restart kubelet
kubectl uncordon k8s-master
kubectl get nodes
```

```bash
NAME          STATUS   ROLES           AGE    VERSION
k8s-master    Ready    control-plane   119d   v1.31.1
k8s-worker1   Ready    worker          119d   v1.31.0
k8s-worker2   Ready    worker          119d   v1.31.0
```

# Helm 部署实践

官方网址 http://helm.sh

## Helm安装

下载安装Helm

```bash
wget https://get.helm.sh/helm-v3.16.1-linux-amd64.tar.gz
tar xf helm-v3.16.1-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm

```

默认情况下，helm内置了一个hub，用于软件搜索和安装，搜索软件是否可被安装，用以下格式命令：

```bash
helm search hub Packages
```

命令行显示有点奇怪，也不够丰富，可以考虑用浏览器打开搜索：https://hub.helm.sh

## 添加仓库

官方仓库网速慢，可以考虑一下以下仓库

```textile
http://mirror.azure.cn/kubernetes/charts/
https://apphub.aliyuncs.com/
```

添加方式

```bash
helm repo add azurerepo http://mirror.azure.cn/kubernetes/charts/
```

## Helm 安装wordpress

本次安装一个wordpress

```bash
helm search repo wordpress
```

```bash
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
azurerepo/wordpress     9.0.3           5.3.2           DEPRECATED Web publishing platform for building...
```

安装

这一步将安装mariadb和wordpress，我们这里用的是存储章节设置的默认存储类，所以会自动创建pv以及pvc，你要是还没有默认存储类，往上翻，重新做一下存储类并标记为默认即可

```bash
helm install wordpress azurerepo/wordpress
```

查询服务端口

```bash
kubectl get service
```

```bash
NAME                TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
wordpress           LoadBalancer   10.102.156.226   <pending>     80:31194/TCP,443:30386/TCP   3m42s
wordpress-mariadb   ClusterIP      10.106.8.85      <none>        3306/TCP                     3m42s
```

查询pod所在节点

```bash
root@k8s-master:~# kubectl get pod -o wide
```

```bash
NAME                                      READY   STATUS      RESTARTS   AGE    IP               NODE          NOMINATED NODE   READINESS GATES
nfs-client-provisioner-598cf75b45-kflwb   1/1     Running     0          133m   172.16.200.248   k8s-master    <none>           <none>
pod-default                               0/1     Completed   0          82m    172.16.93.198    k8s-worker1   <none>           <none>
wordpress-78d6fd4d6b-jt4pp                1/1     Running     0          107s   172.16.93.201    k8s-worker1   <none>           <none>
wordpress-mariadb-0                       1/1     Running     0          107s   172.16.245.6     k8s-worker2   <none>           <none>
```
可以看到wordpress在k8s-worker1上，直接打开浏览器，访问31194或30386端口都可以，例如:

```bash
http://k8s-worker1:31194
```


用户名：user
密码需要提取secret

```bash
root@k8s-master:~# kubectl get secrets wordpress -o yaml
apiVersion: v1
data:
  wordpress-password: YkRWc21jcmFLbA==
kind: Secret

```
我本次的密码是随机字符串：bDVsmcraKl
```bash
root@k8s-master:~# echo YkRWc21jcmFLbA== | base64 --decode
bDVsmcraKl
```

## Helm 安装k8s Dashboard

**这是可选实验，不管你这个实验做的怎么样，为了安全，都不要在任何生产环境中使用dashboard**

下载dashboard的安装包

```bash
cd
wget https://gitee.com/cnlxh/Kubernetes/raw/master/files/k8s/kubernetes-dashboard-7.8.0.tgz
```

部署dashboard

```bash
helm install lxh-k8s-dash --create-namespace --namespace lxh-k8s-dash /root/kubernetes-dashboard-7.8.0.tgz
```
输出
```text
NAME: lxh-k8s-dash
LAST DEPLOYED: Wed Oct 16 11:19:27 2024
NAMESPACE: lxh-k8s-dash
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
*************************************************************************************************
*** PLEASE BE PATIENT: Kubernetes Dashboard may need a few minutes to get up and become ready ***
*************************************************************************************************

Congratulations! You have just installed Kubernetes Dashboard in your cluster.

To access Dashboard run:
  kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443

NOTE: In case port-forward command does not work, make sure that kong service name is correct.
      Check the services in Kubernetes Dashboard namespace using:
        kubectl -n lxh-k8s-dash get svc

Dashboard will be available at:
  https://localhost:8443

```
查看pod是否启动

```bash
kubectl get pod -n lxh-k8s-dash

NAME                                                              READY   STATUS    RESTARTS   AGE
lxh-k8s-dash-kong-7c6d59d85f-4tswb                                1/1     Running   0          76s
lxh-k8s-dash-kubernetes-dashboard-api-7484fd9568-qlzwz            1/1     Running   0          76s
lxh-k8s-dash-kubernetes-dashboard-auth-5b548894b9-z977j           1/1     Running   0          76s
lxh-k8s-dash-kubernetes-dashboard-metrics-scraper-76c7f4ffp6pp2   1/1     Running   0          76s
lxh-k8s-dash-kubernetes-dashboard-web-59b6476f97-r9d26            1/1     Running   0          76s
```

查看服务是否存在

```bash
kubectl get service -n lxh-k8s-dash

NAME                                                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)         AGE
lxh-k8s-dash-kong-proxy                             ClusterIP    10.106.124.121   <none>        443:31000/TCP   12m
lxh-k8s-dash-kubernetes-dashboard-api               ClusterIP   10.111.236.2     <none>        8000/TCP        12m
lxh-k8s-dash-kubernetes-dashboard-auth              ClusterIP   10.102.138.145   <none>        8000/TCP        12m
lxh-k8s-dash-kubernetes-dashboard-metrics-scraper   ClusterIP   10.99.13.88      <none>        8000/TCP        12m
lxh-k8s-dash-kubernetes-dashboard-web               ClusterIP   10.107.34.153    <none>        8000/TCP        12m
```

看到kong-proxy是ClusterIP，不方便查看，直接改为31000的nodeport，就可以用任何节点的ip打开查看了

```bash
kubectl patch svc lxh-k8s-dash-kong-proxy -n lxh-k8s-dash --type='json' -p='[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"add","path":"/spec/ports/0/nodePort","value":31000}]'
```

比如我在浏览器输入https://192.168.8.3:31000

![](https://gitee.com/cnlxh/Kubernetes/raw/master/images/k8s/dashboard/dashboard-login.png)

创建一个用户登录的超级用户，并创建长期有效的token

```yaml
cat > create-dash-user.yml <<-'EOF'
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: lxh-dash
  namespace: lxh-k8s-dash
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: lxh-dash-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: lxh-dash
  namespace: lxh-k8s-dash
---
apiVersion: v1
kind: Secret
metadata:
  name: lxh-dash-secret
  namespace: lxh-k8s-dash
  annotations:
    kubernetes.io/service-account.name: "lxh-dash"
type: kubernetes.io/service-account-token

EOF
```

```bash
kubectl create -f create-dash-user.yml
```

获取登录token

```bash
kubectl get secret lxh-dash-secret -n lxh-k8s-dash -o jsonpath={".data.token"} | base64 -d
```

除了bash的root@master:~#提示符之外，把所有的内容复制一下，然后粘贴到登录框里并点击登录

![](https://gitee.com/cnlxh/Kubernetes/raw/master/images/k8s/dashboard/dashboard-logined.png)


# ETCD 备份与恢复

## 备份

先安装etcd客户端

```bash
apt install etcd-client -y
```

备份成文件并查看

```bash
ETCDCTL_API=3 etcdctl \
--endpoints=https://127.0.0.1:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key \
snapshot save etcdbackupfile.db

```

## 恢复

```bash
# 先停止服务
mv /etc/kubernetes/manifests /etc/kubernetes/manifests.bak
sleep 1m

# 删除现有ETCD，并恢复数据
mv /var/lib/etcd /var/lib/etcd.bak
ETCDCTL_API=3 etcdctl \
--endpoints=https://127.0.0.1:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key \
--data-dir /var/lib/etcd \
snapshot restore etcdbackupfile.db
```

```bash
2022-05-21 22:38:15.878455 I | mvcc: restore compact to 30118
2022-05-21 22:38:15.884564 I | etcdserver/membership: added member 8e9e05c52164694d [http://localhost:2380] to cluster cdf818194e3a8c32
```

```bash

# 恢复服务
mv /etc/kubernetes/manifests.bak /etc/kubernetes/manifests

systemctl restart kubelet.service

# 验证数据已经恢复

kubectl get pod

```

检查etcd是否健康

```bash
ETCDCTL_API=3 etcdctl --endpoints=https://192.168.8.3:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key endpoint health
```

```bash
https://127.0.0.1:2379 is healthy: successfully committed proposal: took = 883.786µs
```

# Kustomize 管理

## Kustomize 概念

Kustomize 是 Kubernetes 的原生配置管理工具，它允许用户通过定义资源和它们之间的依赖关系来描述 Kubernetes 应用程序的配置。

Kustomize 的核心概念大概包括：

**Kustomization 文件**：这是 Kustomize 配置的核心，它是一个 YAML 文件，定义了 Kubernetes 资源和如何定制它们。它可以用来指定要包含的资源、应用补丁、设置标签和注解、生成configmap和secret等

**资源（Resources）**：在 kustomization.yaml 文件中定义的 Kubernetes 资源列表，可以是文件、目录或者远程仓库中的资源。

**生成器（Generators）**：如 configMapGenerator 和 secretGenerator，它们可以根据文件或字面值生成 ConfigMap 或 Secret。

**补丁（Patches）**：用于修改现有资源的字段。Kustomize 支持策略性合并补丁（patchesStrategicMerge）和 JSON 补丁（patchesJson6902）。

**基准（Bases）**：包含 kustomization.yaml 文件的目录，定义了一组资源及其定制。

**覆盖（Overlays）**：也是一个目录，它引用基准目录作为基础，并且可以包含额外的定制。覆盖可以用来创建特定环境的配置，如开发、测试和生产环境。

Kustomize 的工作流程通常包括定义基准和覆盖，然后在覆盖中应用补丁和生成器来定制基准资源。这种方式使得用户可以轻松地为不同环境创建和管理 Kubernetes 资源配置。

## Kustomize 实验

### 实验概述

本实验旨在通过实际操作，让大家掌握 Kustomize 的使用，以便能够根据不同的环境需求（如开发、测试和生产环境）定制和管理 Kubernetes 应用的配置。

### 实验目标

**理解 Kustomize 的作用和优势:**

- 理解 Kustomize 如何简化 Kubernetes 应用的配置管理。

**创建和管理 Base 目录:**

- 学会创建包含通用资源定义的 Base 目录。
- 编写 kustomization.yaml 文件来声明资源、生成器和补丁。

**定制 Overlay 配置:**

- 学会创建 Overlay 目录以适应特定环境的配置需求。
- 应用 patchesStrategicMerge 和 patchesJson6902 来定制 Deployment 资源。

**生成 ConfigMap 和 Secret:**

- 使用 configMapGenerator 和 secretGenerator 来生成环境特定的配置和敏感信息。

**应用环境标签和注解:**

- 在资源上添加环境特定的标签（如 env: dev）和注解。

**禁用名称后缀哈希:**

- 配置 generatorOptions 以禁用资源名称的哈希后缀，以保持资源名称的一致性。

**验证 Overlay 配置:**

- 使用 kubectl kustomize 命令来验证 Overlay 目录的最终 Kubernetes 资源配置。

**部署到 Kubernetes 集群:**

- 使用 kubectl apply -k 命令将定制的 Overlay 配置应用到 Kubernetes 集群。

**清理和维护:**

- 学会如何清理实验中创建的资源，包括 Namespace 和各种 Kubernetes 资源。

### 实验步骤
#### 准备Base目录

先在base目录中创建一些通用的yaml文件

```bash
mkdir base
cd base
```

在base目录中，创建一个secret，稍后可以在overlay目录中打补丁或者不打，secret文件如下：

这个密码是ABCabc123

```yaml
cat > Secret.yml <<-EOF
apiVersion: v1
data:
  password: QUJDYWJjMTIz
kind: Secret
metadata:
  name: mysqlpass
EOF
```
在base目录中，创建一个Deployment，replicas是3，标签为app: nginx, Deployment文件如下：

```yaml
cat > Deployment.yml <<-EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: mysqlname
          image: registry.cn-shanghai.aliyuncs.com/cnlxh/mysql
          imagePullPolicy: IfNotPresent
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysqlpass
                  key: password
EOF
```
在base目录中，创建一个Service，Service文件如下：

```yaml
cat > Service.yml <<-EOF
apiVersion: v1
kind: Service
metadata:
  name: nodeservice
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 8000
      targetPort: 80
      nodePort: 31788
EOF
```

最后生成kustomization.yaml，在这个文件中，我们包含上我们刚创建的3个资源

```yaml
cat > kustomization.yaml <<-EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
metadata:
  name: lxh-base-kustomization
resources:
- Secret.yml
- Deployment.yml
- Service.yml
EOF
```

查看现在文件列表

```bash
apt install tree -y
tree .
```

输出

```text
.
├── Deployment.yml
├── kustomization.yaml
├── Secret.yml
└── Service.yml

0 directories, 4 files
```

以上在base目录中的文件将用于生成：

1. 一个名为mysqlpass的机密

2. 一个名为nginx-deployment的部署，此部署的pod将具有app: nginx标签，并引用mysqlpass机密作为密码，密码值为ABCabc123

3. 一个名为nodeservice的服务，监听在8000端口，收到请求后，转发给具有app: nginx标签的pod，并启用了31788的nodePort

#### 准备Overlay目录

**创建开发环境**

```bash
cd
mkdir -p overlays/development
cd overlays/development
```

创建开发环境的kustomization.yaml 文件：

Kustomize 功能特性列表参阅：

```text
https://kubernetes.io/zh-cn/docs/tasks/manage-kubernetes-objects/kustomization/#kustomize-feature-list
```

1. patchesStrategicMerge补丁将会更新nginx-deployment这个Deployment
2. patchesJson6902补丁也会更新nginx-deployment这个Deployment
3. overlay的对象是刚创建的base目录下的内容
4. 全体对象添加env: dev
5. 禁止添加hash后缀
6. 产生两个新的configmap和secret

```yaml
cat > kustomization.yaml <<-EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: lxh-dev
patches:
  - path: patchesStrategicMerge-demo.yaml
    target:
      kind: Deployment
      name: nginx-deployment
    options:
      allowNameChange: true
  - path: patchesJson6902-demo.yaml
    target:
      kind: Deployment
      name: nginx-deployment
    options:
      allowNameChange: true
resources:
  - ../../base
commonLabels:
  env: dev
generatorOptions:
  disableNameSuffixHash: true
configMapGenerator:
- name: cmusername
  files:
    - configmap-1.yml
- name: cmage
  literals:
    - cmage=18
secretGenerator:
- name: username
  files:
    - secret-1.yml
  type: Opaque
- name: secrettest
  literals:
    - password=LiXiaoHui
  type: Opaque
EOF
```

#### 生成器Generator

在kustomization.yaml，如果用文件来生成configmap和secret，会将文件名也作为数据的一部分，建议用literals

生成configmap和secret的文件

```text
cat > configmap-1.yml <<-EOF
username=lixiaohui
EOF
```
```bash
cat > secret-1.yml <<-EOF
username=admin
password=secret
EOF
```

#### 策略性合并与JSON补丁

在 Kustomize 中，patchesStrategicMerge 和 patchesJson6902 都用于修改现有的 Kubernetes 资源。

1. patchesStrategicMerge补丁方式使用 YAML 文件来定义，它允许你直接编辑资源的 YAML 结构，就像编辑原始资源文件一样。这种方式直观且易于理解，特别是对于那些熟悉 Kubernetes 资源配置的人来说。

2. patchesJson6902 使用的是 JSON 补丁（JSON Patch）的方式，这是一种更为灵活和强大的补丁应用方式。JSON 补丁遵循 JSON Patch 规范（RFC 6902），允许执行更复杂的操作，如添加、删除、替换、测试等。这种方式使用 JSON 格式定义，可能在处理复杂的修改时更加强大。

**生成策略性合并补丁**

这里的名字一定要和已有的资源的名称一致

更新deployment的replicas为4

```yaml
cat > patchesStrategicMerge-demo.yaml <<-EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 4
EOF
```

**生成JSON补丁**

新增deployment下的pod标签为dev: release1

```json
cat > patchesJson6902-demo.yaml <<-EOF
[
  {
    "op": "add",
    "path": "/spec/template/metadata/labels/dev",
    "value": "release1"
  }
]
EOF
```

目前的文件列表：

```bash
root@k8s-master:~/overlays/development# tree .
.
├── configmap-1.yml
├── kustomization.yaml
├── patchesJson6902-demo.yaml
├── patchesStrategicMerge-demo.yaml
└── secret-1.yml

0 directories, 5 files
```

#### 验证overlay最终成果

```bash
root@k8s-master:~/overlays/development# kubectl kustomize ./
```
输出
```text
apiVersion: v1
data:
  cmage: "18"
kind: ConfigMap
metadata:
  labels:
    env: dev
  name: cmage
  namespace: lxh-dev
---
apiVersion: v1
data:
  configmap-1.yml: |
    username=lixiaohui
kind: ConfigMap
metadata:
  labels:
    env: dev
  name: cmusername
  namespace: lxh-dev
---
apiVersion: v1
data:
  password: QUJDYWJjMTIz
kind: Secret
metadata:
  labels:
    env: dev
  name: mysqlpass
  namespace: lxh-dev
---
apiVersion: v1
data:
  password: TGlYaWFvSHVp
kind: Secret
metadata:
  labels:
    env: dev
  name: secrettest
  namespace: lxh-dev
type: Opaque
---
apiVersion: v1
data:
  secret-1.yml: dXNlcm5hbWU9YWRtaW4KcGFzc3dvcmQ9c2VjcmV0Cg==
kind: Secret
metadata:
  labels:
    env: dev
  name: username
  namespace: lxh-dev
type: Opaque
---
apiVersion: v1
kind: Service
metadata:
  labels:
    env: dev
  name: nodeservice
  namespace: lxh-dev
spec:
  ports:
  - nodePort: 31788
    port: 8000
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx
    env: dev
  type: NodePort
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx
    env: dev
  name: nginx-deployment
  namespace: lxh-dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
      env: dev
  template:
    metadata:
      labels:
        app: new-label
        env: dev
    spec:
      containers:
      - env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              key: password
              name: mysqlpass
        image: registry.cn-shanghai.aliyuncs.com/cnlxh/mysql
        imagePullPolicy: IfNotPresent
        name: mysqlname
```

#### 发布开发环境

```bash
cd /root/overlays/development/
kubectl create namespace lxh-dev
kubectl apply -k .
```

```text
configmap/cmage created
configmap/cmusername created
secret/mysqlpass created
secret/secrettest created
secret/username created
service/nodeservice created
deployment.apps/nginx-deployment created
```

查询创建的内容

发现我们新configmap和secret已经生效，两个补丁也都生效了，一个补丁将deployment的pod数量该为4，一个补丁添加了dev=release1的标签

```bash
root@k8s-master:~/overlays/development# kubectl get configmaps -n lxh-dev
NAME               DATA   AGE
cmage              1      41s
cmusername         1      41s
kube-root-ca.crt   1      11m
root@k8s-master:~/overlays/development# kubectl get secrets -n lxh-dev
NAME         TYPE     DATA   AGE
mysqlpass    Opaque   1      47s
secrettest   Opaque   1      47s
username     Opaque   1      47s

root@k8s-master:~/overlays/development# kubectl get service -n lxh-dev
NAME          TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
nodeservice   NodePort   10.106.128.145   <none>        8000:31788/TCP   51s

root@k8s-master:~/overlays/development# kubectl get deployments.apps -n lxh-dev
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   4/4     4            4           55s

root@k8s-master:~/overlays/development# kubectl get pod --show-labels  -n lxh-dev
NAME                                READY   STATUS    RESTARTS   AGE   LABELS
nginx-deployment-6f86fd678b-bv688   1/1     Running   0          64s   app=nginx,dev=release1,env=dev,pod-template-hash=6f86fd678b
nginx-deployment-6f86fd678b-wpk49   1/1     Running   0          64s   app=nginx,dev=release1,env=dev,pod-template-hash=6f86fd678b
nginx-deployment-6f86fd678b-wr94h   1/1     Running   0          64s   app=nginx,dev=release1,env=dev,pod-template-hash=6f86fd678b
nginx-deployment-6f86fd678b-xxkbw   1/1     Running   0          64s   app=nginx,dev=release1,env=dev,pod-template-hash=6f86fd678b
```

