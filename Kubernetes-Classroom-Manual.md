# Kubernetes 实验手册

```textile
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```

| 版本编号 | 版本日期       | 修改者 | 说明                      | 备注  |
| ---- | ---------- | --- | ----------------------- | --- |
| 1.0  | 2022-01-14 | 李晓辉 | 初始创建，基于Kubernetes v1.23 |     |
| 2.0  | 2022-05-12 | 李晓辉 | 修订细节，更新版本至v1.24         |     |
| 3.0  | 2022-10-15 | 李晓辉 | 修订细节，更新版本至v1.25         |     |

[TOC]

# 准备DNS解析

```bash
cat >> /etc/hosts <<EOF
192.168.30.130 cka-master
192.168.30.131 cka-worker1
192.168.30.132 cka-worker2
192.168.30.133 registry.xiaohui.cn
EOF
```

以下Docker CE和Containerd只需选一个即可，建议选Docker CE

# Docker CE 部署
## 添加Docker 仓库

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

```

## 安装Docker CE

```bash
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

## 添加Docker 镜像加速器
```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["http://hub-mirror.c.163.com"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
systemctl enable docker

# 验证镜像加速器成功添加与否，docker info | grep 163后，要出现163链接才算成功

docker info | grep 163

WARNING: No swap limit support
http://hub-mirror.c.163.com/

```
部署完Docker CE之后，还需要cri-docker shim才可以和Kubernetes集成

## CRI-Docker 部署
```bash
wget https://ghproxy.com/https://github.com/Mirantis/cri-dockerd/releases/download/v0.2.6/cri-dockerd_0.2.6.3-0.ubuntu-focal_amd64.deb
dpkg -i cri-dockerd_0.2.6.3-0.ubuntu-focal_amd64.deb

sed -i 's/ExecStart=.*/ExecStart=\/usr\/bin\/cri-dockerd --container-runtime-endpoint fd:\/\/ --network-plugin=cni --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com\/google_containers\/pause:3.8/' /lib/systemd/system/cri-docker.service
systemctl daemon-reload
systemctl restart cri-docker.service
systemctl enable cri-docker.service

```

# Containerd部署

Containerd部署的环节需要在所有节点上都完成，如果已经安装了Docker，请勿进行Containerd整个一级目录

## 下载安装包

```bash
wget https://ghproxy.com/https://github.com/containerd/nerdctl/releases/download/v1.0.0/nerdctl-full-1.0.0-linux-amd64.tar.gz
tar Cxzvvf /usr/local nerdctl-full-1.0.0-linux-amd64.tar.gz
```

## 生成并编辑配置文件

更改文件内容的原因是因为国内无法连接Google

```bash
mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/.*sandbox_image.*/    sandbox_image = "registry.cn-hangzhou.aliyuncs.com\/google_containers\/pause:3.6"/' /etc/containerd/config.toml
sed -i 's/.*SystemdCgroup.*/            SystemdCgroup = true/' /etc/containerd/config.toml
```

大家要注意，上方的SystemCgroup中的首字母是大写，不要修改sandbox下方的systemd_cgroup = false，真正需要修改的是125行左右的内容，如果修改的不是首字母大写的参数，在执行下方集成Containerd的步骤时会出现以下报错

```bash
FATA[0000] listing images: rpc error: code = Unimplemented desc = unknown service runtime.v1alpha2.ImageService 
```

解决办法是把小写字母的值改回false，把125行左右的值改成true

## 添加容器镜像加速

这里只限在国内部署时才需要加速，在国外这样加速反而缓慢

