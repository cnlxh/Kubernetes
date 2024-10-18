# CKA 环境操作指南

```text
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```

本次课程所涉及的虚拟机平台是VirtualBox，创建了3台虚拟机用于CKA课程，主机名和IP地址分别是:

|编号|主机名|IP地址|用户名|密码|
|-|-|-|-|-|
|1|k8s-master|192.168.8.3|root|vagrant|
|2|k8s-worker1|192.168.8.4|root|vagrant|
|3|k8s-worker2|192.168.8.5|root|vagrant|

## VirtualBox 安装和配置

VirtualBox 已经通过百度网盘提供，请下载好之后直接安装，安装过程的选项没有特别需要注意的地方，所有选项可以保持默认

### VirtualBox 扩展安装

VirtualBox 扩展已通过百度网盘提供，具体安装方法如下：

在左侧的工具处，点击三个横杠，点击扩展，然后点击安装两个字，在弹出的对话框中点击安装，并下拉协议内容到最后，同意协议

![virtualbox-extend](https://gitee.com/cnlxh/Kubernetes/raw/master/images/virtualbox/virtualbox-extend.png)

![virtualbox-confirm](https://gitee.com/cnlxh/Kubernetes/raw/master/images/virtualbox/extend-confirm.png)

### VirtualBox 网络配置

为了方便沟通，本次课程所有同学都使用同样的IP地址，我们本次使用virtualbox提供的`NAT网络`类型

1. 新建NAT网络

在左侧的工具处，点击三个横杠，点击网络，在网络界面上，点击`NAT网络`按钮，点击后，右击下方空白处，点击`创建`，保持名称为`NatNetwork`，IPV4为`192.168.8.0/24`, 启用`DHCP`，确认信息后，点击`应用`按钮

![network-list](https://gitee.com/cnlxh/Kubernetes/raw/master/images/virtualbox/network-list.png)

![nat-create](https://gitee.com/cnlxh/Kubernetes/raw/master/images/virtualbox/nat-create.png)

![nat-create-ok](https://gitee.com/cnlxh/Kubernetes/raw/master/images/virtualbox/nat-create-ok.png)

2. 配置端口转发

由于virtualbox的特性原因，默认情况下，我们的物理机无法直接和虚拟机通信，所以我们需要配置端口转发来访问3台机器的SSH端口

确认点击了`NatNwork`的网络后，点击`端口转发`，点击`绿色的加号`

![network-rule-create](https://gitee.com/cnlxh/Kubernetes/raw/master/images/virtualbox/network-rule-create.png)

多次点击绿色的加号，并配置如下规则，确认规则无误，点击应用按钮：

![rule-create](https://gitee.com/cnlxh/Kubernetes/raw/master/images/virtualbox/rule-create.png)

### 导入虚拟机

将所有的7z压缩包下载完毕，依次右击k8s-master、k8s-worker1、k8s-worker2压缩包的任意一个进行解压，注意不要遗漏，一共三个虚拟机，每个虚拟机只需要点击一次解压即可

点击`控制`，点击`注册`，

![register-vm](https://gitee.com/cnlxh/Kubernetes/raw/master/images/virtualbox/register-vm.png)

浏览到你解压虚拟机的地方，点击如下颜色的文件进行导入，以此类推，把3个虚拟机都导入进来

![import-vm](https://gitee.com/cnlxh/Kubernetes/raw/master/images/virtualbox/import-vm.png)


### 从物理机上连接虚拟机

我们以及完成了virtualbox的网络配置以及导入虚拟机，我们可以右击这几个虚拟机开机，开机后，尝试用SSH软件连接转发的本地端口，看看能不能连接，如果不能连接，请关闭本地Windows的防火墙，或者允许virtualbox流量通过

你可以使用任何你熟悉的工具，如果你没有自己熟悉的工具，可以用我推荐的工具，我推荐的工具下载地址如下：

```text
https://download.mobatek.net/2352023111832715/MobaXterm_Portable_v23.5.zip
```

下载完直接解压即可，此工具无需安装，点击exe文件即可运行，打开后，点击`session`

![ssh-create-1](https://gitee.com/cnlxh/Kubernetes/raw/master/images/virtualbox/ssh-create-1.png)

确认配置如下，要注意，三台虚拟机的端口是不同的，按照同样的步骤，新建多个session，每个session的端口都不同

![ssh-configure](https://gitee.com/cnlxh/Kubernetes/raw/master/images/virtualbox/ssh-configure.png)

连接成功的图如下

![connect-ok](https://gitee.com/cnlxh/Kubernetes/raw/master/images/virtualbox/connect-ok.png)

