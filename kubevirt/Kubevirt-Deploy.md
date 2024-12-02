```textile
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```

# 先决条件要求

1. 已经安装了最新版的Kubernetes集群
1. 在Kubernetes集群的`apiserver`组件中，必须有`--allow-privileged=true`的启动参数
1. 具有`kubectl`客户端且具有Kubernetes管理权限
1. 推荐使用`containerd`作为运行时，其他的应该也行，但`containerd`是确定支持的
1. 所有节点都支持虚拟化功能
1. 在启用SElinux的节点上，要安装`Container-selinux`软件包

# 验证先决条件

1. 验证集群是否正常

确认没问题，都是Ready

```bash
kubectl get nodes
```
输出
```text
NAME          STATUS   ROLES           AGE   VERSION
k8s-master    Ready    control-plane   28d   v1.30.0
k8s-worker1   Ready    worker          28d   v1.30.0
k8s-worker2   Ready    worker          28d   v1.30.0
```

2. 确认apiserver参数

确认没问题，具有`--allow-privileged=true`参数

```bash
kubectl describe pod -n kube-system kube-apiserver-k8s-master | grep -i Command -A 10
```
输出
```text
Command:
  kube-apiserver
  --advertise-address=192.168.8.3
  --allow-privileged=true
  --authorization-mode=Node,RBAC
  --client-ca-file=/etc/kubernetes/pki/ca.crt
  --enable-admission-plugins=NodeRestriction
  --enable-bootstrap-token-auth=true
  --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
  --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
  --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
```

4. 验证虚拟化功能

```bash
apt update
apt install libvirt-clients -y
```

```bash
virt-host-validate qemu
```
输出
```text
QEMU: Checking for hardware virtualization                                 : PASS
QEMU: Checking if device /dev/kvm exists                                   : PASS
QEMU: Checking if device /dev/kvm is accessible                            : PASS
QEMU: Checking if device /dev/vhost-net exists                             : PASS
QEMU: Checking if device /dev/net/tun exists                               : PASS
QEMU: Checking for cgroup 'cpu' controller support                         : PASS
QEMU: Checking for cgroup 'cpuacct' controller support                     : PASS
QEMU: Checking for cgroup 'cpuset' controller support                      : PASS
QEMU: Checking for cgroup 'memory' controller support                      : PASS
QEMU: Checking for cgroup 'devices' controller support                     : PASS
QEMU: Checking for cgroup 'blkio' controller support                       : PASS
QEMU: Checking for device assignment IOMMU support                         : PASS
```

# 安装KubeVirt

在这里可以找到最新版

```text
https://github.com/kubevirt/kubevirt/releases/
```

安装operator

```bash
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v1.2.2/kubevirt-operator.yaml
```

# 创建KubeVirt CR

```bash
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v1.2.2/kubevirt-cr.yaml
```

创建了CR之后，会触发operator的真实安装，安装可能需要一定的时间，继续等待

可以看到pod正在初始化

```bash
kubectl get pod -n kubevirt
```
输出
```text
NAME                               READY   STATUS              RESTARTS   AGE
virt-api-75859b7b7-7gj6h           1/1     Running             0          58s
virt-api-75859b7b7-p5n5w           1/1     Running             0          58s
virt-controller-6855b4df79-jn2sv   0/1     ContainerCreating   0          23s
virt-controller-6855b4df79-tnc2n   0/1     ContainerCreating   0          23s
virt-handler-hx5lz                 0/1     PodInitializing     0          23s
virt-handler-zx6rl                 0/1     Init:0/1            0          23s
virt-operator-56d79bb8bd-4gzr4     1/1     Running             0          2m21s
virt-operator-56d79bb8bd-fwxhv     1/1     Running             0          2m21s

```

用下面的命令来验证是否安装完毕

```bash
kubectl -n kubevirt wait kv kubevirt --for condition=Available
```
输出
```text
kubevirt.kubevirt.io/kubevirt condition met
```

看到`condition met`就说明安装好了，我们后面可以测试一下虚拟机的创建和运行

# 安装virtctl

virtctl用于命令行控制虚拟机

```bash
wget -O /usr/bin/virtctl https://github.com/kubevirt/kubevirt/releases/download/v1.2.2/virtctl-v1.2.2-linux-amd64

chmod +x /usr/bin/virtctl
```

# 创建虚拟机测试

用测试的yaml来创建,复制粘贴以下代码创建yaml

```yaml
cat > testvm.yml <<'EOF'
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: testvm
spec:
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/size: small
        kubevirt.io/domain: testvm
    spec:
      domain:
        devices:
          disks:
            - name: containerdisk
              disk:
                bus: virtio
            - name: cloudinitdisk
              disk:
                bus: virtio
          interfaces:
          - name: default
            masquerade: {}
        resources:
          requests:
            memory: 64M
      networks:
      - name: default
        pod: {}
      volumes:
        - name: containerdisk
          containerDisk:
            image: quay.io/kubevirt/cirros-container-disk-demo
        - name: cloudinitdisk
          cloudInitNoCloud:
            userDataBase64: SGkuXG4=
EOF
```

创建虚拟机

```bash
kubectl apply -f testvm.yml
```

# 查询虚拟机

```bash
kubectl get vms
```
输出
```
NAME     AGE   STATUS    READY
testvm   23s   Stopped   False
```

# 启动虚拟机

```bash
virtctl start testvm
```
起来之后再查一下vm状态

```bash
kubectl get vm
```
输出
```text
NAME     AGE     STATUS    READY
testvm   5m43s   Running   True
```

```bash
kubectl get virtualmachineinstances
```
输出
```text
NAME     AGE   PHASE     IP              NODENAME      READY
testvm   85s   Running   172.16.194.70   k8s-worker1   True
```

# 连接虚拟机控制台

```bash
virtctl console testvm
```
输出
```text
Successfully connected to testvm console. The escape sequence is ^]

login as 'cirros' user. default password: 'gocubsgo'. use 'sudo' for root.
testvm login: `cirros`
Password:
$ `ls /`
bin         home        lib64       mnt         root        tmp
boot        init        linuxrc     old-root    run         usr
dev         initrd.img  lost+found  opt         sbin        var
etc         lib         media       proc        sys         vmlinuz
```

上面我用它提示的用户名和密码登录了，如果要退出要使用`ctrl+]`快捷键

这种方法不方便，我们可以用IP试试ssh

```bash
ssh cirros@172.16.194.70
```
输出
```text
cirros@172.16.194.70's password:
$ ls /
bin         dev         home        initrd.img  lib64       lost+found  mnt         opt         root        sbin        tmp         var
boot        etc         init        lib         linuxrc     media       old-root    proc        run         sys         usr         vmlinuz
$ exitConnection to 172.16.194.70 closed.
```

# 关闭虚拟机

```bash
virtctl stop testvm
```

# 删除虚拟机

```bash
kubectl delete vm testvm
```