[参考资料](https://github.com/containerd/containerd/blob/main/docs/cri/config.md#registry-configuration)  

```bash
sed -i 's/.*config_path.*/      config_path = "\/etc\/containerd\/certs.d"/' /etc/containerd/config.toml
```

```bash
mkdir /etc/containerd/certs.d/docker.io/ -p
cat > /etc/containerd/certs.d/docker.io/hosts.toml <<EOF
server = "https://docker.io"
[host."http://hub-mirror.c.163.com"]
  capabilities = ["pull", "resolve"]
EOF
```

## 启动Containerd服务

```bash
systemctl daemon-reload
systemctl enable --now containerd
systemctl is-active containerd
```

## 添加命令自动补齐功能

```bash
nerdctl completion bash > /etc/bash_completion.d/nerdctl
source /etc/bash_completion.d/nerdctl
```

如果执行后提示 /etc/bash_completion.d/nerdctl: No such file or directory，就更改为以下命令完成自动补齐功能，此时要注意用的是两个大于号的追加符号

```bash
nerdctl completion bash >> /root/.bashrc
source /root/.bashrc
```

# 创建第一个容器

## 创建容器

```bash
docker run -d -p 8000:80 --name container1 nginx
docker ps

CONTAINER ID    IMAGE                             COMMAND                   CREATED          STATUS    PORTS                   NAMES
eea8ed66990c    docker.io/library/nginx:latest    "/docker-entrypoint.…"    7 seconds ago    Up        0.0.0.0:8000->80/tcp    container1    
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

REPOSITORY    TAG       IMAGE ID        CREATED           PLATFORM       SIZE         BLOB SIZE
nginx         latest    0d17b565c37b    13 minutes ago    linux/amd64    149.1 MiB    54.1 MiB
nginx         v1        edc2905109d8    5 seconds ago     linux/amd64    149.2 MiB    54.1 MiB

docker history nginx:v1
```

## 构建并使用Commit镜像

使用nginx:v1镜像在本机的3000端口提供一个名为lixiaohuicommit的容器

```bash
docker run -d -p 3000:80 --name lixiaohuicommit nginx:v1
curl http://127.0.0.1:3000

hello lixiaohui
```

## Dockerfile 构建


```bash
# 只有Nerdctl，也就是containerd才需要启用这个服务
systemctl enable buildkit --now
cat > dockerfile <<EOF
FROM httpd
MAINTAINER 939958092@qq.com
RUN echo hello lixiaohui dockerfile container > /usr/local/apache2/htdocs/index.html
EXPOSE 80
WORKDIR /usr/local/apache2/htdocs/
EOF
```

```bash
docker build -t httpd:v1 -f dockerfile .
docker images

REPOSITORY    TAG       IMAGE ID        CREATED               PLATFORM       SIZE         BLOB SIZE
httpd         v1        494736083f8f    About a minute ago    linux/amd64    150.2 MiB    53.8 MiB
nginx         latest    2d17cc4981bf    4 minutes ago         linux/amd64    149.1 MiB    54.1 MiB
nginx         v1        fc81b1ce4076    3 minutes ago         linux/amd64    149.2 MiB    54.1 MiB
```

docker build -t httpd:v1 -f dockerfile .
这个命令后面还有一个英文的句号.是指当前目录

## 构建并使用Dockerfile镜像

用httpd:v1的镜像在本机4000端口上提供一个名为dockerfile的容器

```bash
docker run -d -p 4000:80 --name lixiaohuidockerfile httpd:v1
docker ps

CONTAINER ID    IMAGE                             COMMAND                   CREATED          STATUS    PORTS                   NAMES
534323e724a7    docker.io/library/nginx:latest    "/docker-entrypoint.…"    5 minutes ago    Up        0.0.0.0:8000->80/tcp    container1             
7ee887b78a75    docker.io/library/httpd:v1        "httpd-foreground"        3 seconds ago    Up        0.0.0.0:4000->80/tcp    lixiaohuidockerfile    
a41ef87ba51f    docker.io/library/nginx:v1        "/docker-entrypoint.…"    3 minutes ago    Up        0.0.0.0:3000->80/tcp    lixiaohuicommit        

curl http://127.0.0.1:4000
hello lixiaohui dockerfile container
```

## 删除容器

```bash
docker rm -f container1 lixiaohuidockerfile lixiaohuicommit 
```

# 构建私有仓库

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
  "registry-mirrors": ["http://hub-mirror.c.163.com"]
}
EOF

```
添加Compose支持，并启动Docker服务

```bash
curl -L "https://ghproxy.com/https://github.com/docker/compose/releases/download/v2.13.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
sudo systemctl daemon-reload
sudo systemctl restart docker

```

```bash
wget https://ghproxy.com/https://github.com/goharbor/harbor/releases/download/v1.10.15/harbor-offline-installer-v1.10.15.tgz
tar xf harbor-offline-installer-v1.10.15.tgz -C /usr/local/bin
cd /usr/local/bin/harbor
docker load -i harbor.v1.10.15.tar.gz

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

```bash
swapoff -a
sed -i 's/.*swap.*/#&/' /etc/fstab
```

## 允许 iptables 检查桥接流量

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

国内选南京大学就行，如果是海外，直接使用Google

### Google

```bash
apt-get update
apt-get install -y apt-transport-https ca-certificates curl 
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
cat > /etc/apt/sources.list.d/k8s.list <<EOF
deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update 
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### 南京大学

```bash
apt-get update && apt-get install -y apt-transport-https curl
cat > /etc/apt/sources.list.d/k8s.list <<EOF
deb https://mirror.nju.edu.cn/kubernetes/apt/ kubernetes-xenial main
EOF
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 
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

如果提示/etc/bash_completion.d/kubectl: No such file or directory 这个错误，用以下方式完成补齐功能，此时要注意用的是两个大于号的追加符号，只能执行一次

```bash
kubectl completion bash >> /root/.bashrc 
kubeadm completion bash >> /root/.bashrc
source /root/.bashrc
```
这里集成CRI-Docker和集成Containerd只需要完成一项，建议CRI-Docker
## 集成CRI-Docker
```bash
crictl config runtime-endpoint unix:///run/cri-dockerd.sock
crictl images
```

