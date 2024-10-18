```textile
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```

| 角色                | IP             | 主机名                     | 操作系统平台     | 软件版本              |硬件配置|
| ----------------- | -------------- | ----------------------- | ---------- | ----------------- | ----------------- |
| k8s-master<br>etcd<br>haproxy<br>keepalived | 主要IP：192.168.8.3<br>keepalived vip: 192.168.8.200 | k8s-master01.xiaohui.cn | Ubuntu 22.04.4 | kubernetes 1.31.1<br>haproxy 3.0.5<br>Keepalived 2.3.1 |CPU: 2核心以上<br>内存：4G以上<br>硬盘：100G以上|
| k8s-master<br>etcd<br>haproxy<br>keepalived | 主要IP：192.168.8.4<br>keepalived vip: 192.168.8.200 | k8s-master02.xiaohui.cn | Ubuntu 22.04.4 | kubernetes 1.31.1<br>haproxy 3.0.5<br>Keepalived 2.3.1 |CPU: 2核心以上<br>内存：4G以上<br>硬盘：100G以上|
| k8s-master<br>etcd<br>haproxy<br>keepalived | 主要IP：192.168.8.5<br>keepalived vip: 192.168.8.200 | k8s-master03.xiaohui.cn | Ubuntu 22.04.4 | kubernetes 1.31.1<br>haproxy 3.0.5<br>Keepalived 2.3.1 |CPU: 2核心以上<br>内存：4G以上<br>硬盘：100G以上|
| k8s-master<br>etcd<br>haproxy<br>keepalived | 主要IP：192.168.8.6<br>keepalived vip: 192.168.8.200 | k8s-master04.xiaohui.cn | Ubuntu 22.04.4 | kubernetes 1.31.1<br>haproxy 3.0.5<br>Keepalived 2.3.1 |CPU: 2核心以上<br>内存：4G以上<br>硬盘：100G以上|
| k8s-worker        | 主要IP：192.168.8.7 | k8s-worker01.xiaohui.cn | Ubuntu 22.04.4 | kubernetes 1.31.1 |CPU: 2核心以上<br>内存：2G以上<br>硬盘：100G以上<br>仅供参考，以负载为准|

这里是k8s-master04只是用于演示在token过期后，还怎么将master加入到集群，所以你可以认为本文档提供的是3节点的控制平面部署指南

# 文档拓扑描述

流量走向：Client--->Keepalived vip--->Haproxy--->--->K8s-master

