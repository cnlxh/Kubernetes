# Kubernetes

```textile
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```
# 请给我一个赞~~

如果觉得本仓库的内容对你有帮助，请按下图方式，给我点个赞，谢谢啦~~

![start](https://gitee.com/cnlxh/Kubernetes/raw/master/images/system/starme.png)

# 电脑硬件配置要求

|CPU|内存|SSD硬盘|<mark>MAC 电脑ARM CPU</mark>|<mark>MAC 电脑Intel CPU</mark>|
|:-:|:-:|:-:|:-:|:-:|
|推荐10代i5 8核以上|推荐16G及以上|推荐100G空闲SSD|<mark>不支持</mark>|<mark>支持</mark>|

# 仓库介绍

本仓库主要用于<mark>李晓辉的Kubernetes课程</mark>授课所用，内容将随着每个班级的具体情况实时更新以适用于不同班级，所以请<mark>保存本网址，而不要下载文件到本地，这将无法获得后续更新</mark>

# 基本信息

本次课程使用<mark>VMware Workstaion</mark>虚拟化软件，作为练习平台，具体信息如下：

|主机名|角色|IP|VMware 网络类型|用户名|密码|互联网连接|
|-|-|-|:-:|-|-|-|
|k8s-master|控制平面|192.168.8.3|NAT|vagrant<br>root|vagrant<br>vagrant|是|
|k8s-worker1|数据平面|192.168.8.4|NAT|vagrant<br>root|vagrant<br>vagrant|是|
|k8s-worker2|数据平面|192.168.8.5|NAT|vagrant<br>root|vagrant<br>vagrant|是|

在整个过程中，请<mark>仅使用root用户来完成课程和模拟考试</mark>

# VMware 网络配置

<mark>虚拟机中的IP不允许修改</mark>，所以你需要按照以下方法配置VMware 设置以便于能够联网

为了更顺利的使用ssh工具连接虚拟机，需要在安装好VMware的情况下，将虚拟机所使用的网络修改为<mark>VMnet8(NAT)</mark>，并将VMnet8的网络修改为<mark>192.168.8.0/24</mark>网段

在VMware软件左上角点击<mark>编辑</mark>，点击<mark>虚拟网络编辑器</mark>

![vmnetedit](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/vmnetedit.png)

默认无法修改，请点击更改设置，请在弹出框中，点击<mark>是</mark>

![vmnetedit](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/changeset.png)

确保选中了<mark>VMnet8</mark>，并将子网信息改为<mark>192.168.8.0</mark>， 掩码<mark>255.255.255.0</mark>点击确定

![vm-network-confirm](https://gitee.com/cnlxh/Kubernetes/raw/master/images/vmware/vm-network-confirm.png)

至此，我们已经可以用ssh工具来远程连接我们的VMware 虚拟机了

# Docker和K8S镜像站说明

在<mark>直播上课期间</mark>，我提供了免费的Docker和K8S的镜像加速器以及Docker和K8S软件仓库加速器，需要注意的是，加速器地址可能会受到不可抗力经常变更网址，请需要时，打开以下链接查看最新地址即可

```text
https://gitee.com/cnlxh/Kubernetes/blob/master/Docker-Images-Mirror.md
```


# 练习题使用说明

**练习题这部分，只在上完课之后才需要做，刚上课的时候不需要做这部分**

1. <mark>CKA-Exam-Setup.sh:</mark> 用于部署练习环境所用，在使用此脚本之前，请确保目前3台虚拟机是刚安装好的干净集群且集群状态正常，确认集群正常后，<mark>只在k8s-master上用root用户执行脚本</mark>即可完成练习环境部署，具体使用方法如下：

    1. <mark>用root用户</mark>确认集群状态是否正常，需要确保3个节点全部是Ready状态

        ```bash
        root@k8s-master:~# kubectl get nodes
        NAME          STATUS   ROLES           AGE     VERSION
        k8s-master    Ready    control-plane   7d17h   v1.31.0
        k8s-worker1   Ready    worker          7d17h   v1.31.0
        k8s-worker2   Ready    worker          7d17h   v1.31.0
        ```

    2. 执行脚本来部署练习环境
        ```bash
        wget https://gitee.com/cnlxh/Kubernetes/raw/master/CKA-Exam-Setup.sh
        bash CKA-Exam-Setup.sh
        ```
2. <mark>CKA-Exam-Grade.sh:</mark>用于练习完检验成果，在做完了练习题后，<mark>只在k8s-master上用root用户执行脚本</mark>，可以输出是否符合练习题的要求，并输出分值，可以检验是否掌握了具体的知识点，具体使用方法如下：

    1. 下载并执行校验

        ```bash
        wget https://gitee.com/cnlxh/Kubernetes/raw/master/CKA-Exam-Grade.sh
        bash CKA-Exam-Grade.sh
        ```