## 集成Containerd

```bash
crictl config runtime-endpoint unix:///run/containerd/containerd.sock
crictl images
```

集成的步骤务必确保crictl images命令回车的时候不能出错，出错后参考上述生成并编辑配置文件的步骤

## 集群部署

下方kubeadm.yaml中name字段必须在网络中可被解析，也可以将解析记录添加到集群中所有机器的/etc/hosts中

```bash
kubeadm config print init-defaults > kubeadm.yaml
sed -i 's/.*advert.*/  advertiseAddress: 192.168.30.130/g' kubeadm.yaml
sed -i 's/.*name.*/  name: cka-master/g' kubeadm.yaml
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
kubeadm join 192.168.30.130:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:d0edd579cbefc3baee6c2253561e24261300ede214ae172bf9687404e09104bf 
```

授权管理权限
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## 部署Calico网络插件

为解决镜像无法拉取，我做了国内镜像，请使用此镜像

```bash
kubectl apply -f https://gitee.com/cnlxh/Kubernetes/raw/master/cka-yaml/calico.yaml
```

查询集群组件是否工作正常，正常应该都处于running

```bash
kubectl get pod -A
```

## 加入Worker节点

这里要注意，Worker节点需要完成以下先决条件才能执行kubeadm join

1. Containerd 部署或CRI-Docker 部署
2. Swap 分区关闭
3. iptables 桥接流量的允许
4. 安装kubeadm等软件
5. 集成Containerd或集成CRI-Docker
6. 所有节点的/etc/hosts中互相添加对方的解析

如果时间长忘记了join参数，可以用以下方法获取

```bash
kubeadm token create
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
```

如果觉得查找命令太长，可以用以下方式生成新的token

```bash
kubeadm token create --print-join-command
```

加入节点时，指定CRI对象，案例如下：

```bash
kubeadm join 192.168.30.130:6443 --token m0uywc.81wx2xlrzzfe4he0 \
--discovery-token-ca-cert-hash sha256:5a24296d9c8f5ace4dede7ed46ee2ecf5ed51c0877e5c1650fe2204c09458274 \
--cri-socket=unix:///var/run/cri-dockerd.sock
```

加入后执行下面的命令查看节点状态

```bash
kubectl get nodes
```

给节点打上角色标签，cka-worker1 cka-worker2打上了worker标签

```bash
kubectl label nodes cka-worker1 cka-worker2 node-role.kubernetes.io/worker=
kubectl get nodes
```

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
kubectl run nginx --image=nginx --namespace=lixiaohui
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
    image: busybox
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
    image: busybox
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', 'echo "Hello, lixiaohui!" && sleep 3600']
  - name: httpd
    image: httpd
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
NAME   READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
pod    2/2     Running   0          66s   172.16.200.199   host1   <none>           <none>

root@cka-master:~# curl 172.16.200.199
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
    image: busybox
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', 'echo The app is running! && sleep 3600']
  initContainers:
  - name: init-myservice
    image: busybox
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', "sleep 20"]
  - name: init-mydb
    image: busybox
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
    image: httpd
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /usr/local/apache2/htdocs/
        name: lixiaohuivolume
  - name: busybox
    image: busybox
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
NAME         READY   STATUS    RESTARTS   AGE     IP             NODE          NOMINATED NODE   READINESS GATES
sidecarpod   2/2     Running   0          3m54s   172.17.245.1   cka-worker2   <none>           <none>

curl http://172.17.245.1
Hello sidecar
```

## Static Pod

运行中的 kubelet 会定期扫描配置的目录中的变化， 并且根据文件中出现/消失的 Pod 来添加/删除 Pod。 

```bash
systemctl status kubelet
...
Drop-In: /etc/systemd/system/kubelet.service.d
           └─10-kubeadm.conf
```

```bash
tail /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
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
    image: busybox
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', 'echo "Hello, lixiaohui!" && sleep 3600']
  restartPolicy: OnFailure
EOF
```

把这个yaml文件复制到/etc/kubernetes/manifests，然后观察pod列表，然后把yaml文件移出此文件夹，再观察pod列表

```bash
cp static.yml /etc/kubernetes/manifests/
kubectl get pod
NAME                   READY   STATUS    RESTARTS   AGE
staticpod-host1   1/1     Running   0          74s

rm -rf /etc/kubernetes/manifests/static.yml 
kubectl get pod
No resources found in default namespace.
```

## Pod 删除

kubectl delete pod --all会删除所有pod

```bash
kubectl delete pod --all
```

# kubernetes 控制器

## Replica Set

使用cnlxh/gb-frontend:v3镜像创建具有3个pod的RS,并分配合适的标签

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
        image: nginx
        ports:
          - name: http
            containerPort: 80
        imagePullPolicy: IfNotPresent
EOF
```

