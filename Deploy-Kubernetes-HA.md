| 角色                | IP             | 主机名                     | 操作系统平台     | 软件版本              |
| ----------------- | -------------- | ----------------------- | ---------- | ----------------- |
| k8s-master & etcd | 192.168.8.3 | k8s-master01.xiaohui.cn | CentOS 7.9 | kubernetes 1.25.0 |
| k8s-master & etcd | 192.168.8.4 | k8s-master02.xiaohui.cn | CentOS 7.9 | kubernetes 1.25.0 |
| k8s-master & etcd | 192.168.8.5 | k8s-master03.xiaohui.cn | CentOS 7.9 | kubernetes 1.25.0 |
| k8s-worker        | 192.168.30.131 | k8s-worker01.xiaohui.cn | CentOS 7.9 | kubernetes 1.25.0 |
| k8s-worker        | 192.168.30.132 | k8s-worker02.xiaohui.cn | CentOS 7.9 | kubernetes 1.25.0 |
| keepalived        | 192.168.30.200 | k8s-master01.xiaohui.cn | CentOS 7.9 | keepalived 2.2.7  |
| keepalived        | 192.168.30.200 | k8s-master02.xiaohui.cn | CentOS 7.9 | keepalived 2.2.7  |
| keepalived        | 192.168.30.200 | k8s-master03.xiaohui.cn | CentOS 7.9 | keepalived 2.2.7  |
| Haproxy           | 192.168.8.3 | k8s-master01.xiaohui.cn | CentOS 7.9 | haproxy 2.6.5     |
| Haproxy           | 192.168.8.4 | k8s-master02.xiaohui.cn | CentOS 7.9 | haproxy 2.6.5     |
| Haproxy           | 192.168.8.5 | k8s-master03.xiaohui.cn | CentOS 7.9 | haproxy 2.6.5     |
|                   |                |                         |            |                   |

# 文档拓扑描述

流量走向：Client--->Keepalived vip--->Haproxy--->--->K8s-master

