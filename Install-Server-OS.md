```textile
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```

# 资料下载

ISO 下载地址：

从以下链接下载文件：ubuntu-20.04.6-live-server-amd64.iso

```textile
http://mirrors.aliyun.com/ubuntu-releases/20.04.6/ubuntu-20.04.6-live-server-amd64.iso
```

VMware Workstation下载地址：

将链接复制到浏览器，即可自动开始下载，另外此为付费软件，可试用，本次课程使用试用版，如有必要，请支持正版

```textile
https://www.vmware.com/go/getworkstation-win
```

# 虚拟机

## 配置虚拟机网络

为了方便沟通，请确保和我的网络设定一致，在VMware软件左上角打开如下图所示

![vmnetedit](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/vmnetedit.png)

默认无法修改，请点击更改设置，请在弹出框中，点击“是”

![vmnetedit](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/changeset.png)

点击vmnet8，并确保vmnet8是nat类型，输入子网192.168.8.0，掩码255.255.255.0

![correctvmnet8](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/correctvmnet8.png)


## 新建虚拟机

**请注意，CKA课程至少需要3台虚拟机，新建虚拟机和安装系统步骤，请做3台虚拟机，而不要克隆，不然会导致后续课程异常**

安装好VMware软件之后，打开软件，点击菜单中的文件---新建

![new](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/new.png)

点击下一步

![welcome](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/welcome.png)

选择稍后安装系统

![source](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/source.png)

选择Linux---Ubuntu 64位

![os](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/os.png)

点击第一个选项，并在磁盘处输入200G

![disk](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/disksize.png)

点击完成

![finish](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/finish.png)

## 修改虚拟机配置

根据你的电脑性能修改虚拟机配置，推荐每台虚拟机的配置为4核心4G内存，如果你有更好的配置，请自行修改，但不要小于2G内存，请注意在DVD处，选择自己下载好的ISO镜像，并确保勾选在启动时连接

![resize](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/resize.png)

![resizeresult](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/resizeresult.png)

为避免安装时间过长，请在安装之前，断开VMware 网络连接，并在安装完成后，重新将其链接上恢复网络能力
![vmnetdis](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/vmnetdis.png)


# 操作系统

## 系统安装

在修改好虚拟机配置之后，点击打开虚拟机电源，稍等之后，会出现以下界面，请选择english，并回车

![welcome](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/server/welcome.png)

语言和键盘处，保持默认，done

![layout](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/server/layout.png)

网络处保持默认

![method](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/server/network.png)

无需proxy

![erasedisk](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/server/proxy.png)

mirror安装好之后再配置，直接done

![location](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/server/mirror.png)

磁盘处使用默认的整个硬盘，然后done

![password](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/server/disk.png)

确认后直接done

![finish](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/server/disksummary.png)

确认数据会全部擦除，并在continue处回车

![start](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/server/diskconfirm.png)

输入用户名、计算机名、密码等信息，根据课程安排，你的计算机名必须是如下所述：

1. 第一台: k8s-master

2. 第二台: k8s-worker1

3. 第三台: k8s-worker2

以下图上的主机名是随便取的一个，你的主机名必须符合上面描述的主机名要求

![start](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/server/useradd.png)

用空格来勾选SSH，后面我们用工具远程连接

![start](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/server/ssh.png)

很快会安装好，安装好之后，回车reboot now

![start](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/server/reboot.png)

在回车后，会让你在移除ISO或光盘后再次回车才能启动

重新使VMware 虚拟机恢复网络能力

![restorenet](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/restorenet.png)

## 设置root密码

用上面自己的用户名和密码登录后，输入sudo -i回车，输入自己的密码，并输入passwd root，给root用户设置密码，请注意，所有虚拟机的root密码，必须是`vagrant`

![start](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/server/rootpass.png)

# 获取临时地址

先设置临时地址用于SSH工具配置，在控制台输入dhclient命令，从配置好的网段获取临时IP

```bash
dhclient
```

# 使用SSH工具连接

推荐的工具下载链接如下，你也可以使用自己熟悉的

```bash
https://download.mobatek.net/2422024061715901/MobaXterm_Portable_v24.2.zip
```

# 设置永久静态IP地址

先确定接口名称，输入 `ip a s` 回车这里发现接口名称为ens33，临时地址为192.168.30.130

![start](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/server/interface.png)

设置静态IP

直接在SSH工具上，全选复制粘贴即可将IP配置完成，如果使用SSH工具存在困难，以下任何需要粘贴的部分，可手工在服务器中vim修改具体文件

再次提醒，请注意，三台虚拟机的IP和主机名必须如下：

1. 第一台: k8s-master  对应的IP 为192.168.8.3

2. 第二台: k8s-worker1 对应的IP 为192.168.8.4

3. 第三台: k8s-worker2 对应的IP 为192.168.8.5

下面是举例k8s-master配置IP方法，直接复制粘贴即可，第二台和第三台记得更换IP地址

```bash
cat > /etc/netplan/00-installer-config.yaml <<EOF
# This is the network config written by 'subiquity'
network:
  renderer: networkd
  ethernets:
    ens33:
      addresses:
        - 192.168.8.3/24
      routes:
        - to: default
          via: 192.168.8.2
      nameservers:
        addresses:
          - 223.5.5.5
  version: 2
EOF

netplan apply

```

# 配置OpenSSH-Server

开通root用户的ssh权限以方便我们远程，此为课程所必须，请确保3台虚拟机上都配置好了root的ssh登录，且密码为`vagrant`，全选复制，然后在三台机器上粘贴

```bash
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart sshd
```

# 配置软件仓库加速

使用镜像加速，可以提高软件下载速度，在root权限下，输入以下内容，内容较多

## 南京大学

```bash
cp /etc/apt/sources.list /etc/apt/sources.list.bak
sed -i 's/^deb.*archive.ubuntu.com/deb https:\/\/mirror.nju.edu.cn/' /etc/apt/sources.list
apt update
```

# 安装VM Tools

```bash
apt install open-vm-tools -y
```

# 安装实用性工具包

```bash
apt install vim wget curl bash-completion -y
```

# 配置集群内部解析

全选复制，然后在三台机器上粘贴，注意不要有遗漏，3台机器都需要配置解析

```bash
cat >> /etc/hosts <<EOF
192.168.8.3 k8s-master
192.168.8.4 k8s-worker1
192.168.8.5 k8s-worker2
EOF
```

# 制作虚拟机快照

在后期操作期间，如果系统损坏，可以用快照快速恢复到干净的系统状态，所以在完成上述所有步骤后，根据下图指示，给三台虚拟机分别做一个快照以备不时之需

![snap](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/snapshot-create.png)

输入快照名称以及合适的备注，名称和备注的内容可以自取，自己能分辨此快照中包含什么内容即可

![snapshot](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/snapshot-create-confirm.png)

按照上面的做法，记得分别给其他两台虚拟机也分别做一个快照，避免后期重装系统的麻烦