```bash
kubectl create -f rs.yml 
kubectl get replicasets.apps,pods -o wide
NAME                          DESIRED   CURRENT   READY   AGE    CONTAINERS   IMAGES   SELECTOR
replicaset.apps/nginxrstest   3         3         3       2m4s   nginx        nginx    app=nginxrstest

NAME                    READY   STATUS    RESTARTS   AGE   IP              NODE                    NOMINATED NODE   READINESS GATES
pod/nginxrstest-chtkc   1/1     Running   0          62s   172.17.93.196   cka-worker1             <none>           <none>
pod/nginxrstest-scvhv   1/1     Running   0          62s   172.17.245.4    cka-worker2             <none>           <none>
pod/nginxrstest-zqllq   1/1     Running   0          62s   172.17.193.2    cka-master              <none>           <none>

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
        image: nginx
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
EOF
```

我们发现deployment管理了一个RS，而RS又实现了3个pod

```bash
kubectl create -f deployment.yml
kubectl get deployments.apps,replicasets.apps,pods -l app=nginx
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
kubectl set image deployments/nginx-deployment nginx=nginx:1.16.1 --record

查看更新进度

kubectl rollout status deployment/nginx-deployment
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
Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 3 new replicas have been updated...
```

查看历史版本

```bash
kubectl rollout history deployments/nginx-deployment
deployment.apps/nginx-deployment 
REVISION  CHANGE-CAUSE
1         <none>
2         kubectl set image deployments/nginx-deployment nginx=nginx:1.16.1 --record=true
3         kubectl set image deployments/nginx-deployment nginx=nginx:1.161 --record=true

kubectl rollout history deployment.v1.apps/nginx-deployment --revision=3
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
        image: busybox
        imagePullPolicy: IfNotPresent
        command: ['sh', '-c', 'sleep 3600']
EOF
```

```bash
kubectl create -f daemonset.yml
kubectl get daemonsets.apps
NAME        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
lixiaohui   3         3         3       3            3           <none>          24s
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
        image: nginx
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
        image: busybox
        imagePullPolicy: IfNotPresent
        command: ["sh",  "-c", "while true;do echo CKA JOB;done"]
      restartPolicy: Never
  backoffLimit: 4
EOF
```

```bash
root@cka-master:~# kubectl get jobs,pods
NAME           COMPLETIONS   DURATION   AGE
job.batch/pi   0/1           82s        82s

NAME           READY   STATUS    RESTARTS   AGE
pod/pi-66qbm   1/1     Running   0          82s

kubectl logs pi-66qbm
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
cat > crobjob.yml <<EOF
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
            image: busybox
            imagePullPolicy: IfNotPresent
            command:
            - /bin/sh
            - -c
            - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure
EOF
```

```bash
kubectl create -f crobjob.yml
# 这里需要等待一分钟再去get
kubectl get cronjobs,pod
NAME                        SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
cronjob.batch/cronjobtest   */1 * * * *   False     0        23s             83s
NAME                                   READY   STATUS      RESTARTS   AGE
pod/cronjobtest-27444239-kqcjc         0/1     Completed   0          23s

kubectl logs cronjobtest-27444239-kqcjc 
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
        image: nginx
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

NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
service/kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP          27m
service/lxhservice   NodePort    10.96.213.26   <none>        9000:31919/TCP   28s

NAME                   ENDPOINTS                                                        AGE
endpoints/kubernetes   192.168.30.130:6443                                              27m
endpoints/lxhservice   172.16.152.69:80,172.16.152.72:80,172.16.152.73:80 + 8 more...   28s

root@cka-master:~# curl http://192.168.30.130:31919
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
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
my-service   ClusterIP   10.102.224.203   <none>        8000/TCP   88s

root@cka-master:~# curl http://10.102.224.203:8000
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

NAME          TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
nodeservice   NodePort   10.100.234.83   <none>        8000:31788/TCP   11s

# 因为是nodeport，所以用节点IP
curl http://192.168.30.130:31788
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

NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
headless   ClusterIP   None         <none>        8000/TCP   4s
```

```bash
kubectl run --rm --image=docker.io/busybox:1.28 -it testpod
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

## Ingress

Ingress 需要Ingress控制器支持，先部署控制器

```bash
kubectl apply -f https://gitee.com/cnlxh/Kubernetes/raw/master/cka-yaml/ingressdeploy.yaml

```

```bash
kubectl get pod -n ingress-nginx
NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-2pstr        0/1     Completed   0          66s
ingress-nginx-admission-patch-l2ndl         0/1     Completed   0          66s
ingress-nginx-controller-7bb6bfc859-2m7zn   1/1     Running     0          66s
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
        image: nginx
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

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment-ingress   3/3     3            3           2m

NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
ingressservice   ClusterIP   10.110.117.37   <none>        80/TCP    2m7

NAME        CLASS   HOSTS               ADDRESS                         PORTS   AGE
lixiaohui   nginx   www.lixiaohui.com   192.168.30.131,192.168.30.132   80      2m26s

把上述ADDRESS部分的IP和域名绑定解析

echo 192.168.30.131 www.lixiaohui.com >> /etc/hosts

curl http://www.lixiaohui.com
```

```bash
kubectl delete -f ingress.yml
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
    image: busybox
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
...
Events:
  Type     Reason     Age                  From               Message
  ----     ------     ----                 ----               -------
  Normal   Scheduled  3m16s                default-scheduler  Successfully assigned lixiaohui/liveness-exec to cka-worker1
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
    image: httpd
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
NAME   READY   STATUS      RESTARTS   AGE
http   0/1     Completed   3          3m6s

kubectl describe pod http 
Events:
  Type     Reason     Age                    From               Message
  ----     ------     ----                   ----               -------
  Normal   Scheduled  3m28s                  default-scheduler  Successfully assigned lixiaohui/http to cka-worker1
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

kubelet 会在容器启动 5 秒后发送第一个就绪探测。 这会尝试连接容器的 80 端口。如果探测成功，这个 Pod 会被标记为就绪状态，kubelet 将继续每隔 10 秒运行一次检测。

除了就绪探测，这个配置包括了一个存活探测。 kubelet 会在容器启动 15 秒后进行第一次存活探测。 与就绪探测类似，会尝试连接 器的 80 端口。 如果存活探测失败，这个容器会被重新启动。

```bash
cat > readiness.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: tcpcheck
spec:
  containers:
  - name: httpd
    image: httpd
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
NAME       READY   STATUS    RESTARTS     AGE
tcpcheck   0/1     Running   1 (6s ago)   67s

kubectl describe pod tcpcheck 
...
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  60s               default-scheduler  Successfully assigned lixiaohui/tcpcheck to cka-worker1
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
    image: httpd
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
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  24s               default-scheduler  Successfully assigned default/startprobe to cka-worker02
  Normal   Pulled     23s               kubelet            Container image "httpd" already present on machine
  Normal   Created    23s               kubelet            Created container httpd
  Normal   Started    23s               kubelet            Started container httpd
  Warning  Unhealthy  3s (x2 over 13s)  kubelet            Startup probe failed: Get "http://192.168.20.20:800/": dial tcp 192.168.20.20:800: connect: connection refused
```

可以发现由于我们故意写成了800端口，检测失败，容器一直无法就绪

```bash
kubectl delete -f startup.yml
```

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
    image: httpd
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
NAME   READY   STATUS    RESTARTS   AGE
httpgrace    1/1     Running   0          7s

kubectl delete -f grace.yml &
[1] 61187

kubectl get pod
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
  - image: httpd
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
NAME       READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
emptydir   1/1     Running   0          29s   172.16.200.228   cka-worker01 <none>           <none>
```

```bash
# 根据上面的提示，在指定的机器上完成这个步骤
crictl ps | grep -i test-container
d27c066d7acc3       faed93b288591       2 minutes ago       Running             test-container            0                   6f045542048c9

crictl inspect d27c066d7acc3 | grep cache
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
  - image: nginx
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
NAME           READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
hostpathtest   1/1     Running   0          3s    172.16.200.223   cka-worker02   <none>           <none>

# 根据提示，在work02上完成这个步骤
echo hostwrite > /data/index.html

curl http://172.16.200.223
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
    server: 192.168.30.130
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
      image: httpd
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
NAME    READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
mypod   1/1     Running   0          8s    172.16.200.225   cka-worker02   <none>           <none>

# 在NFS服务器上(192.168.30.130)创建出index.html网页

echo pvctest > /nfsshare/index.html

# 这里要看一下调度到哪个机器，这个机器必须执行apt install nfs-common -y

curl http://172.16.200.225
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
SUCCESS
```

删除pod和pvc，会删除我们的资源，测试一下，执行后，会删除pod、pvc、pv，再去nfs服务器查看，数据就没了

```bash
kubectl delete -f deploy/test-pod.yaml -f deploy/test-claim.yaml
```

# Pod调度

## nodeSelector

给cka-worker2节点打一个标签name=lixiaohui

```bash
kubectl label nodes cka-worker2 name=lixiaohui
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
    image: nginx
    imagePullPolicy: IfNotPresent
  nodeSelector:
    name: lixiaohui
