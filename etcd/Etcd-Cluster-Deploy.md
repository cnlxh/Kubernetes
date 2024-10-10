```textile
作者：李晓辉

微信联系：lxh_chat

联系邮箱: 939958092@qq.com
```

本文将部署3节点的etcd集群，在这个过程中，同时举例了：

1. 如何新建多节点集群

2. 如何在新建集群时启用TLS加密

3. 如何将节点加入现有集群

4. 如何查询集群成员

5. 如何写入和查询etcd数据

以下是具体的资源信息：

|节点名称|操作系统|IP地址|备注|
|-|-|-|-|
|node1|Ubuntu|192.168.8.3||
|node2|Ubuntu|192.168.8.4||
|node3|Ubuntu|192.168.8.5||
|node4|Ubuntu|192.168.8.6|后期作为新节点加入集群|

关于集群节点数量，为了分布式一致性算法达到更好的投票效果，集群必须由奇数个节点组成，我的node4只是为了演示如何加入新节点目的


# 准备hosts解析

需要在所有节点都完成

```bash
cat > /etc/hosts <<'EOF'
192.168.8.3 node1
192.168.8.4 node2
192.168.8.5 node3
192.168.8.6 node4
EOF
```

# etcd 软件安装

这里可以找到最新版

```text
https://github.com/etcd-io/etcd/releases/
```

**部署二进制程序**

需要在所有节点都完成

```bash
wget https://github.com/etcd-io/etcd/releases/download/v3.4.33/etcd-v3.4.33-linux-amd64.tar.gz
tar xf etcd-v3.4.33-linux-amd64.tar.gz
cd etcd-v3.4.33-linux-amd64/
cp etcd etcdctl /usr/local/bin/
chmod +x /usr/local/bin/etcd /usr/local/bin/etcdctl
```

# 生成配置文件和服务文件

**配置文件参数解读**

etcd支持TLS加密和http两种部署方式，但两者只能在部署时选择，不支持在已经初始化好http的集群情况下，再加TLS证书，所以请始终选择以下的一种方式

`ETCD_NAME` 这个参数定义了etcd节点的名称

`ETCD_DATA_DIR` 这是etcd节点的数据存储目录

`ETCD_LISTEN_PEER_URLS` 这个参数指定了 etcd 节点监听的对等节点（peer）通信的 URL。对等节点之间的通信通常用于数据复制和集群管理

`ETCD_LISTEN_CLIENT_URLS` 这个参数指定了 etcd 节点监听客户端请求的 URL。客户端可以通过这些 URL 访问 etcd 服务

`ETCD_INITIAL_ADVERTISE_PEER_URLS` 这是节点在集群中对其他对等节点进行广播的 URL。这个 URL 用于集群中的节点发现和连接

`ETCD_ADVERTISE_CLIENT_URLS` 这是节点在集群中对客户端进行广播的 URL。客户端可以使用这个 URL 来连接到 etcd 服务

`ETCD_INITIAL_CLUSTER` 这个参数定义了集群的初始状态，包括集群中的所有节点及其对应的 URL。这个参数对于启动一个新的 etcd 集群是必需的

`ETCD_INITIAL_CLUSTER_TOKEN` 这是集群创建时使用的令牌，用于识别集群成员。它在集群的初始阶段用于确保所有节点属于同一个集群

`ETCD_INITIAL_CLUSTER_STATE="new"` 这个参数指定了集群的初始状态，这个选项只在初始化集群的时候有效，在初始化好之后，重启服务时，不会再次新建集群，请放心

`ETCD_INITIAL_CLUSTER_STATE="existing"` 当设置为 existing 时，表示集群已经存在，并且节点是加入到一个已经存在的集群中

`ETCD_CERT_FILE` 这个参数指定了 etcd 节点用于客户端通信的 TLS 证书文件的路径。证书文件包含了公钥，用于在客户端和 etcd 节点之间建立安全的连接

`ETCD_KEY_FILE` 这个参数指定了与 ETCD_CERT_FILE 中证书相对应的私钥文件的路径。私钥是加密通信中使用的，必须严格保密

`ETCD_TRUSTED_CA_FILE` 这个参数指定了受信任的 CA（证书颁发机构）证书文件的路径。etcd 节点会使用这个 CA 证书来验证与其通信的客户端或对等节点的证书是否有效

`ETCD_PEER_CERT_FILE` 这个参数指定了 etcd 节点用于对等节点（peer）通信的 TLS 证书文件的路径

