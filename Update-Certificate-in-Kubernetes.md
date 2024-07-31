```textile
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```

=====

**请勿使用本文操作，未经验证**



# 故障现象

将master和worker节点系统时间设置到2040年1月1日，模拟证书到期，发现集群无法做操作了，证书已到期

```bash
kubectl get pod

The connection to the server 172.16.50.100:6443 was refused - did you specify the right host or port?
```

```bash
tail -f /var/log/syslog

Jan  1 00:01:51 cka-master kubelet[1786]: I0101 00:01:51.994619    1786 server.go:825] "Client rotation is on, will bootstrap in background"
Jan  1 00:01:51 cka-master kubelet[1786]: E0101 00:01:51.996498    1786 bootstrap.go:265] part of the existing bootstrap client certificate in /etc/kubernetes/kubelet.conf is expired: 2023-10-16 08:26:30 +0000 UTC
```

发现已经全部到期了，需要注意的是连ca颁发机构都过期了，这个情况更严峻，CA都到期了，服务证书就没意义了，这种情况一般不会发生，因为服务证书默认情况下，也就一年有效期，而CA是10年有效期，但10年之后也面临CA过期的情况，所以我们干脆模拟全部到期，猝不及防

```bash
kubeadm certs check-expiration

[check-expiration] Reading configuration from the cluster...
[check-expiration] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[check-expiration] Error reading configuration from the Cluster. Falling back to default configuration

W0101 00:00:33.623568   87689 certs.go:524] WARNING: could not validate bounds for certificate CA: the certificate has expired: NotBefore: 2022-10-16 04:04:17 +0000 UTC, NotAfter: 2032-10-13 04:04:17 +0000 UTC
W0101 00:00:33.624637   87689 certs.go:524] WARNING: could not validate bounds for certificate etcd CA: the certificate has expired: NotBefore: 2022-10-16 04:04:19 +0000 UTC, NotAfter: 2032-10-13 04:04:19 +0000 UTC
W0101 00:00:33.625957   87689 certs.go:524] WARNING: could not validate bounds for certificate front-proxy CA: the certificate has expired: NotBefore: 2022-10-16 04:04:19 +0000 UTC, NotAfter: 2032-10-13 04:04:19 +0000 UTC
CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 Dec 31, 2032 00:03 UTC   <invalid>       ca                      no
apiserver                  Dec 31, 2032 00:03 UTC   <invalid>       ca                      no
apiserver-etcd-client      Dec 31, 2032 00:03 UTC   <invalid>       etcd-ca                 no
apiserver-kubelet-client   Dec 31, 2032 00:03 UTC   <invalid>       ca                      no
controller-manager.conf    Dec 31, 2032 00:03 UTC   <invalid>       ca                      no
etcd-healthcheck-client    Dec 31, 2032 00:03 UTC   <invalid>       etcd-ca                 no
etcd-peer                  Dec 31, 2032 00:03 UTC   <invalid>       etcd-ca                 no
etcd-server                Dec 31, 2032 00:03 UTC   <invalid>       etcd-ca                 no
front-proxy-client         Dec 31, 2032 00:03 UTC   <invalid>       front-proxy-ca          no
scheduler.conf             Dec 31, 2032 00:03 UTC   <invalid>       ca                      no

CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      Oct 13, 2032 04:04 UTC   <invalid>       no
etcd-ca                 Oct 13, 2032 04:04 UTC   <invalid>       no
front-proxy-ca          Oct 13, 2032 04:04 UTC   <invalid>       no
```

# 备份原有证书

以防万一，先备份一下

```bash
mkdir /k8scert
cp -a /etc/kubernetes/pki/ /k8scert/
```

# 制作新的CA证书

```bash
# create etcd-ca
openssl genrsa -out /etc/kubernetes/pki/etcd/ca.key 4096
openssl req -x509 -new -nodes -sha512 -days 3650 -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Company/OU=SH/CN=etcd-ca" \
-key /etc/kubernetes/pki/etcd/ca.key \
-out /etc/kubernetes/pki/etcd/ca.crt
# create kubernetes-ca
openssl genrsa -out /etc/kubernetes/pki/ca.key 4096
openssl req -x509 -new -nodes -sha512 -days 3650 -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Company/OU=SH/CN=kubernetes-ca" \
-key /etc/kubernetes/pki/ca.key \
-out /etc/kubernetes/pki/ca.crt
# create front-proxy-ca
openssl genrsa -out /etc/kubernetes/pki/front-proxy-ca.key 4096
openssl req -x509 -new -nodes -sha512 -days 3650 -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Company/OU=SH/CN=kubernetes-ca" \
-key /etc/kubernetes/pki/front-proxy-ca.key \
-out /etc/kubernetes/pki/front-proxy-ca.crt
```

# 更新服务证书