EOF
```

```bash
kubectl create -f assignpod.yml 
kubectl get pod cnlxhtest -o wide
NAME        READY   STATUS    RESTARTS   AGE   IP               NODE               NOMINATED NODE   READINESS GATES
cnlxhtest   1/1     Running   0          10s   172.16.125.120   cka-worker2   <none>           <none>
```

```bash
kubectl delete -f assignpod.yml
```

## nodeName

将Pod仅调度到具有特定名称的节点上，例如仅调度到cka-worker1上

```bash
cat > nodename.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: lxhnodename
spec:
  containers:
  - name: nginx
    image: nginx
    imagePullPolicy: IfNotPresent
  nodeName:
    cka-worker1
EOF
```

```bash
kubectl create -f nodename.yml 
kubectl get pod lxhnodename -o wide
NAME          READY   STATUS    RESTARTS   AGE   IP             NODE               NOMINATED NODE   READINESS GATES
lxhnodename   1/1     Running   0          9s    172.16.127.5   cka-worker1   <none>           <none>
```

```bash
kubectl delete -f nodename.yml
```

## tolerations

master节点默认不参与调度的原因就是因为其上有taint，而toleration就是容忍度

```bash
kubectl describe nodes cka-master | grep -i taint
node-role.kubernetes.io/control-plane:NoSchedule
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
    image: nginx
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
NAME          READY   STATUS    RESTARTS   AGE   IP              NODE               NOMINATED NODE   READINESS GATES
tolerations   1/1     Running   0          7s    172.16.125.65   cka-worker2   <none>           <none>
```

此时我们发现，并没有调度到cka-master上，由此我们得出来一个结果，容忍不代表必须，如果必须要调度到cka-master，需要用以下例子

```bash
cat > mustassign.yml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: tolerationsmust
spec:
  containers:
  - name: nginx
    image: nginx
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
NAME          READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
tolerations   1/1     Running   0          3s    172.16.119.16   cka-master   <none>           <none>
```

```bash
kubectl delete -f tolerations.yml
kubectl delete -f mustassign.yml
```

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
NAME               DATA   AGE
game-demo          3      18s
kube-root-ca.crt   1      49d

kubectl describe configmaps game-demo 
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
      image: httpd
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
NAME              READY   STATUS    RESTARTS   AGE   IP               NODE         NOMINATED NODE   READINESS GATES
configmapvolume   1/1     Running   0          63s   172.16.200.237   cka-worker1 <none>           <none>

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
      image: mysql
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
      image: mysql
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
    image: nginx
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
    image: nginx
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
Error from server (Forbidden): error when creating "nmpod.yml": pods "frontend" is forbidden: exceeded quota: lixiaohuiquota, requested: limits.cpu=15,requests.cpu=15,requests.memory=64Mi, used: limits.cpu=0,requests.cpu=0,requests.memory=0, limited: limits.cpu=2,requests.cpu=1,requests.memory=1
```

# 访问控制

## ServiceAaccount

在一个名为test的namespace中，创建一个名为lixiaohui的ServiceAccount

```bash
kubectl create namespace test
kubectl -n test create serviceaccount lixiaohui
kubectl -n test get serviceaccounts lixiaohui
NAME        SECRETS   AGE
lixiaohui   1         63s

kubectl -n test describe serviceaccounts lixiaohui
Name:                lixiaohui
Namespace:           test
Labels:              <none>
Annotations:         <none>
Image pull secrets:  <none>
Mountable secrets:   lixiaohui-token-4flwd
Tokens:              lixiaohui-token-4flwd
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
kubectl create clusterrole --resource=pod,deployment --verb=create,get test-clusterrole
kubectl describe clusterrole test-clusterrole
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
    image: httpd
    ports:
      - name: web
        containerPort: 80
  restartPolicy: OnFailure
EOF
```

```bash
kubectl create -f nppod.yml
kubectl get pod -n zhangsan  -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP              NODE               NOMINATED NODE   READINESS GATES
pod    1/1     Running   0          83s   172.16.152.73   cka-worker2        <none>           <none>
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
    image: httpd
    ports:
      - name: web
        containerPort: 80
  restartPolicy: OnFailure
EOF
```

```bash
kubectl create -f nppod1.yml
kubectl get pod -n lixiaohui -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP              NODE               NOMINATED NODE   READINESS GATES
pod1   1/1     Running   0          14s   172.16.152.74   cka-worker2          <none>           <none>
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
          name: lixiaohui
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
    image: busybox
    command:
      - /bin/sh
      - -c
      - "sleep 10m"
  restartPolicy: OnFailure
EOF
kubectl create -f nptest.yml
```

访问没有被网络策略选中的pod，发现成功访问

```bash
kubectl exec -it pod-default -- wget 172.16.152.74
Connecting to 172.16.152.74 (172.16.152.74:80)
saving to 'index.html'
index.html           100% |********************************|    45  0:00:00 ETA
'index.html' saved
```

访问被网络策略选中的pod，发现无法访问

```bash
kubectl exec -it pod-default -- wget 172.16.152.73
Connecting to 172.16.152.73 (172.16.152.73:80)
```

# 监控与升级

