# 国内使用容器镜像的注意事项

## 拉取镜像的几种方法

由于国家网络策略原因，整个中国都无法访问所有的Docker镜像，这提高了我们学习Docker和K8S相关知识的难度，我们目前可以通过以下几种方法解决无法拉取镜像的问题：

1. **使用Docker镜像加速器**

这是最推荐的方式，可以先搜搜网上有没有免费的加速器，如果没有就需要看看在哪里可以购买，不管是找到免费能用的还是购买，这是操作上最省事的方法

2. **自己购买云主机搭建**

这是自主掌握最好的方法，自己在国外买一个云服务器，然后自己搭建反向代理dockerhub的服务，就可以提供实时的所有镜像加速服务，拉镜像就从自己的仓库拉取，也可以在买好的云服务器上部署docker，将镜像拉取到云服务器本地，然后再把容器镜像打包成tar包，下载到本地，在本地加载也是可以的，这种方法对你的IT技能要求较高，取决于你会不会操作，不会操作这个方法就得pass掉，且云服务器和流量带宽成本也较高

3. **自己在内网部署仓库**

这是收集别人镜像给自己用的方式，找到镜像后，可以从别人那下载然后上传到自己的仓库，以后拉镜像就从自己的仓库拉取，这大大减少了公网拉取镜像的延迟，不过由于中国不允许访问dockerhub，在内网搭建的镜像，需要注意更新的频率和时效性，而且能用的镜像也相对较少，取决于能不能找到合适的镜像，而且也不能用于加速器，只能单个指定镜像来使用

## 如何使用自己的仓库

大部分的企业都有自己的内网镜像仓库服务，因为内网拉取更快，以下是几款可以用于仓库部署的软件，仅供参考：

1. Docker registry

2. Harbor

3. Quay

以上是可以用于部署在内网的容器镜像仓库，需根据企业或自身要求来自行部署，我们聊一下如何使用已经部署好的仓库

假设我们部署的仓库地址为：`registry.credclouds.com`

为了确保自己的仓库工作正常，我们假设你已经上传了镜像，我们以拉取busybox为例先确定能从自己的仓库拉取镜像：

```bash
docker pull registry.credclouds.com/busybox
```

以上地址的格式取决于你部署的仓库具体地址，由于仓库是你自己部署的，格式你一定是比较清楚，我们这里只是用于确定你的仓库工作正常

**在确定工作正常的情况下，我们又该如何使用自己的仓库呢？**

1. 命令行使用方法：

命令行方式拉取镜像，只需要在原镜像前面加上自己的地址格式前缀，这里我们假设要拉取busybox镜像

**docker 命令行**

```bash
docker pull registry.credclouds.com/busybox
```

**kubectl命令行运行pod**

```bash
kubectl run --image=registry.credclouds.com/busybox ....
```

2. 脚本或yaml中使用方法：

这种方法你就需要找一下在哪里定义了镜像，然后在镜像前面加上自己的地址格式前缀

例如:

从以下yaml中，可以看到我们要用busybox镜像，但是中国不允许我们访问国外的仓库，所以是无法成功的

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lixiaohuipod
spec:
  containers:
  - name: hello
    image: busybox
    imagePullPolicy: IfNotPresent
```

我们在image这里加上我们的地址格式前缀就行

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lixiaohuipod
spec:
  containers:
  - name: hello
    image: registry.credclouds.com/busybox
    imagePullPolicy: IfNotPresent
```

## Docker自动使用加速器

如果你已经找到了免费的加速器或已经购买了加速器，可以考虑在所有需要使用镜像的机器上都按照以下方式配置Docker服务，这样Docker就能自动使用镜像加速，而不需要手工执行地址格式前缀了

```bash
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<-EOF
{
  "registry-mirrors": [
    "https://registry.credclouds.com"
  ],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
systemctl daemon-reload
systemctl restart docker
```

这样配置好之后，就可以用下面的方式来拉取镜像了，可以看到，就不需要指定地址了，只需要指定你需要的镜像即可

```bash
docker pull busybox
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lixiaohuipod
spec:
  containers:
  - name: hello
    image: busybox
    imagePullPolicy: IfNotPresent
```
