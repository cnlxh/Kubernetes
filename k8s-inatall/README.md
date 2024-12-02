```textile
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```
**以下所有内容，请用root账号完成**

**请确保在做以下内容之前，3台机器已经恢复了最干净的快照或刚安装完操作系统**

本脚本仅支持Ubuntu 20.04系统

# 准备hosts解析

在所有机器上执行，请务必确保以下3个机器已经安装下面的对应表设置了特定的IP和主机名，IP和主机名必须是这样的，不能改

```bash
cat >> /etc/hosts <<EOF
192.168.8.3 k8s-master
192.168.8.4 k8s-worker1
192.168.8.5 k8s-worker2
EOF
```

# 设置统一密码

在所有机器上执行，密码必须是vagrant，不喜欢可以在部署结束之后再改

```bash
echo root:vagrant | chpasswd
```

# 准备SSH配置文件

在所有机器上执行

```bash
# 打开这个文件，添加下面这个参数

vim /etc/ssh/sshd_config
...
PermitRootLogin yes
...

# 以上是手工方式，如果已经用普通账户通过ssh工具连接了系统，可以执行以下方法自动高效实现

sudo -i
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

```

# 部署集群

完成所有上述任务后，执行下面两个命令，将自动在3个机器上完成集群部署

这里的脚本必须要在我的docker容器镜像加速器开启的情况下才可以安装成功，详情打开以下网页查询：

```text
https://registry.credclouds.com/
```

再次提醒，必须是3个固定的主机名、IP、root密码的干净虚拟机状态，而且如果脚本执行过程中有任何的失败，这3个机器都必须要恢复到脚本没运行之前的状态，然后重新开始执行脚本，而不能在不恢复虚拟机干净状态的情况下重新执行脚本，除非你具有一定的调试能力

docker版本

```bash
wget https://gitee.com/cnlxh/Kubernetes/raw/master/k8s-inatall/Create-K8S-With-Docker.sh

bash Create-K8S-With-Docker.sh

```

containerd版本

```bash
wget https://gitee.com/cnlxh/Kubernetes/raw/master/k8s-inatall/Create-K8S-With-Containerd.sh

bash Create-K8S-With-Containerd.sh

```