`ETCD_PEER_KEY_FILE` 这个参数指定了与 ETCD_PEER_CERT_FILE 中证书相对应的私钥文件的路径。这个私钥用于对等节点之间的安全通信

`ETCD_PEER_TRUSTED_CA_FILE` 这个参数指定了用于验证对等节点证书的受信任 CA 证书文件的路径。etcd 节点会使用这个 CA 证书来确保它只与有效的对等节点通信

**证书生成注意事项**

1. 根证书最好能让所有节点都信任

2. 每个节点的etcd服务证书都必须能对包括127.0.0.1在内的所有IP和节点名称进行TLS验证

## node1 节点-非TLS

### 配置文件

```bash
mkdir /etc/etcd
cat > /etc/etcd/etcd.conf <<'EOF'
ETCD_NAME="node1"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://192.168.8.3:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.8.3:2379,http://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.8.3:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.8.3:2379"
ETCD_INITIAL_CLUSTER="node1=http://192.168.8.3:2380,node2=http://192.168.8.4:2380,node3=http://192.168.8.5:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-1"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF
```

### 服务文件

```bash
cat > /etc/systemd/system/etcd.service <<'EOF'
[Unit]
Description=etcd key-value store
Documentation=https://etcd.io/docs/
After=network.target

[Service]
EnvironmentFile=/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

### 启动服务

所有节点完成

```bash
sudo systemctl daemon-reload
sudo systemctl start etcd
sudo systemctl enable etcd
```

## node1 节点-TLS加密

### 生成根证书

```bash
openssl genrsa -out /etc/ssl/private/selfsignroot.key 4096
openssl req -x509 -new -nodes -sha512 -days 3650 -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Company/OU=SH/CN=etcd-root" \
-key /etc/ssl/private/selfsignroot.key \
-out /usr/local/share/ca-certificates/selfsignroot.crt
```

信任根证书

```bash
update-ca-certificates
```

### 生成服务证书

```bash
openssl genrsa -out /etc/ssl/private/node1.key 4096
openssl req -sha512 -new \
-subj "/C=CN/ST=Shanghai/L=Shanghai/O=Company/OU=SH/CN=etcd" \
-key /etc/ssl/private/node1.key \
-out node1.csr
```

**生成openssl cnf扩展文件**

```bash
cat > certs.cnf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = node1
IP.1 = 192.168.8.3
IP.2 = 127.0.0.1
EOF
```

**签发服务证书**

```bash
openssl x509 -req -in node1.csr \
-CA /usr/local/share/ca-certificates/selfsignroot.crt \
-CAkey /etc/ssl/private/selfsignroot.key -CAcreateserial \
-out /etc/ssl/certs/node1.crt \
-days 3650 -extensions v3_req -extfile certs.cnf
```



### TLS加密配置文件

```bash
mkdir /etc/etcd
cat > /etc/etcd/etcd.conf <<'EOF'
ETCD_NAME="node1"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.8.3:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.8.3:2379,https://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.8.3:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.8.3:2379"
ETCD_INITIAL_CLUSTER="node1=https://192.168.8.3:2380,node2=https://192.168.8.4:2380,node3=https://192.168.8.5:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-1"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_CERT_FILE="/etc/ssl/certs/node1.crt"
ETCD_KEY_FILE="/etc/ssl/private/node1.key"
ETCD_TRUSTED_CA_FILE="/usr/local/share/ca-certificates/selfsignroot.crt"
ETCD_PEER_CERT_FILE="/etc/ssl/certs/node1.crt"
ETCD_PEER_KEY_FILE="/etc/ssl/private/node1.key"
ETCD_PEER_TRUSTED_CA_FILE="/usr/local/share/ca-certificates/selfsignroot.crt"
EOF
```

服务文件：

```bash
cat > /etc/systemd/system/etcd.service <<'EOF'
[Unit]
Description=etcd key-value store
Documentation=https://etcd.io/docs/
After=network.target

[Service]
EnvironmentFile=/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

### 启动服务

所有节点完成

```bash
sudo systemctl daemon-reload
sudo systemctl start etcd
sudo systemctl enable etcd
```

## node2 节点-非TLS

### 配置文件

在node2的配置文件中，我们指定了不同的ETCD_NAME和不同的IP地址