## 部署Metrics

```bash
kubectl apply -f https://gitee.com/cnlxh/Kubernetes/raw/master/cka-yaml/metrics-components.yaml
```

部署好之后，执行kubectl top 命令时就会返回结果了

```bash
kubectl top nodes
NAME                    CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
cka-master              142m         3%     1725Mi          45%       
cka-worker1             150m         3%     1024Mi          27%       
cka-worker2             53m          1%     995Mi           26%       

kubectl top pod
NAME                               CPU(cores)   MEMORY(bytes)   
lixiaohui-mq4sp                    0m           0Mi             
lixiaohui-qjlwt                    0m           0Mi             
lixiaohui-sm6pp                    0m           0Mi             
```

## 部署Prometheus

手工部署较为复杂，我们采用operator进行部署，先克隆它的operator，本次采用的是0.11.0版本

```bash
wget https://gitee.com/cnlxh/Kubernetes/raw/master/files/kube-prometheus-v0.11.0.tar.gz
tar xf kube-prometheus-v0.11.0.tar.gz
cd kube-prometheus-0.11.0
kubectl create -f manifests/setup/
```

测试是否符合条件，如果上一步全部成功，这里会显示全部符合

```bash
kubectl wait --for condition=Established --all CustomResourceDefinition --namespace=monitoring
```

准备容器镜像，全选复制即可，此处会产生大量网络流量，需要较长时间，请耐心等待，推荐在所有节点都下载镜像

```bash
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus-adapter:v0.9.1 
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/alertmanager:v0.24.0 
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/kube-state-metrics:v2.5.0 
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/kube-rbac-proxy:v0.12.0 
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/grafana:8.5.5 
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus:v2.36.1 
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus-operator:v0.57.0 
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/node-exporter:v1.3.1 
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/blackbox-exporter:v0.21.0 
docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/configmap-reload:v0.5.0 
   
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus-adapter:v0.9.1 k8s.gcr.io/prometheus-adapter/prometheus-adapter:v0.9.1
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/alertmanager:v0.24.0 quay.io/prometheus/alertmanager:v0.24.0
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/kube-state-metrics:v2.5.0 k8s.gcr.io/kube-state-metrics/kube-state-metrics:v2.5.0
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/kube-rbac-proxy:v0.12.0 quay.io/brancz/kube-rbac-proxy:v0.12.0
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/grafana:8.5.5 grafana/grafana:8.5.5
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus:v2.36.1 quay.io/prometheus/prometheus:v2.36.1
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus-operator:v0.57.0 quay.io/prometheus-operator/prometheus-operator:v0.57.0
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/node-exporter:v1.3.1 quay.io/prometheus/node-exporter:v1.3.1
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/blackbox-exporter:v0.21.0 quay.io/prometheus/blackbox-exporter:v0.21.0
docker tag registry.cn-shanghai.aliyuncs.com/cnlxh/configmap-reload:v0.5.0 jimmidyson/configmap-reload:v0.5.0
   
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus-adapter:v0.9.1 
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/alertmanager:v0.24.0 
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/kube-state-metrics:v2.5.0 
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/kube-rbac-proxy:v0.12.0 
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/grafana:8.5.5 
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus:v2.36.1 
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/prometheus-operator:v0.57.0 
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/node-exporter:v1.3.1 
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/blackbox-exporter:v0.21.0 
docker rmi registry.cn-shanghai.aliyuncs.com/cnlxh/configmap-reload:v0.5.0 

```

默认情况下，grafana等各个组件都提供了网络策略，无法被外部访问，我们先删除grafana的策略，并修改它的服务暴露方式为NodePort，因为我们要从外部访问它的图表面板

```bash
rm -rf manifests/grafana-networkPolicy.yaml
sed -i '/spec:/a\  type: NodePort' manifests/grafana-service.yaml
sed -i '/targetPort/a\    nodePort: 32000' manifests/grafana-service.yaml
kubectl apply -f manifests/
```

确定grafana所在节点，我们已经定义了32000端口，可以看出目前工作在worker1节点上，直接打开浏览器访问

```bash
kubectl get pod -n monitoring -o wide | grep grafana
grafana-67b774cb88-4kf9c ... cka-worker1

kubectl get service -n monitoring grafana
NAME      TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
grafana   NodePort   10.99.168.64   <none>        3000:32000/TCP   30m
```

配置好解析后，在浏览器中打开http://cka-worker1:32000，或者不配置解析用IP也可以

用户名和密码都是admin，点击login之后会让你修改新密码，进行修改后点击submit或直接点击skip不修改

