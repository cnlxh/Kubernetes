```textile
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```
**以下所有内容，请用root账号完成**

**请确保在做以下内容之前，3台机器已经恢复了最干净的快照或刚安装完操作系统**


# 准备hosts解析

在所有机器上执行，请务必确保以下3个机器已经安装下面的对应表设置了特定的IP和主机名，IP和主机名必须是这样的

```bash
cat >> /etc/hosts <<EOF
192.168.30.130 cka-master
192.168.30.131 cka-worker1
192.168.30.132 cka-worker2
EOF
```

# 设置统一密码

在所有机器上执行，密码必须是1，不喜欢可以在部署结束之后再改

```bash
echo root:1 | chpasswd
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

```bash
wget https://gitee.com/cnlxh/Kubernetes/raw/master/Create-K8S-With-Docker.sh

bash Create-K8S-With-Docker.sh

```
