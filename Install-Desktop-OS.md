```textile
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```

# 资料下载

ISO 下载地址：

从以下链接下载文件：ubuntu-20.04.5-desktop-amd64.iso

```textile
http://mirrors.aliyun.com/ubuntu-releases/20.04.5
```

VMware Workstation下载地址：

将链接复制到浏览器，即可自动开始下载，另外此为付费软件，可试用，本次课程使用试用版，如有必要，请支持正版

```textile
https://www.vmware.com/go/getworkstation-win
```

# 虚拟机

## 新建虚拟机

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

根据你的电脑性能修改虚拟机配置，推荐配置为4核心4G内存，如果你有更好的配置，请自行修改，但不要小于2G内存，请注意在DVD处，选择自己下载好的ISO镜像，并确保勾选在启动时连接

![resize](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/resize.png)

![resizeresult](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/resizeresult.png)

# 操作系统

## 系统安装

在修改好虚拟机配置之后，点击打开虚拟机电源，稍等之后，会出现以下界面，请选择install Ubuntu

![welcome](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/welcome.png)

语言和键盘处，保持默认，点击continue

![layout](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/layout.png)

选择Minimal installation，并去掉download前面的勾选，具体见下图

![method](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/installmethod.png)

保持第一项擦除硬盘，并在弹出中，点击continue

![erasedisk](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/erasedisk.png)

选择上海地区

![location](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/location.png)

输入用户名、计算机名、密码，选择自动登录，具体见下图

![password](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/password.png)

结束安装后，点击finish

![finish](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/finish.png)

确保断开ISO和虚拟机的连接后，直接回车

![start](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/start.png)

系统启动后，会有一个欢迎的引导过程，请自行选择，不关心选项的一律点击右上角唯一的按钮即可

## 设置root密码

在桌面中，右击，并选择open in termital，输入sudo -i回车，输入自己的密码，并输入passwd root，给root用户设置密码
![rootpass](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/rootpass.png)

# 配置软件仓库加速

使用镜像加速，可以提高软件下载速度，在root权限下，输入以下内容，内容较多，可以用虚拟机浏览器打开本页面，复制粘贴

## 阿里云

```bash
cp /etc/apt/sources.list /etc/apt/sources.list.bak
sed -i s/cn.archive.ubuntu.com/mirrors.aliyun.com/g /etc/apt/sources.list
sed -i s/security.ubuntu.com/mirrors.aliyun.com/g /etc/apt/sources.list
apt update
```

## 清华大学

```bash
cp /etc/apt/sources.list /etc/apt/sources.list.bak
sed -i s/cn.archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g /etc/apt/sources.list
sed -i s/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g /etc/apt/sources.list
apt update
```

# 安装VM Tools

```bash
apt install open-vm-tools -y
```

# 安装OpenSSH-Server

安装SSH以方便我们远程

```bash
apt install openssh-server -y
sed -i /^#PermitRootLogin/a\PermitRootLogin\ yes /etc/ssh/sshd_config
systemctl enable ssh --now
```

# 安装实用性工具包

```bash
apt install vim wget curl bash-completion -y
```

# 设置IP地址

使用nmtui、nmcli以及你熟悉的方法，给虚拟机配置合理的IP