![](https://gitee.com/cnlxh/Kubernetes/raw/master/images/Prometheus/grafana-login.png)

点击左侧的+号，选择import导入k8s模板

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
apt list kubeadm -a
Listing... Done
kubeadm/kubernetes-xenial,now 1.24.0-00 amd64 [installed]
kubeadm/kubernetes-xenial 1.23.6-00 amd64
kubeadm/kubernetes-xenial 1.23.5-00 amd64
```

在上一步可以看到一个可用的列表，假设我们要升级的目标为1.24.0-00的版本

禁止Master节点接收新调度

```bash
kubectl cordon cka-master
kubectl get nodes
NAME                    STATUS                     ROLES           AGE     VERSION
cka-master              Ready,SchedulingDisabled   control-plane   7h38m   v1.24.0
cka-worker1             Ready                      worker          7h2m    v1.24.0
cka-worker2             Ready                      worker          7h2m    v1.24.0
```

驱逐Master节点上的现有任务

```bash
kubectl drain cka-master --ignore-daemonsets --delete-emptydir-data

node/cka-master already cordoned
WARNING: ignoring DaemonSet-managed Pods: default/lixiaohui-mq4sp, kube-system/calico-node-xzhwb, kube-system/kube-proxy-8nnfn
evicting pod kube-system/coredns-7f74c56694-nwqzc
evicting pod default/nginx-deployment-66b957f9d-ph8d6
evicting pod kube-system/coredns-7f74c56694-7q797
evicting pod default/nginxrstest-zqllq
evicting pod default/nginxrstest-4tms8
```

安装目标的kubeadm、kubelet、kubectl

```bash
apt-get update
apt-get install -y kubelet=1.24.0-00 kubeadm=1.24.0-00 kubectl=1.24.0-00
```

查看可升级的列表并升级

```bash
kubeadm upgrade plan
kubeadm upgrade apply v1.24.0  --etcd-upgrade=false

[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
...
[upgrade/confirm] Are you sure you want to proceed with the upgrade? [y/N]:  y
[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.24.0". Enjoy!
[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```

恢复Master节点的调度能力

```bash
systemctl restart kubelet
kubectl uncordon cka-master
kubectl get nodes
NAME                    STATUS   ROLES           AGE     VERSION
cka-master              Ready    control-plane   7h48m   v1.24.0
cka-worker1             Ready    worker          7h12m   v1.24.0
cka-worker2             Ready    worker          7h12m   v1.24.0
```

# Helm 部署实践

官方网址 http://helm.sh

## Helm安装

下载安装Helm

```bash
wget https://ghproxy.com/https://raw.githubusercontent.com/cnlxh/coursefile/main/helm-v3.10.2-linux-amd64.tar.gz

tar xf helm-v3.10.2-linux-amd64.tar.gz
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

## 从仓库中安装软件

本次安装一个wordpress

```bash
helm search repo wordpress
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
azurerepo/wordpress     9.0.3           5.3.2           DEPRECATED Web publishing platform for building...
```

安装

这一步将安装mariadb和wordpress，我们这里用的是存储章节设置的默认存储类，所以会自动创建pv以及pvc，如果是打算自己创建pv、pvc，就需要修改values.yaml

```bash
helm install wordpress azurerepo/wordpress
```

查询服务端口

```bash
kubectl get service

NAME                TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
wordpress           LoadBalancer   10.102.156.226   <pending>     80:31194/TCP,443:30386/TCP   3m42s
wordpress-mariadb   ClusterIP      10.106.8.85      <none>        3306/TCP                     3m42s
```

查询pod所在节点

```bash
root@cka-master:~# kubectl get pod -o wide
NAME                                      READY   STATUS      RESTARTS   AGE    IP               NODE          NOMINATED NODE   READINESS GATES
nfs-client-provisioner-598cf75b45-kflwb   1/1     Running     0          133m   172.16.200.248   cka-master    <none>           <none>
pod-default                               0/1     Completed   0          82m    172.16.93.198    cka-worker1   <none>           <none>
wordpress-78d6fd4d6b-jt4pp                1/1     Running     0          107s   172.16.93.201    cka-worker1   <none>           <none>
wordpress-mariadb-0                       1/1     Running     0          107s   172.16.245.6     cka-worker2   <none>           <none>
```
可以看到wordpress在cka-worker1上，直接打开浏览器，访问31194或30386端口都可以，例如:

```bash
http://cka-worker1:31194
```

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

2022-05-21 22:38:15.878455 I | mvcc: restore compact to 30118
2022-05-21 22:38:15.884564 I | etcdserver/membership: added member 8e9e05c52164694d [http://localhost:2380] to cluster cdf818194e3a8c32

# 恢复服务

mv /etc/kubernetes/manifests.bak /etc/kubernetes/manifests

systemctl restart kubelet.service

# 验证数据已经恢复

kubectl get pod

```

检查etcd是否健康

```bash
ETCDCTL_API=3 etcdctl --endpoints=https://192.168.30.130:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key endpoint health

https://127.0.0.1:2379 is healthy: successfully committed proposal: took = 883.786µs
```
