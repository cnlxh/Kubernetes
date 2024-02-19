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
|4核心以上|8G以上，推荐16G|200G空闲|

# 仓库介绍

本仓库主要用于李晓辉的Kubernetes课程授课所用，内容将随着每个班级的具体情况实时更新以适用于不同班级，所以请保存本网址，而不要下载文件到本地，这将无法获得后续更新

# 使用说明

本仓库包含众多文件，主要内容如下：

1. `Install-Server-OS.md:` 用于<font color="red">面授</font>课程第一天或后续学员需要时，创建和配置VMware 虚拟机所用，<font color="red">不适用于我赢职场的答疑，我赢职场答疑使用群公告的虚拟机包含VMware虚拟机创建</font>，以及系统安装的注意事项，CKA课程至少需要3台虚拟机，请按照此中内容，完成3台虚拟机，注意不要克隆，并且`主机名`, `IP地址`, `root密码`，都需要和此文中所述的完全一致，不然可能会导致后面kubernetes集群异常

2. `Create-ECS-on-AliCloud.pdf: ` 用于学员电脑不满足配置要求，在阿里云上创建虚拟机所用，其内包含在阿里云上购买云主机的所有必要流程

3. `Create-K8S-With-Docker.sh: ` 用于<font color="red">面授</font>第一天课程没有出席，但后续需要跟班的学员创建集群所用或由于各种原因需要重装集群使用，<font color="red">不适用于我赢职场的答疑，我赢职场答疑使用群公告的虚拟机，</font>包含VMware虚拟机创建只需要在k8s-master虚拟机上使用本脚本，可以在3台虚拟机上自动安装一套3节点的Kubernetes 集群，使用此脚本时，务必确保在3台虚拟机上同时完成了以下事项:

    1. 确保在/etc/hosts中添加了3台虚拟机的解析，另外请务必确保你的3台虚拟机主机名和IP地址的确是这样对应的，这里列出的特定主机和IP地址是课程所必须

        192.168.8.3 k8s-master

        192.168.8.4 k8s-worker1

        192.168.8.5 k8s-worker2

    2. 确保3台虚拟机都开启了root通过ssh登录的权限，如未开启，请按照以下方法开启
        ```bash
        sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
        systemctl restart sshd
        ```
        如果不太懂sed，请手工编辑/etc/ssh/sshd_config文件，确保其内包含PermitRootLogin yes参数

    3. 确保3台虚拟机的root密码都是vagrant

   在确保虚拟机满足以上要求时，在k8s-master执行以下指令，来完成集群安装

    1. 下载并执行脚本完成集群安装

        ```bash
        wget https://gitee.com/cnlxh/Kubernetes/raw/master/Create-K8S-With-Docker.sh
        bash Create-K8S-With-Docker.sh
        ```

4. `Kubernetes-Classroom-Manual.md: ` 用于课程过程中的练习以及课程笔记，上课期间，请听从老师安排，执行其中特定的练习，验证知识点

5. `CKA-Exam-Question.md: ` 用于CKA课后练习所用，基本涵盖了CKA的所有知识点，请务必练习到位

6. `CKA-Exam-Setup.sh: ` 用于部署练习环境所用，在使用此脚本之前，请确保目前3台虚拟机是刚安装好的干净集群且集群状态正常，确认集群正常后，只需要在k8s-master上执行脚本即可完成练习环境部署，具体使用方法如下：

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
7. `CKA-Exam-Grade.sh: ` 用于练习完检验成果，在做完了练习题后，运行此脚本，可以输出是否符合练习题的要求，并输出分值，可以检验是否掌握了具体的知识点，具体使用方法如下：

    1. 下载并执行校验

        ```bash
        wget https://gitee.com/cnlxh/Kubernetes/raw/master/CKA-Exam-Grade.sh
        bash CKA-Exam-Grade.sh
        ```