![architecture-ha-k8s-cluster](https://kubesphere.io/images/docs/v3.3/installing-on-linux/high-availability-configurations/set-up-ha-cluster-using-keepalived-haproxy/architecture-ha-k8s-cluster.png)

# 部署 Haproxy服务

Haproxy 在这里承担了K8S Master节点之间的负载均衡角色，需要在所有的控制平面机器上都安装

## 添加域名解析

```bash
cat << EOF >> /etc/hosts
192.168.8.3 k8s-master01.xiaohui.cn k8s-master01
192.168.8.4 k8s-master02.xiaohui.cn k8s-master02
192.168.8.5 k8s-master03.xiaohui.cn k8s-master03
192.168.30.131 k8s-worker01.xiaohui.cn k8s-worker01
192.168.30.132 k8s-worker02.xiaohui.cn k8s-worker02
192.168.30.200 k8s.xiaohui.cn k8s
EOF
```

## 安装haproxy最新版

这里可以找到最新版的haproxy

```text
https://github.com/haproxy/haproxy/tags
```
我写文章的时候，最新版是3.0.0

```bash
wget https://github.com/haproxy/haproxy/archive/refs/tags/v3.0.0.tar.gz
tar xf tar xf v3.0.0.tar.gz
```

编译安装的时候还需要lua支持

```bash
wget https://www.lua.org/ftp/lua-5.4.7.tar.gz
tar xf lua-5.4.7.tar.gz
```

编译安装需要有make和gcc支持

```bash
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

```bash
cd haproxy-3.0.0/
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
frontend apiserver
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

## 准备软件包

```bash
wget https://www.keepalived.org/software/keepalived-2.3.1.tar.gz
tar xf keepalived-2.3.1.tar.gz
cd keepalived-2.3.1/
```

检测依赖包，正常来说，Ubuntu不需要额外做什么，会正常退出

```bash
./configure
```

```bash
make
make install
cd
```

## 准备keepalived配置文件

这是keepalived的检测脚本，主要是判断haproxy是否工作正常，这里需要注意你的网卡名称是否为ens32

```bash
mkdir /etc/keepalived
cat << EOF > /etc/keepalived/check_apiserver.sh
#!/bin/sh
systemctl is-active haproxy
if [ $? -eq 0 ];then
  exit 0
else
  ip link set ens32 down
fi
EOF
```

以下为第一台keepalived配置文件样例

```bash
cat << EOF > /etc/keepalived/keepalived.conf
global_defs {
    router_id lixiaohui
}
vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"
  interval 3
  weight -2
  fall 10
  rise 2
}

vrrp_instance haproxy {
    state MASTER     # 其他机器要写成BACKUP
    interface ens32
    virtual_router_id 20
    priority 100
    authentication {
        auth_type PASS
        auth_pass lixiaohui
    }
    unicast_src_ip 192.168.8.3 #本机地址
    unicast_peer {
        192.168.8.4 #对端地址
        192.168.8.5 #对端地址
    }
    virtual_ipaddress {
        192.168.8.200
    }
    track_script {
        check_apiserver
    }
}

EOF
```

```bash
cat << EOF > /etc/systemd/system/keepalived.service
[Unit]
Description=LVS and VRRP High Availability Monitor
After=network-online.target syslog.target haproxy.service
Wants=network-online.target
Documentation=man:keepalived(8)
Documentation=man:keepalived.conf(5)
Documentation=man:genhash(1)
Documentation=https://keepalived.org

[Service]
Type=notify
NotifyAccess=all
PIDFile=/run/keepalived.pid
KillMode=process
EnvironmentFile=-/usr/local/etc/sysconfig/keepalived
ExecStartPre=/bin/sh -c 'until systemctl is-active haproxy.service; do sleep 1; done'
ExecStart=/usr/local/sbin/keepalived --dont-fork $KEEPALIVED_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF
```

启动keepalived服务的部分先不执行，因为haproxy后端服务器现在全部离线，会导致haproxy服务失败，一旦haproxy服务失败，keepalived会自动断开你的网络，等最起码haproxy后端一台机器上线后再执行keepalived的启动

```bash
chmod +x /etc/keepalived/check_apiserver.sh
systemctl daemon-reload
systemctl enable keepalived --now
```

# 部署高可用Kubernetes

## 先决条件

### 禁用交换分区

```bash
sed -ri 's/.*swap.*/#&/' /etc/fstab
swapoff -a
```

### 部署Containerd

这里采用类docker的nerdctl，此工具包含containerd在内，但提供类docker的管理命令

```bash
wget https://github.com/containerd/nerdctl/releases/download/v0.22.2/nerdctl-full-0.22.2-linux-amd64.tar.gz
tar Cxzvvf /usr/local nerdctl-full-0.22.2-linux-amd64.tar.gz
```

#### 生成并编辑配置文件

更改文件内容的原因是因为国内无法连接Google

```bash
mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml
vim /etc/containerd/config.toml
...
# 如果是在国内部署，需要修改sandbox_image参数为阿里云，如果是海外的机器，就不需要修改sandbox_image
sandbox_image = "registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.6"
...
SystemdCgroup = true
...
# 添加加速器
[plugins."io.containerd.grpc.v1.cri".registry.mirrors]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
    endpoint = ["https://registry.cn-hangzhou.aliyuncs.com"]
```

```bash
systemctl enable --now containerd
```

## 安装kubeadm工具

```bash
cat << EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=kubernetes
baseurl=https://mirrors.tuna.tsinghua.edu.cn/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
EOF
setenforce 0
yum install -y kubelet kubeadm kubectl
systemctl enable kubelet && systemctl start kubelet
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
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

## 添加命令自动补齐功能

```bash
kubectl completion bash > /etc/bash_completion.d/kubectl
kubeadm completion bash > /etc/bash_completion.d/kubeadm
source /etc/bash_completion.d/kubectl
source /etc/bash_completion.d/kubeadm
```

## 集成Containerd

```bash
crictl config runtime-endpoint unix:///run/containerd/containerd.sock
crictl images
```

## 集群部署

下方kubeadm.yaml中name字段必须在网络中可被解析，也可以将解析记录添加到集群中所有机器的/etc/hosts中

```bash
kubeadm init \
--apiserver-advertise-address=192.168.8.3 \
--apiserver-bind-port=6443 \
--control-plane-endpoint=192.168.30.200:64433 \
--image-repository=registry.cn-hangzhou.aliyuncs.com/google_containers \
--kubernetes-version=v1.25.0 \
--service-cidr=10.96.0.0/12 \
--service-dns-domain=lixiaohui.cn \
--upload-certs
```

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## 部署Calico网络插件

```bash
kubectl create -f https://docs.projectcalico.org/manifests/calico.yaml
kubectl get nodes
NAME   STATUS   ROLES           AGE     VERSION
k8s    Ready    control-plane   3m20s   v1.25.0
```

## 加入更多master节点

在第一个master节点上，把证书传输到需要加入的节点上

```bash
ssh root@k8s-master02 mkdir /etc/kubernetes/pki/etcd -p
scp -rp /etc/kubernetes/pki/ca.* k8s-master02:/etc/kubernetes/pki
scp -rp /etc/kubernetes/pki/sa.* k8s-master02:/etc/kubernetes/pki
scp -rp /etc/kubernetes/pki/front-proxy-ca.* k8s-master02:/etc/kubernetes/pki
scp -rp /etc/kubernetes/pki/etcd/ca* k8s-master02:/etc/kubernetes/pki/etcd
scp -rp /etc/kubernetes/pki/etcd/healthcheck-client.* k8s-master02:/etc/kubernetes/pki/etcd
```

```bash
kubeadm join 192.168.30.200:64433 --token v22v7i.901fgfr55b5mbfd3 --control-plane --discovery-token-ca-cert-hash sha256:94f73076dc062e0eba6ac502a2c54c4500a7b3a3a9062d544fe1afaf881a73a3
```

## 加入worker节点

```bash
kubeadm join 192.168.30.200:64433 --token 389wbm.41yho95l251by9np --discovery-token-ca-cert-hash sha256:94f73076dc062e0eba6ac502a2c54c4500a7b3a3a9062d544fe1afaf881a73a3
```

```bash
kubectl label nodes k8s-worker01.xiaohui.cn node-role.kubernetes.io/Worker=
kubectl label nodes k8s-worker02.xiaohui.cn node-role.kubernetes.io/Worker=
kubectl get nodes
NAME                      STATUS   ROLES           AGE     VERSION
k8s-master01.xiaohui.cn   Ready    control-plane   37m     v1.25.0
k8s-master02.xiaohui.cn   Ready    control-plane   10m     v1.25.0
k8s-master03.xiaohui.cn   Ready    control-plane   6m4s    v1.25.0
k8s-worker01.xiaohui.cn   Ready    Worker          3m47s   v1.25.0
k8s-worker02.xiaohui.cn   Ready    Worker          3m56s   v1.25.0
```