```bash
 kubeadm certs renew all

[renew] Reading configuration from the cluster...
[renew] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[renew] Error reading configuration from the Cluster. Falling back to default configuration

W0101 00:01:31.360344   87876 certs.go:524] WARNING: could not validate bounds for certificate CA: the certificate has expired: NotBefore: 2022-10-16 04:04:17 +0000 UTC, NotAfter: 2032-10-13 04:04:17 +0000 UTC
W0101 00:01:31.361285   87876 certs.go:524] WARNING: could not validate bounds for certificate ca: the certificate has expired: NotBefore: 2022-10-16 04:04:17 +0000 UTC, NotAfter: 2032-10-13 04:04:17 +0000 UTC
certificate embedded in the kubeconfig file for the admin to use and for kubeadm itself renewed
certificate for serving the Kubernetes API renewed
W0101 00:01:31.770046   87876 certs.go:524] WARNING: could not validate bounds for certificate etcd CA: the certificate has expired: NotBefore: 2022-10-16 04:04:19 +0000 UTC, NotAfter: 2032-10-13 04:04:19 +0000 UTC
W0101 00:01:31.770488   87876 certs.go:524] WARNING: could not validate bounds for certificate etcd/ca: the certificate has expired: NotBefore: 2022-10-16 04:04:19 +0000 UTC, NotAfter: 2032-10-13 04:04:19 +0000 UTC
certificate the apiserver uses to access etcd renewed
certificate for the API server to connect to kubelet renewed
certificate embedded in the kubeconfig file for the controller manager to use renewed
certificate for liveness probes to healthcheck etcd renewed
certificate for etcd nodes to communicate with each other renewed
certificate for serving etcd renewed
W0101 00:01:33.585045   87876 certs.go:524] WARNING: could not validate bounds for certificate front-proxy CA: the certificate has expired: NotBefore: 2022-10-16 04:04:19 +0000 UTC, NotAfter: 2032-10-13 04:04:19 +0000 UTC
W0101 00:01:33.585390   87876 certs.go:524] WARNING: could not validate bounds for certificate front-proxy-ca: the certificate has expired: NotBefore: 2022-10-16 04:04:19 +0000 UTC, NotAfter: 2032-10-13 04:04:19 +0000 UTC
certificate for the front proxy client renewed
certificate embedded in the kubeconfig file for the scheduler manager to use renewed

Done renewing certificates. You must restart the kube-apiserver, kube-controller-manager, kube-scheduler and etcd, so that they can use the new certificates.
```

# 查询新证书到期情况

现在看到下面的ca和上面的服务证书全都更新了

```bash
kubeadm certs check-expiration

[check-expiration] Reading configuration from the cluster...
[check-expiration] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[check-expiration] Error reading configuration from the Cluster. Falling back to default configuration

CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 Dec 31, 2040 00:05 UTC   364d            ca                      no
apiserver                  Dec 31, 2040 00:05 UTC   364d            ca                      no
apiserver-etcd-client      Dec 31, 2040 00:05 UTC   364d            etcd-ca                 no
apiserver-kubelet-client   Dec 31, 2040 00:05 UTC   364d            ca                      no
controller-manager.conf    Dec 31, 2040 00:05 UTC   364d            ca                      no
etcd-healthcheck-client    Dec 31, 2040 00:05 UTC   364d            etcd-ca                 no
etcd-peer                  Dec 31, 2040 00:05 UTC   364d            etcd-ca                 no
etcd-server                Dec 31, 2040 00:05 UTC   364d            etcd-ca                 no
front-proxy-client         Dec 31, 2040 00:05 UTC   364d            front-proxy-ca          no
scheduler.conf             Dec 31, 2040 00:05 UTC   364d            ca                      no

CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      Dec 29, 2049 00:03 UTC   9y              no
etcd-ca                 Dec 29, 2049 00:02 UTC   9y              no
front-proxy-ca          Dec 29, 2049 00:03 UTC   9y              no
```

# 重启系统组件

```bash
mv /etc/kubernetes/manifests/kube-scheduler.yaml /k8scert/
mv /etc/kubernetes/manifests/kube-controller-manager.yaml /k8scert/
mv /etc/kubernetes/manifests/kube-apiserver.yaml /k8scert/
mv /etc/kubernetes/manifests/etcd.yaml /k8scert/
sleep 30
mv /k8scert/kube-scheduler.yaml /etc/kubernetes/manifests/
mv /k8scert/kube-controller-manager.yaml /etc/kubernetes/manifests/
mv /k8scert/kube-apiserver.yaml /etc/kubernetes/manifests/
mv /k8scert/etcd.yaml /etc/kubernetes/manifests/ 
```

# 整理kubelet证书

这个时候，由于kubelet的证书没有恢复，所以集群还是不可以使用，从管理员配置文件中复制新密钥过来覆盖

```bash
grep client-certificate-data /etc/kubernetes/admin.conf | cut -d : -f 2 | tr -d ' ' > client.crt
grep client-key-data /etc/kubernetes/admin.conf | cut -d : -f 2 | tr -d ' ' > client.key
base64 -d client.crt > /var/lib/kubelet/pki/kubelet-client-current.pem
base64 -d client.key >> /var/lib/kubelet/pki/kubelet-client-current.pem
ca=`grep certificate-authority-data /etc/kubernetes/admin.conf | cut -d : -f 2 | tr -d " "`
sed -i "s/.*certificate-authority-data.*/    certificate-authority-data: $ca/" /etc/kubernetes/kubelet.conf
```

# 重启服务

```bash
systemctl restart kubelet
```

# 重新生成管理员配置文件

```bash
rm -rf /root/.kube
mkdir /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
```

# 更新Cluster-info证书信息

```bash
grep certificate-authority-data /etc/kubernetes/admin.conf | cut -d : -f 2 | tr -d " "
将grep出来的信息填写到certificate-authority-data后方，替换原有信息
kubectl edit cm -n kube-public cluster-info
```

# 生成节点加入命令

```bash
kubeadm token create --print-join-command
kubeadm join 172.16.50.100:6443 --token qme54v.gs2wksn04o2298g6 --discovery-token-ca-cert-hash sha256:b1ac46ff3574e683726335982193c6fa0e3871d56295734d2a4a49072e70b1b
```

# 重置worker节点

```bash
kubeadm reset -f
mv /etc/cni/net.d/* /mnt
iptables -F
```

# 重新加入worker节点

```bash
kubeadm join 172.16.50.100:6443 --token qme54v.gs2wksn04o2298g6 --discovery-token-ca-cert-hash sha256:b1ac46ff3574e683726335982193c6fa0e3871d56295734d2a4a49072e70b1b
```
