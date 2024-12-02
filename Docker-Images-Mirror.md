# 容器镜像站列表

本页的镜像站会不断更新，可时常打开看看~

镜像提供者微信：Lxh_Chat

# 仅课程中有效的镜像站地址

这里的镜像站<mark>仅限直播课程中有效</mark>，你可以考虑使用这里的站点或搜索其他站点，只要可以下载镜像都可以，由于这里的加速器是我个人花钱给大家免费使用的，所以这里的免费加速器将会于课程结束当日下线，再次开课时，这些镜像站会重新上线，如有任何疑问，请联系微信Lxh_Chat

|用途|地址|备注|
|-|-|-|
|Docker软件安装|class-docker-install.myk8s.cn|添加到apt/yum仓库|
|Docker容器镜像|class-docker.myk8s.cn|添加到daemon文件或手工指定镜像地址|
|K8S软件安装|class-k8s-install.myk8s.cn|添加到apt/yum仓库|
|K8S容器镜像|class-k8s.myk8s.cn|手工指定镜像地址|
|Github容器镜像|class-ghcr.myk8s.cn|手工指定镜像地址|
|Github网站代理|class-git.myk8s.cn|打开浏览器|

# 永久有效的容器镜像加速站

这里的镜像站<mark>长期有效</mark>，供朋友间有偿共享使用

请点击网站地址前往了解：[https://registry.credclouds.com](https://registry.credclouds.com)

# Docker加速器配置

以下Docker Daemon配置中的内容仅为配置示意

1. 永久有效的容器镜像加速器用户使用时请参考以下格式更正为带有你姓名的专属链接，例如，将lixiaohui.myk8s.cn改为zhangsan.myk8s.cn即可
2. 直播课程中只需要将下方的链接更正为上表中的Docker容器镜像的地址，直接复制更正后的代码粘贴到3台机器即可，上表的所有加速地址将在课程结束当日关闭，请勿依赖

Docker Daemon配置示意如下：

```bash
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<-EOF
{
  "registry-mirrors": [
    "https://lixiaohui.myk8s.cn"
  ],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

systemctl daemon-reload
systemctl restart docker

```
配置完成后，拉取镜像的案例如下：

```bash
docker pull lixiaohui.myk8s.cn/library/nginx
# 或者
docker pull nginx
```

# 镜像拉取失败的处理方法

如果上面的案例无法拉取镜像，那是因为触发了docker 官方的匿名拉取限制，请翻墙后在以下网址或docker hub上注册一个账号，然后用docker login登录即可拉取

1. 账号注册网址：https://app.docker.com/signup

2. 注册好之后，用<mark>docker login lixiaohui.myk8s.cn</mark>登陆一下然后重新拉取镜像即可，不要忘记将加速器地址换成你的姓名，例如zhangsan.myk8s.cn