```bash
mkdir /etc/etcd
cat > /etc/etcd/etcd.conf <<'EOF'
ETCD_NAME="node2"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://192.168.8.4:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.8.4:2379,http://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.8.4:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.8.4:2379"
ETCD_INITIAL_CLUSTER="node1=http://192.168.8.3:2380,node2=http://192.168.8.4:2380,node3=http://192.168.8.5:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-1"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF
```

### 服务文件

```bash
cat > /etc/systemd/system/etcd.service <<'EOF'
[Unit]
Description=etcd key-value store
Documentation=https://etcd.io/docs/
After=network.target

[Service]
EnvironmentFile=/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

### 启动服务

所有节点完成

```bash
sudo systemctl daemon-reload
sudo systemctl start etcd
sudo systemctl enable etcd
```

## node2 节点-TLS加密

### 生成根证书

根证书已经生成，这里直接复用

从node1上，直接复制过来

node1:

```bash
scp /etc/ssl/private/selfsignroot.key root@node2:/etc/ssl/private/selfsignroot.key
scp /usr/local/share/ca-certificates/selfsignroot.crt root@node2:/usr/local/share/ca-certificates/selfsignroot.crt
```
在node2上信任根证书

```bash
update-ca-certificates
```

### 生成服务证书

```bash
openssl genrsa -out /etc/ssl/private/node2.key 4096
openssl req -sha512 -new \
-subj "/C=CN/ST=Shanghai/L=Shanghai/O=Company/OU=SH/CN=etcd" \
-key /etc/ssl/private/node2.key \
-out node2.csr
```

**生成openssl cnf扩展文件**

```bash
cat > certs.cnf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = node2
IP.1 = 192.168.8.4
IP.2 = 127.0.0.1
EOF
```

**签发服务证书**

```bash
openssl x509 -req -in node2.csr \
-CA /usr/local/share/ca-certificates/selfsignroot.crt \
-CAkey /etc/ssl/private/selfsignroot.key -CAcreateserial \
-out /etc/ssl/certs/node2.crt \
-days 3650 -extensions v3_req -extfile certs.cnf
```

### TLS加密配置文件

在node2的配置文件中，我们指定了不同的ETCD_NAME和不同的IP地址

```bash
mkdir /etc/etcd
cat > /etc/etcd/etcd.conf <<'EOF'
ETCD_NAME="node2"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.8.4:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.8.4:2379,https://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.8.4:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.8.4:2379"
ETCD_INITIAL_CLUSTER="node1=https://192.168.8.3:2380,node2=https://192.168.8.4:2380,node3=https://192.168.8.5:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-1"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_CERT_FILE="/etc/ssl/certs/node2.crt"
ETCD_KEY_FILE="/etc/ssl/private/node2.key"
ETCD_TRUSTED_CA_FILE="/usr/local/share/ca-certificates/selfsignroot.crt"
ETCD_PEER_CERT_FILE="/etc/ssl/certs/node2.crt"
ETCD_PEER_KEY_FILE="/etc/ssl/private/node2.key"
ETCD_PEER_TRUSTED_CA_FILE="/usr/local/share/ca-certificates/selfsignroot.crt"
EOF
```

服务文件：

```bash
cat > /etc/systemd/system/etcd.service <<'EOF'
[Unit]
Description=etcd key-value store
Documentation=https://etcd.io/docs/
After=network.target

[Service]
EnvironmentFile=/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

### 启动服务

所有节点完成

```bash
sudo systemctl daemon-reload
sudo systemctl start etcd
sudo systemctl enable etcd
```

## node3 节点-非TLS

### 配置文件

在node3的配置文件中，我们指定了不同的ETCD_NAME和不同的IP地址

```bash
mkdir /etc/etcd
cat > /etc/etcd/etcd.conf <<'EOF'
ETCD_NAME="node3"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://192.168.8.5:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.8.5:2379,http://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.8.5:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.8.5:2379"
ETCD_INITIAL_CLUSTER="node1=http://192.168.8.3:2380,node2=http://192.168.8.4:2380,node3=http://192.168.8.5:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-1"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF
```

### 服务文件

