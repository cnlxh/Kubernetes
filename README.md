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

|CPU|内存|SSD硬盘|
|-|-|-|
|4核心以上|8G以上，推荐16G|50G空闲|

# 仓库介绍

本仓库主要用于 `李晓辉` 的Kubernetes课程授课所用，内容将随着每个班级的具体情况实时更新以适用于不同班级，所以请保存本网址，而不要下载文件到本地，这将无法获得后续更新

# 基本信息

本次课程使用`VMware Workstaion` 虚拟化软件，作为练习平台，具体信息如下：

|主机名|角色|IP|用户名|密码|互联网连接|
|-|-|-|-|-|-|
|k8s-master|控制平面|192.168.8.3|vagrant<br>root|vagrant<br>vagrant|是|
|k8s-worker1|数据平面|192.168.8.4|vagrant<br>root|vagrant<br>vagrant|是|
|k8s-worker2|数据平面|192.168.8.5|vagrant<br>root|vagrant<br>vagrant|是|

# 练习题使用说明

1. `CKA-Exam-Setup.sh: ` 用于部署练习环境所用，在使用此脚本之前，请确保目前3台虚拟机是刚安装好的干净集群且集群状态正常，确认集群正常后，只需要在k8s-master上执行脚本即可完成练习环境部署，具体使用方法如下：

    1. 确认集群状态是否正常，需要确保3个节点全部是Ready状态

        ```bash
        root@k8s-master:~# kubectl get nodes
        NAME          STATUS   ROLES           AGE     VERSION
        k8s-master    Ready    control-plane   7d17h   v1.29.1
        k8s-worker1   Ready    worker          7d17h   v1.29.1
        k8s-worker2   Ready    worker          7d17h   v1.29.1
        ```

    2. 执行脚本来部署练习环境
        ```bash
        wget https://gitee.com/cnlxh/Kubernetes/raw/master/CKA-Exam-Setup.sh
        bash CKA-Exam-Setup.sh
        ```
2. `CKA-Exam-Grade.sh: ` 用于练习完检验成果，在做完了练习题后，运行此脚本，可以输出是否符合练习题的要求，并输出分值，可以检验是否掌握了具体的知识点，具体使用方法如下：

    1. 下载并执行校验

        ```bash
        wget https://gitee.com/cnlxh/Kubernetes/raw/master/CKA-Exam-Grade.sh
        bash CKA-Exam-Grade.sh
        ```