![architecture-ha-k8s-cluster](https://gitee.com/cnlxh/Kubernetes/raw/master/images/k8s/kubeadm-ha-topology-stacked-etcd.svg)

# 添加域名解析

**我的k8s-master04只是用于演示token过期后，如何加入更多节点而已，你集群的master最好是奇数个机器**

```bash
cat << EOF >> /etc/hosts
192.168.8.3 k8s-master01.xiaohui.cn k8s-master01
192.168.8.4 k8s-master02.xiaohui.cn k8s-master02
192.168.8.5 k8s-master03.xiaohui.cn k8s-master03
192.168.8.6 k8s-master04.xiaohui.cn k8s-master04
192.168.8.7 k8s-worker01.xiaohui.cn k8s-worker01
EOF
```
分别给每个主机设置主机名，我这里以第一个master举例

```bash
hostnamectl hostname k8s-master01.xiaohui.cn
```

# 部署 Haproxy服务

Haproxy 在这里承担了K8S Master节点之间的负载均衡角色，需要在所有的控制平面机器上都安装

## 安装haproxy最新版

这里可以找到最新版的haproxy

```text
https://github.com/haproxy/haproxy/tags
```
我写文章的时候，最新版是3.0.5，我用我自己的仓库做了加速，你用的时候在上面的链接找最新版

```bash
wget https://gitee.com/cnlxh/Kubernetes/raw/master/files/k8s/haproxy-3.0.5.tar.gz
tar xf haproxy-3.0.5.tar.gz
```

编译安装的时候还需要lua支持，最新版可以在下面的网址找到最新版

```text
https://www.lua.org/
```

```bash
wget https://gitee.com/cnlxh/Kubernetes/raw/master/files/k8s/lua-5.4.7.tar.gz
tar xf lua-5.4.7.tar.gz
```

编译安装需要有make和gcc支持

```bash
apt update
apt install make gcc -y
```

编译安装lua

```bash
cd lua-5.4.7/
make
make install
cd
```

为haproxy准备编译先决条件

执行这个apt install有可能会跳出界面让你选择，你可以用上下键选择，用空格勾选所有，然后tab键选中ok并回车

```bash
cd haproxy-3.0.5/
apt install libpcre2-dev libssl-dev -y
```

编译安装haproxy

```bash
make -j $(nproc) TARGET=linux-glibc \
USE_OPENSSL=1 USE_QUIC=1 USE_QUIC_OPENSSL_COMPAT=1 \
USE_LUA=1 USE_PCRE2=1
```

```
make install
cd
```

## 准备haproxy配置文件

这里要注意，你在文本最后将k8s-master04这台机器加入到k8s集群确认没问题后，将其他所有master机器上的haproxy配置文件都更新一下，包含新的控制节点

```bash
mkdir /etc/haproxy /var/lib/haproxy

cat << EOF > /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 1
    timeout http-request    10s
    timeout queue           20s
    timeout connect         5s
    timeout client          20s
    timeout server          20s
    timeout http-keep-alive 10s
    timeout check           10s
frontend k8s-api
    bind *:64433 #非并置的情况下，这里写6443和k8s更一致
    mode tcp
    option tcplog
    default_backend apiserver
backend apiserver
    option httpchk GET /healthz
    http-check expect status 200
    mode tcp
    option ssl-hello-chk
    balance     roundrobin
        server k8s-master01 k8s-master01.xiaohui.cn:6443 check
        server k8s-master02 k8s-master02.xiaohui.cn:6443 check
        server k8s-master03 k8s-master03.xiaohui.cn:6443 check
        server k8s-master04 k8s-master04.xiaohui.cn:6443 check
EOF
```

```textile
cat << EOF > /etc/systemd/system/haproxy.service
[Unit]
Description=HAProxy Load Balancer
After=syslog.target network.target
[Service]
ExecStartPre=/usr/local/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c -q
ExecStart=/usr/local/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -p /var/lib/haproxy/haproxy.pid
ExecReload=/bin/kill -USR2 $MAINPID
[Install]
WantedBy=multi-user.target
EOF
```

## 启动haproxy服务

```bash
systemctl daemon-reload
systemctl enable haproxy --now
```

# 部署 Keepalived服务

keepalived提供了一个虚拟IP，需要在所有的控制平面都安装

## 安装依赖包

```bash
apt install -y build-essential pkg-config automake autoconf libxtables-dev libip4tc-dev libip6tc-dev libipset-dev libnl-3-dev libnl-genl-3-dev libssl-dev libipset-dev libnl-3-dev libnl-genl-3-dev libssl-dev libmagic-dev libsnmp-dev libglib2.0-dev libpcre2-dev libnftnl-dev libmnl-dev libsystemd-dev libkmod-dev libnm-dev ipset ipvsadm
```

这里是apt install有可能会弹窗提醒内核升级，请直接在ok处回车，然后对涉及到的机器执行reboot操作，哪怕没有弹出，我也建议对它重启一下，如果在ok处回车后，让你选择，和上面一样，全选后点击ok

```bash
reboot
```

## 编译安装keepalived

```bash
git clone https://gitee.com/cnlxh/keepalived.git
cd keepalived
./autogen.sh
```


```bash
./configure
```

```bash
make
make install
cd
```

## 准备keepalived配置文件

### 第一台

这是keepalived的检测脚本，主要是判断haproxy是否工作正常，这里需要注意你的网卡名称是否为ens33

```bash
cat <<- 'EOF' > /etc/keepalived/check_haproxy.sh
#!/bin/bash

# 检查 HAProxy 是否在运行
if systemctl is-active --quiet haproxy; then
    exit 0  # HAProxy 正常
else
    exit 1  # HAProxy 不正常
fi

EOF
```

以下为第一台keepalived配置文件

```bash
cat > /etc/keepalived/keepalived.conf <<- 'EOF'
global_defs {
   router_id K8S_VIP
}

vrrp_script check_haproxy {
    script "/etc/keepalived/check_haproxy.sh" #每个机器要一致
    interval 2
    weight 20 #这里的跨度要超越下面的priority，因为脚本返回0时，weight会直接加20
}

vrrp_instance VI_1 {
    state MASTER # 其他机器写成BACKUP
    interface ens33 # 注意每个机器的网卡名称
    virtual_router_id 51 #每个机器要一致
    priority 100 # 其他机器依次递减1就行
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111 #每个机器要一致
    }
    virtual_ipaddress {
        192.168.8.200 #每个机器要一致，这里是VIP
    }

    track_script {
        check_haproxy
    }

    accept
}
EOF
```

```bash
chmod +x /etc/keepalived/check_haproxy.sh
systemctl daemon-reload
systemctl enable keepalived --now
```

### 第二台

这是keepalived的检测脚本，主要是判断haproxy是否工作正常，这里需要注意你的网卡名称是否为ens33

```bash
cat <<- 'EOF' > /etc/keepalived/check_haproxy.sh
#!/bin/bash

# 检查 HAProxy 是否在运行
if systemctl is-active --quiet haproxy; then
    exit 0  # HAProxy 正常
else
    exit 1  # HAProxy 不正常
fi

EOF
```

以下为第二台keepalived配置文件

```bash
cat > /etc/keepalived/keepalived.conf <<- 'EOF'
global_defs {
   router_id K8S_VIP
}

vrrp_script check_haproxy {
    script "/etc/keepalived/check_haproxy.sh" #每个机器要一致
    interval 2
    weight 20 #这里的跨度要超越下面的priority，因为脚本返回0时，weight会直接加20
}

vrrp_instance VI_1 {
    state BACKUP # 其他机器写成BACKUP
    interface ens33 # 注意每个机器的网卡名称
    virtual_router_id 51 #每个机器要一致
    priority 99 # 其他机器依次递减1就行
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111 #每个机器要一致
    }
    virtual_ipaddress {
        192.168.8.200 #每个机器要一致，这里是VIP
    }

    track_script {
        check_haproxy
    }

    accept
}

EOF
```

```bash
chmod +x /etc/keepalived/check_haproxy.sh
systemctl daemon-reload
systemctl enable keepalived --now
```


### 第三台

这是keepalived的检测脚本，主要是判断haproxy是否工作正常，这里需要注意你的网卡名称是否为ens33

```bash
cat <<- 'EOF' > /etc/keepalived/check_haproxy.sh
#!/bin/bash

# 检查 HAProxy 是否在运行
if systemctl is-active --quiet haproxy; then
    exit 0  # HAProxy 正常
else
    exit 1  # HAProxy 不正常
fi

EOF
```

以下为第三台keepalived配置文件

```bash
cat > /etc/keepalived/keepalived.conf <<- 'EOF'
global_defs {
   router_id K8S_VIP
}

vrrp_script check_haproxy {
    script "/etc/keepalived/check_haproxy.sh" #每个机器要一致
    interval 2
    weight 20 #这里的跨度要超越下面的priority，因为脚本返回0时，weight会直接加20
}

vrrp_instance VI_1 {
    state BACKUP # 其他机器写成BACKUP
    interface ens33 # 注意每个机器的网卡名称
    virtual_router_id 51 #每个机器要一致
    priority 98 # 其他机器依次递减1就行
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111 #每个机器要一致
    }
    virtual_ipaddress {
        192.168.8.200 #每个机器要一致，这里是VIP
    }

    track_script {
        check_haproxy
    }

    accept
}

EOF
```

```bash
chmod +x /etc/keepalived/check_haproxy.sh
systemctl daemon-reload
systemctl enable keepalived --now
```

# 部署高可用Kubernetes

## 先决条件

先决条件的部分，在所有k8s节点都要完成

### 禁用交换分区

```bash
sed -ri 's/.*swap.*/#&/' /etc/fstab
swapoff -a
```

### 部署Docker和CRI-Docker

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
```

部署docker

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://mirrors.nju.edu.cn/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.nju.edu.cn/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

部署CRI-Docker

```bash
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.15/cri-dockerd_0.3.15.3-0.ubuntu-focal_amd64.deb
dpkg -i cri-dockerd_0.3.15.3-0.ubuntu-focal_amd64.deb
```

将镜像指引到国内

```bash
sed -i 's/ExecStart=.*/ExecStart=\/usr\/bin\/cri-dockerd --container-runtime-endpoint fd:\/\/ --network-plugin=cni --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com\/google_containers\/pause:3.10/' /lib/systemd/system/cri-docker.service
systemctl daemon-reload
systemctl restart cri-docker.service
systemctl enable cri-docker.service
```

### 安装kubeadm工具

```bash
cat > /etc/apt/sources.list.d/k8s.list <<EOF
deb https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.31/deb /
EOF
curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.31/deb/Release.key | apt-key add -
apt-get update
apt-get install -y kubelet kubeadm kubectl socat
apt-mark hold kubelet kubeadm kubectl
```

添加命令自动补齐功能

```bash
kubectl completion bash > /etc/bash_completion.d/kubectl
kubeadm completion bash > /etc/bash_completion.d/kubeadm
source /etc/bash_completion.d/kubectl
source /etc/bash_completion.d/kubeadm
```

集成CRI-Docker

```bash
crictl config runtime-endpoint unix:///run/cri-dockerd.sock
crictl images
```

### 允许 iptables 检查桥接流量

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

## 集群部署

这个部署只在第一台k8s-master01完成，其他的master稍后以join的方式加入到集群中

```bash
kubeadm init \
--apiserver-advertise-address=192.168.8.3 \
--apiserver-bind-port=6443 \
--control-plane-endpoint=192.168.8.200:64433 \
--image-repository=registry.cn-hangzhou.aliyuncs.com/google_containers \
--kubernetes-version=v1.31.1 \
--service-cidr=10.96.0.0/12 \
--service-dns-domain=lixiaohui.cn \
--cri-socket unix:///var/run/cri-dockerd.sock \
--upload-certs
```
部分输出内容:

```text

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
...

You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join 192.168.8.200:64433 --token cal8xp.zu8r2wwg0f6z9vc0 \
        --discovery-token-ca-cert-hash sha256:3a8863076a7948c7e55c27d185bbfd82f0d790ca28ccf3196684a032114e939d \
        --control-plane --certificate-key 781a9ef6424708489dfebe056bdc02452842a0a3b9220dd568e8b8f080a912d5
...
Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.8.200:64433 --token cal8xp.zu8r2wwg0f6z9vc0 \
        --discovery-token-ca-cert-hash sha256:3a8863076a7948c7e55c27d185bbfd82f0d790ca28ccf3196684a032114e939d

```

## 加入更多Master

所有的Master节点都必须得完成本地hosts添加、Haproxy、Keepalived部署，以及k8s部署的所有先决条件，请注意在haproxy的后端添加包含新节点的所有后端，在keepalived配置文件中的优先级继续减1


第二台和第三台都输入下面的命令即可，下面的命令也是从第一台部署好之后的输出中复制粘贴的，注意加了--cri-socket参数

```bash
kubeadm join 192.168.8.200:64433 --token cal8xp.zu8r2wwg0f6z9vc0 \
        --discovery-token-ca-cert-hash sha256:3a8863076a7948c7e55c27d185bbfd82f0d790ca28ccf3196684a032114e939d \
        --control-plane --certificate-key 781a9ef6424708489dfebe056bdc02452842a0a3b9220dd568e8b8f080a912d5 \
        --cri-socket unix:///var/run/cri-dockerd.sock
```
输出内容：

```text

This node has joined the cluster and a new control plane instance was created:

* Certificate signing request was sent to apiserver and approval was received.
* The Kubelet was informed of the new secure connection details.
* Control plane label and taint were applied to the new node.
* The Kubernetes control plane instances scaled up.
* A new etcd member was added to the local/stacked etcd cluster.

To start administering your cluster from this node, you need to run the following as a regular user:

        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config

Run 'kubectl get nodes' to see this node join the cluster.
```

这个加入过程可能会有一些警告，不过只要在授予管理权限以及部署完calico网络后，获取节点状态和kube-system下的pod状态没问题就可以忽略警告

在每台上，都授予自己管理权限
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## 部署Calico网络插件

这个在任何一台master上做都行，只需要做一次，这里会从国外下载容器镜像，需要自己解决镜像下载问题

```bash
kubectl create -f https://docs.projectcalico.org/manifests/calico.yaml
```

在这里稍等一会儿，等待容器镜像下载完毕，在此期间，你可以用下面的方式查看系统pod，比如我的，可以看到还在努力初始化中，继续等待即可

```bash
root@k8s-master01:~# kubectl get pod -A
NAMESPACE     NAME                                              READY   STATUS              RESTARTS   AGE
kube-system   calico-kube-controllers-564b9d64dd-gsdv6          0/1     ContainerCreating   0          41s
kube-system   calico-node-hvn97                                 0/1     Init:2/3            0          41s
kube-system   calico-node-lh8q6                                 0/1     Init:2/3            0          41s
kube-system   calico-node-nrvzp                                 0/1     Init:2/3            0          41s
kube-system   coredns-fcd6c9c4-2qmdt                            0/1     ContainerCreating   0          7m35s
kube-system   coredns-fcd6c9c4-6gxq5                            0/1     ContainerCreating   0          7m35s
kube-system   etcd-k8s-master01.xiaohui.cn                      1/1     Running             0          7m40s
kube-system   etcd-k8s-master02.xiaohui.cn                      1/1     Running             0          3m50s
kube-system   etcd-k8s-master03.xiaohui.cn                      1/1     Running             0          3m43s
kube-system   kube-apiserver-k8s-master01.xiaohui.cn            1/1     Running             0          7m40s
kube-system   kube-apiserver-k8s-master02.xiaohui.cn            1/1     Running             0          3m50s
kube-system   kube-apiserver-k8s-master03.xiaohui.cn            1/1     Running             0          3m44s
kube-system   kube-controller-manager-k8s-master01.xiaohui.cn   1/1     Running             0          7m40s
kube-system   kube-controller-manager-k8s-master02.xiaohui.cn   1/1     Running             0          3m50s
kube-system   kube-controller-manager-k8s-master03.xiaohui.cn   1/1     Running             0          3m44s
kube-system   kube-proxy-4vpqw                                  1/1     Running             0          3m45s
kube-system   kube-proxy-rwbvv                                  1/1     Running             0          7m35s
kube-system   kube-proxy-tst26                                  1/1     Running             0          3m52s
kube-system   kube-scheduler-k8s-master01.xiaohui.cn            1/1     Running             0          7m40s
kube-system   kube-scheduler-k8s-master02.xiaohui.cn            1/1     Running             0          3m50s
kube-system   kube-scheduler-k8s-master03.xiaohui.cn            1/1     Running             0          3m43s

```

初始化好之后：

```bash
root@k8s-master01:~# kubectl get nodes
NAME                      STATUS   ROLES           AGE     VERSION
k8s-master01.xiaohui.cn   Ready    control-plane   8m19s   v1.31.1
k8s-master02.xiaohui.cn   Ready    control-plane   4m30s   v1.31.1
k8s-master03.xiaohui.cn   Ready    control-plane   4m23s   v1.31.1
root@k8s-master01:~# kubectl get pod -A
NAMESPACE     NAME                                              READY   STATUS    RESTARTS   AGE
kube-system   calico-kube-controllers-564b9d64dd-gsdv6          1/1     Running   0          82s
kube-system   calico-node-hvn97                                 1/1     Running   0          82s
kube-system   calico-node-lh8q6                                 1/1     Running   0          82s
kube-system   calico-node-nrvzp                                 1/1     Running   0          82s
kube-system   coredns-fcd6c9c4-2qmdt                            1/1     Running   0          8m16s
kube-system   coredns-fcd6c9c4-6gxq5                            1/1     Running   0          8m16s
kube-system   etcd-k8s-master01.xiaohui.cn                      1/1     Running   0          8m21s
kube-system   etcd-k8s-master02.xiaohui.cn                      1/1     Running   0          4m31s
kube-system   etcd-k8s-master03.xiaohui.cn                      1/1     Running   0          4m24s
kube-system   kube-apiserver-k8s-master01.xiaohui.cn            1/1     Running   0          8m21s
kube-system   kube-apiserver-k8s-master02.xiaohui.cn            1/1     Running   0          4m31s
kube-system   kube-apiserver-k8s-master03.xiaohui.cn            1/1     Running   0          4m25s
kube-system   kube-controller-manager-k8s-master01.xiaohui.cn   1/1     Running   0          8m21s
kube-system   kube-controller-manager-k8s-master02.xiaohui.cn   1/1     Running   0          4m31s
kube-system   kube-controller-manager-k8s-master03.xiaohui.cn   1/1     Running   0          4m25s
kube-system   kube-proxy-4vpqw                                  1/1     Running   0          4m26s
kube-system   kube-proxy-rwbvv                                  1/1     Running   0          8m16s
kube-system   kube-proxy-tst26                                  1/1     Running   0          4m33s
kube-system   kube-scheduler-k8s-master01.xiaohui.cn            1/1     Running   0          8m21s
kube-system   kube-scheduler-k8s-master02.xiaohui.cn            1/1     Running   0          4m31s
kube-system   kube-scheduler-k8s-master03.xiaohui.cn            1/1     Running   0          4m24s
```

## 重新生成加入master命令

第一台初始化好24小时后，token什么的就会失效，24小时后加入更多master或者worker节点可以用下面的方式，需要注意的是，新加入的所有节点，都必须完成所有关于部署k8s的先决条件

加入master除了需要token之外，还需要certificate key

在现有的master上，生成token和certificate key

```bash
root@k8s-master01:~# kubeadm token create --print-join-command
kubeadm join 192.168.8.200:64433 --token 7kr44t.1kqdkafjg6qn4xt8 --discovery-token-ca-cert-hash sha256:3a8863076a7948c7e55c27d185bbfd82f0d790ca28ccf3196684a032114e939d

root@k8s-master01:~# kubeadm init phase upload-certs --upload-certs
[upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[upload-certs] Using certificate key:
4891b13553af476533c06777da2050f9d66587dec1e6e8802cbfb394f3436065
```

把上面两个拼接起来，然后额外加入--certificate-key和--control-plane就行了，由于我们安装的是docker和cri-docker，所以还得加一个--cri-socket

```bash
kubeadm join 192.168.8.200:64433 --token 7kr44t.1kqdkafjg6qn4xt8 \
--discovery-token-ca-cert-hash sha256:3a8863076a7948c7e55c27d185bbfd82f0d790ca28ccf3196684a032114e939d \
--certificate-key 4891b13553af476533c06777da2050f9d66587dec1e6e8802cbfb394f3436065 \
--control-plane \
--cri-socket unix:///var/run/cri-dockerd.sock
```

授予自己管理权限

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

查询节点

```bash
root@k8s-master04:~# kubectl get nodes
NAME                      STATUS   ROLES           AGE   VERSION
k8s-master01.xiaohui.cn   Ready    control-plane   77m   v1.31.1
k8s-master02.xiaohui.cn   Ready    control-plane   73m   v1.31.1
k8s-master03.xiaohui.cn   Ready    control-plane   73m   v1.31.1
k8s-master04.xiaohui.cn   Ready    control-plane   17m   v1.31.1
```


## 加入worker节点

需要注意的是，每个需要加入的worker，也必须完成本地hosts添加和部署Kubernetes中的所有先决条件，不然不能加入

在现有的master上，生成token，worker节点不需要certificate key

```bash
root@k8s-master01:~# kubeadm token create --print-join-command
kubeadm join 192.168.8.200:64433 --token 6gcjwz.22942jco0ssof8f8 --discovery-token-ca-cert-hash sha256:3a8863076a7948c7e55c27d185bbfd82f0d790ca28ccf3196684a032114e939d
```

在新的worker节点加入

```bash
kubeadm join 192.168.8.200:64433 --token 6gcjwz.22942jco0ssof8f8 \
--discovery-token-ca-cert-hash sha256:3a8863076a7948c7e55c27d185bbfd82f0d790ca28ccf3196684a032114e939d \
--cri-socket unix:///var/run/cri-dockerd.sock
```

获取节点列表

给worker节点打上worker标签，并查询节点和pod

```bash
root@k8s-master01:~# kubectl label nodes k8s-worker01.xiaohui.cn node-role.kubernetes.io/Worker=
node/k8s-worker01.xiaohui.cn labeled

root@k8s-master01:~# kubectl get nodes
NAME                      STATUS   ROLES           AGE    VERSION
k8s-master01.xiaohui.cn   Ready    control-plane   87m    v1.31.1
k8s-master02.xiaohui.cn   Ready    control-plane   83m    v1.31.1
k8s-master03.xiaohui.cn   Ready    control-plane   83m    v1.31.1
k8s-master04.xiaohui.cn   Ready    control-plane   27m    v1.31.1
k8s-worker01.xiaohui.cn   Ready    Worker          104s   v1.31.1

root@k8s-master01:~# kubectl get pod -A
NAMESPACE     NAME                                              READY   STATUS    RESTARTS   AGE
kube-system   calico-kube-controllers-564b9d64dd-gsdv6          1/1     Running   0          80m
kube-system   calico-node-8m4g7                                 1/1     Running   0          27m
kube-system   calico-node-hvn97                                 1/1     Running   0          80m
kube-system   calico-node-lh8q6                                 1/1     Running   0          80m
kube-system   calico-node-nrvzp                                 1/1     Running   0          80m
kube-system   calico-node-zwwfz                                 1/1     Running   0          109s
kube-system   coredns-fcd6c9c4-2qmdt                            1/1     Running   0          87m
kube-system   coredns-fcd6c9c4-6gxq5                            1/1     Running   0          87m
kube-system   etcd-k8s-master01.xiaohui.cn                      1/1     Running   0          87m
kube-system   etcd-k8s-master02.xiaohui.cn                      1/1     Running   0          83m
kube-system   etcd-k8s-master03.xiaohui.cn                      1/1     Running   0          83m
kube-system   etcd-k8s-master04.xiaohui.cn                      1/1     Running   0          10m
kube-system   kube-apiserver-k8s-master01.xiaohui.cn            1/1     Running   0          87m
kube-system   kube-apiserver-k8s-master02.xiaohui.cn            1/1     Running   0          83m
kube-system   kube-apiserver-k8s-master03.xiaohui.cn            1/1     Running   0          83m
kube-system   kube-apiserver-k8s-master04.xiaohui.cn            1/1     Running   0          10m
kube-system   kube-controller-manager-k8s-master01.xiaohui.cn   1/1     Running   0          87m
kube-system   kube-controller-manager-k8s-master02.xiaohui.cn   1/1     Running   0          83m
kube-system   kube-controller-manager-k8s-master03.xiaohui.cn   1/1     Running   0          83m
kube-system   kube-controller-manager-k8s-master04.xiaohui.cn   1/1     Running   0          10m
kube-system   kube-proxy-4vpqw                                  1/1     Running   0          83m
kube-system   kube-proxy-bfl4c                                  1/1     Running   0          27m
kube-system   kube-proxy-mx2nq                                  1/1     Running   0          109s
kube-system   kube-proxy-rwbvv                                  1/1     Running   0          87m
kube-system   kube-proxy-tst26                                  1/1     Running   0          83m
kube-system   kube-scheduler-k8s-master01.xiaohui.cn            1/1     Running   0          87m
kube-system   kube-scheduler-k8s-master02.xiaohui.cn            1/1     Running   0          83m
kube-system   kube-scheduler-k8s-master03.xiaohui.cn            1/1     Running   0          83m
kube-system   kube-scheduler-k8s-master04.xiaohui.cn            1/1     Running   0          10m
```