```bash
cat > /etc/systemd/system/etcd.service <<'EOF'
[Unit]
Description=etcd key-value store
Documentation=https://etcd.io/docs/
After=network.target

[Service]
EnvironmentFile=/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

### 启动服务

所有节点完成

```bash
sudo systemctl daemon-reload
sudo systemctl start etcd
sudo systemctl enable etcd
```
## node3 节点-TLS加密

### 生成根证书

根证书已经生成，这里直接复用

从node1上，直接复制过来

node1:

```bash
scp /etc/ssl/private/selfsignroot.key root@node3:/etc/ssl/private/selfsignroot.key
scp /usr/local/share/ca-certificates/selfsignroot.crt root@node3:/usr/local/share/ca-certificates/selfsignroot.crt
```
在node3上信任根证书

```bash
update-ca-certificates
```

### 生成服务证书

```bash
openssl genrsa -out /etc/ssl/private/node3.key 4096
openssl req -sha512 -new \
-subj "/C=CN/ST=Shanghai/L=Shanghai/O=Company/OU=SH/CN=192.168.8.5" \
-key /etc/ssl/private/node3.key \
-out node3.csr
```

**生成openssl cnf扩展文件**

```bash
cat > certs.cnf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = node3
IP.1 = 192.168.8.5
IP.2 = 127.0.0.1
EOF
```

**签发服务证书**

```bash
openssl x509 -req -in node3.csr \
-CA /usr/local/share/ca-certificates/selfsignroot.crt \
-CAkey /etc/ssl/private/selfsignroot.key -CAcreateserial \
-out /etc/ssl/certs/node3.crt \
-days 3650 -extensions v3_req -extfile certs.cnf
```



### TLS加密配置文件

在node3的配置文件中，我们指定了不同的ETCD_NAME和不同的IP地址

```bash
mkdir /etc/etcd
cat > /etc/etcd/etcd.conf <<'EOF'
ETCD_NAME="node3"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.8.5:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.8.5:2379,https://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.8.5:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.8.5:2379"
ETCD_INITIAL_CLUSTER="node1=https://192.168.8.3:2380,node2=https://192.168.8.4:2380,node3=https://192.168.8.5:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-1"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_CERT_FILE="/etc/ssl/certs/node3.crt"
ETCD_KEY_FILE="/etc/ssl/private/node3.key"
ETCD_TRUSTED_CA_FILE="/usr/local/share/ca-certificates/selfsignroot.crt"
ETCD_PEER_CERT_FILE="/etc/ssl/certs/node3.crt"
ETCD_PEER_KEY_FILE="/etc/ssl/private/node3.key"
ETCD_PEER_TRUSTED_CA_FILE="/usr/local/share/ca-certificates/selfsignroot.crt"
EOF
```

服务文件：

```bash
cat > /etc/systemd/system/etcd.service <<'EOF'
[Unit]
Description=etcd key-value store
Documentation=https://etcd.io/docs/
After=network.target

[Service]
EnvironmentFile=/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

### 启动服务

所有节点完成

```bash
sudo systemctl daemon-reload
sudo systemctl start etcd
sudo systemctl enable etcd
```
# 查询节点成员

## 非TLS查询

```bash
etcdctl member list
```
输出
```text
2913e51cedd143c8, started, node2, http://192.168.8.4:2380, http://192.168.8.4:2379, false
3b2a0d0231245fc2, started, node3, http://192.168.8.5:2380, http://192.168.8.5:2379, false
65992e6edd0a3422, started, node1, http://192.168.8.3:2380, http://192.168.8.3:2379, false
```

查询详细情况

```bash
root@node1:~# etcdctl endpoint status --write-out=table
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|    ENDPOINT    |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| 127.0.0.1:2379 | 65992e6edd0a3422 |  3.4.33 |   20 kB |      true |      false |       262 |          9 |                  9 |        |
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

```bash
root@node2:~# etcdctl endpoint status --write-out=table
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|    ENDPOINT    |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| 127.0.0.1:2379 | 2913e51cedd143c8 |  3.4.33 |   20 kB |     false |      false |       262 |          9 |                  9 |        |
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

```bash
root@node3:~# etcdctl endpoint status --write-out=table
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|    ENDPOINT    |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| 127.0.0.1:2379 | 3b2a0d0231245fc2 |  3.4.33 |   20 kB |     false |      false |       262 |          9 |                  9 |        |
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

以上输出中，我们可以清晰的看到集群已经成功启动，并且node1的节点是leader

## TLS查询

```bash
root@node1:~# etcdctl member list --cacert=/usr/local/share/ca-certificates/selfsignroot.crt --cert=/etc/ssl/certs/node1.crt --key=/etc/ssl/private/node1.key
```
输出

```text
998b25cb26b17f5c, started, node1, https://192.168.8.3:2380, https://192.168.8.3:2379, false
c7b8ab040a991c52, started, node3, https://192.168.8.5:2380, https://192.168.8.5:2379, false
edeb1f281f08b3f3, started, node2, https://192.168.8.4:2380, https://192.168.8.4:2379, false
```

```bash
root@node1:~# etcdctl endpoint status --write-out=table --cacert=/usr/local/share/ca-certificates/selfsignroot.crt --cert=/etc/ssl/certs/node1.crt --key=/etc/ssl/private/node1.key
```

```text
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|    ENDPOINT    |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| 127.0.0.1:2379 | 998b25cb26b17f5c |  3.4.33 |   25 kB |     true |      false |       819 |         22 |                 22 |        |
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

# 添加新的节点到现有集群

这里将node4添加到集群中，node4已完成软件安装

## 非TLS节点添加

### 添加新节点信息

```bash
etcdctl member add node4 --peer-urls=http://192.168.8.6:2380 --endpoints=http://192.168.8.3:2379
```
输出
```text
Member ba1b5c99a67ee8dd added to cluster  88152b6a9e7e873

ETCD_NAME="node4"
ETCD_INITIAL_CLUSTER="node2=http://192.168.8.4:2380,node3=http://192.168.8.5:2380,node1=http://192.168.8.3:2380,node4=http://192.168.8.6:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.8.6:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
```

可以看到ETCD_INITIAL_CLUSTER_STATE这个值并不是new，而是existing


### 配置文件

在node4的配置文件中，我们指定了不同的ETCD_NAME和不同的IP地址

需要格外注意，我们在ETCD_INITIAL_CLUSTER这里新增了node4信息以及ETCD_INITIAL_CLUSTER_STATE为existing

```bash
mkdir /etc/etcd
cat > /etc/etcd/etcd.conf <<'EOF'
ETCD_NAME="node4"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://192.168.8.6:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.8.6:2379,http://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.8.6:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.8.6:2379"
ETCD_INITIAL_CLUSTER="node1=http://192.168.8.3:2380,node2=http://192.168.8.4:2380,node3=http://192.168.8.5:2380,node4=http://192.168.8.6:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-1"
ETCD_INITIAL_CLUSTER_STATE="existing"
EOF
```

### 服务文件

```bash
cat > /etc/systemd/system/etcd.service <<'EOF'
[Unit]
Description=etcd key-value store
Documentation=https://etcd.io/docs/
After=network.target

[Service]
EnvironmentFile=/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

### 启动服务

所有节点完成

```bash
sudo systemctl daemon-reload
sudo systemctl start etcd
sudo systemctl enable etcd
```

### 查询新节点信息

```bash
etcdctl endpoint status --write-out=table
```
输出
```text
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|    ENDPOINT    |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| 127.0.0.1:2379 | ba1b5c99a67ee8dd |  3.4.33 |   16 kB |     false |      false |       329 |         26 |                 26 |        |
+----------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

### 修改现有节点的配置信息

由于在现有的node1 node2 node3上的配置中并不包含node4信息，所以要在他们的配置文件中，包含此信息

以下操作需要在所有节点完成

在所有节点上，更新ETCD_INITIAL_CLUSTER这个参数以包含所有节点信息

```bash
vim /etc/etcd/etcd.conf
...
ETCD_INITIAL_CLUSTER="node1=http://192.168.8.3:2380,node2=http://192.168.8.4:2380,node3=http://192.168.8.5:2380,node4=http://192.168.8.6:2380"
```

所有节点修改了配置文件后，在每个节点上执行以下指令重启服务

```bash
sudo systemctl daemon-reload
sudo systemctl restart etcd
```

## TLS 节点添加

### 生成根证书

根证书已经生成，这里直接复用

从node1上，直接复制过来

node1:

```bash
scp /etc/ssl/private/selfsignroot.key root@node4:/etc/ssl/private/selfsignroot.key
scp /usr/local/share/ca-certificates/selfsignroot.crt root@node4:/usr/local/share/ca-certificates/selfsignroot.crt
```
在node2上信任根证书

```bash
update-ca-certificates
```

### 生成服务证书

```bash
openssl genrsa -out /etc/ssl/private/node4.key 4096
openssl req -sha512 -new \
-subj "/C=CN/ST=Shanghai/L=Shanghai/O=Company/OU=SH/CN=etcd" \
-key /etc/ssl/private/node4.key \
-out node4.csr
```

**生成openssl cnf扩展文件**

```bash
cat > certs.cnf << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = node4
IP.1 = 192.168.8.6
IP.2 = 127.0.0.1
EOF
```

**签发服务证书**

```bash
openssl x509 -req -in node4.csr \
-CA /usr/local/share/ca-certificates/selfsignroot.crt \
-CAkey /etc/ssl/private/selfsignroot.key -CAcreateserial \
-out /etc/ssl/certs/node4.crt \
-days 3650 -extensions v3_req -extfile certs.cnf
```

### 添加新节点信息

```bash
etcdctl member add node4 --peer-urls=https://192.168.8.6:2380 --endpoints=https://192.168.8.3:2379 --cacert=/usr/local/share/ca-certificates/selfsignroot.crt --cert=/etc/ssl/certs/node4.crt --key=/etc/ssl/private/node4.key
```
输出
```text
Member df40bdedd2918141 added to cluster 2c2b901cb34ab0c8

ETCD_NAME="node4"
ETCD_INITIAL_CLUSTER="node1=https://192.168.8.3:2380,node3=https://192.168.8.5:2380,node4=https://192.168.8.6:2380,node2=https://192.168.8.4:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.8.6:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
```

可以看到ETCD_INITIAL_CLUSTER_STATE这个值并不是new，而是existing

### TLS加密配置文件

在node4的配置文件中，我们指定了不同的ETCD_NAME和不同的IP地址

```bash
mkdir /etc/etcd
cat > /etc/etcd/etcd.conf <<'EOF'
ETCD_NAME="node4"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.8.6:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.8.6:2379,https://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.8.6:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.8.6:2379"
ETCD_INITIAL_CLUSTER="node1=https://192.168.8.3:2380,node2=https://192.168.8.4:2380,node3=https://192.168.8.5:2380,node4=https://192.168.8.6:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-1"
ETCD_INITIAL_CLUSTER_STATE="existing"
ETCD_CERT_FILE="/etc/ssl/certs/node4.crt"
ETCD_KEY_FILE="/etc/ssl/private/node4.key"
ETCD_TRUSTED_CA_FILE="/usr/local/share/ca-certificates/selfsignroot.crt"
ETCD_PEER_CERT_FILE="/etc/ssl/certs/node4.crt"
ETCD_PEER_KEY_FILE="/etc/ssl/private/node4.key"
ETCD_PEER_TRUSTED_CA_FILE="/usr/local/share/ca-certificates/selfsignroot.crt"
EOF
```

服务文件：

```bash
cat > /etc/systemd/system/etcd.service <<'EOF'
[Unit]
Description=etcd key-value store
Documentation=https://etcd.io/docs/
After=network.target

[Service]
EnvironmentFile=/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

### 启动服务

所有节点完成

```bash
sudo systemctl daemon-reload
sudo systemctl start etcd
sudo systemctl enable etcd
```

### TLS查询新节点是否加入

```bash
root@node1:~# etcdctl member list --cacert=/usr/local/share/ca-certificates/selfsignroot.crt --cert=/etc/ssl/certs/node4.crt --key=/etc/ssl/private/node4.key
```
输出

```text
998b25cb26b17f5c, started, node1, https://192.168.8.3:2380, https://192.168.8.3:2379, false
c7b8ab040a991c52, started, node3, https://192.168.8.5:2380, https://192.168.8.5:2379, false
df40bdedd2918141, started, node4, https://192.168.8.6:2380, https://192.168.8.6:2379, false
edeb1f281f08b3f3, started, node2, https://192.168.8.4:2380, https://192.168.8.4:2379, false
```

# 写入数据测试

## 非TLS写入测试

在node1上执行数据写入

```bash
etcdctl put lixiaohui "Hello, etcd!"
```
输出
```text
OK
```

在其他的node上执行查询

```bash
etcdctl get lixiaohui
```
输出
```text
lixiaohui
Hello, etcd!
```

## TLS写入测试

在node1上执行数据写入

```bash
etcdctl put cnlxh "Hello, lixiaohui" --cacert=/usr/local/share/ca-certificates/selfsignroot.crt --cert=/etc/ssl/certs/node1.crt --key=/etc/ssl/private/node1.key
```
输出
```text
OK
```

在其他的node上执行查询

```bash
etcdctl get cnlxh --cacert=/usr/local/share/ca-certificates/selfsignroot.crt --cert=/etc/ssl/certs/node2.crt --key=/etc/ssl/private/node2.key
```
输出
```text
cnlxh
Hello, lixiaohui
```