#!/bin/bash
echo "######################################################################################################
#  
#    Author：Xiaohui Li
#    Contact me via WeChat: Lxh_Chat
#    Contact me via QQ: 939958092
#    Version： 2022-03-01
#
#    Make sure you have a 3-node k8s cluster and have done the following:
#
#    1. complete /etc/hosts file
#    
#       192.168.30.130 cka-master
#       192.168.30.131 cka-worker1
#       192.168.30.132 cka-worker2
#
#    2. root password has been set to 1 on all of node
#
#       tips:
#         sudo echo root:1 | chpasswd
#		
#    3. enable root ssh login on /etc/ssh/sshd_config
#
#       tips: 
#         sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
#         sudo systemctl restart sshd
#
#    4. if you don't have that, please correct it before you are run this script
#
######################################################################################################"
echo
echo

# Defined CKA Question function

function rbac {
  # cordon node for prohibit running container
    kubectl cordon cka-worker1 &> /dev/null
    echo 'Preparing RBAC'
    kubectl create namespace app-team1 &> /dev/null
}

function node_maintenance {
    echo 'Preparing node maintenance'
}

function upgrade {
    echo 'Preparing upgrade'
}

function backup {
    echo 'Preparing backupfile'
    apt install etcd-client -y &> /dev/null
    mkdir -p /srv &> /dev/null 
    kubectl create namespace cka-etcd-backup-check &> /dev/null 
    ETCDCTL_API=3 etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    snapshot save /srv/etcd_exam_backup.db &> /dev/null 
    kubectl delete namespace cka-etcd-backup-check &> /dev/null 
}

function networkpolicy {
    echo 'Preparing internal and corp namespace'
    kubectl create namespace internal &> /dev/null
    kubectl create namespace corp &> /dev/null
    sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@cka-master docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/nginx &> /dev/null
    sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@cka-worker2 docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/nginx &> /dev/null



echo 'Preparing pod in internal'
cat > /root/internlpod.yaml <<'EOF'
kind: Pod
apiVersion: v1
metadata:
  name: internlpod
  namespace: internal
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
      ports:
        - containerPort: 80
EOF
kubectl create -f /root/internlpod.yaml &> /dev/null
rm -rf /root/internlpod.yaml
echo 'Preparing pod in corp'
cat > /root/corppod.yaml <<'EOF'
kind: Pod
apiVersion: v1
metadata:
  name: corppod
  namespace: corp
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: registry.cn-shanghai.aliyuncs.com/cnlxh/nginx
      ports:
        - containerPort: 80
EOF
kubectl create -f /root/corppod.yaml &> /dev/null
rm -rf /root/corppod.yaml
}

function service {
    echo 'Preparing front-end deployment'
    kubectl create deployment front-end --image=registry.cn-shanghai.aliyuncs.com/cnlxh/nginx &> /dev/null
}

function ingress {
    echo 'Preparing ingress controller'
    kubectl apply -f https://gitee.com/cnlxh/Kubernetes/raw/master/cka-yaml/ingressdeploy.yaml &> /dev/null

    echo 'Preparing ing-internal namespace'
    kubectl create namespace ing-internal &> /dev/null

    echo 'Preparing "ping" image for pod'
    for host in cka-master cka-worker2 ;do
      while true;do
        sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host crictl pull registry.cn-shanghai.aliyuncs.com/cnlxh/ping &> /dev/null
        if sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host docker images | grep -q ping;then
            break
        else
           systemctl restart docker &> /dev/null
           sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host crictl pull registry.cn-shanghai.aliyuncs.com/cnlxh/ping &> /dev/null
           break
        fi
      done
    done
    kubectl -n ing-internal run hi --image=registry.cn-shanghai.aliyuncs.com/cnlxh/ping &> /dev/null
    kubectl -n ing-internal expose pod hi --port=5678 &> /dev/null
}

function scale {
    echo 'Preparing loadbalancer deployment'
    kubectl create deployment loadbalancer --image=registry.cn-shanghai.aliyuncs.com/cnlxh/nginx &> /dev/null
}

function assignpod {
    echo 'Preparing cka-worker2 node label'
    kubectl label node cka-worker2 disk=spinning &> /dev/null
}

function health_node_count {
    echo 'Preparing health node for find'
}


function multi_container {
    echo 'Preparing multi container image'
    for host in cka-master cka-worker2 ;do
      while true;do
        `sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/nginx &` &> /dev/null
        `sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/redis  &` &> /dev/null
        `sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/memcached &` &> /dev/null
        `sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/consul &` &> /dev/null
        if ! sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host docker images | grep -q nginx;then
          `sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/nginx &` &> /dev/null
        elif ! sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host docker images | grep -q redis;then
          `sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/redis &` &> /dev/null
        elif ! sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host docker images | grep -q memcached;then
          `sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/memcached &` &> /dev/null
        elif ! sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host docker images | grep -q consul;then
          `sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@$host docker pull registry.cn-shanghai.aliyuncs.com/cnlxh/consul &` &> /dev/null
        # else
        #   echo ERROR: image cannot download, please check your internal or check nginx redis memcached consul docker image on all nodes
        fi
        break
      done
    done
}

function pv {
    echo 'Preparing pv mount point'
    sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@cka-master mkdir /srv/app-data  &> /dev/null
    sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@cka-worker2 mkdir /srv/app-data  &> /dev/null

}

function pvc {
    echo 'Preparing nfs server on cka-master nodes'
    apt install nfs-kernel-server nfs-common -y  &> /dev/null
    mkdir /nfsshare  &> /dev/null
    chmod 777 /nfsshare -R  &> /dev/null
    echo '/nfsshare *(rw)' > /etc/exports
    systemctl enable nfs-server nfs-mountd nfs-kernel-server nfs-utils --now &> /dev/null
    exportfs -rav  &> /dev/null

    sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@cka-master apt install nfs-common -y &> /dev/null
    sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@cka-worker2 apt install nfs-common -y &> /dev/null
    echo 'Preparing nfs external-provisioner'
    git clone https://gitee.com/cnlxh/nfs-subdir-external-provisioner.git  &> /dev/null
    cd nfs-subdir-external-provisioner
    NS=$(kubectl config get-contexts|grep -e "^\*" |awk '{print $5}')
    NAMESPACE=${NS:-default}
    sed -i'' "s/namespace:.*/namespace: $NAMESPACE/g" ./deploy/rbac.yaml ./deploy/deployment.yaml
    kubectl apply -f deploy/rbac.yaml  &> /dev/null
    kubectl apply -f deploy/deployment.yaml  &> /dev/null
    rm -rf /root/nfs-subdir-external-provisioner

echo 'Preparing csi-hostpath-sc StorageClass'
cat > /root/storageclass.yaml <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: csi-hostpath-sc
provisioner: cnlxh/nfs-storage
allowVolumeExpansion: true
parameters:
  pathPattern: "${.PVC.namespace}-${.PVC.name}"
  onDelete: delete
EOF
kubectl apply -f /root/storageclass.yaml &> /dev/null
rm -rf /root/storageclass.yaml
kubectl patch storageclass csi-hostpath-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' &> /dev/null

}

function log {
    echo 'Preparing foobar pod'
    kubectl run foobar --image=registry.cn-shanghai.aliyuncs.com/cnlxh/bar &> /dev/null
}

function sidecar {
    echo 'Preparing legacy-app pod'
cat > /root/sidecar.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: legacy-app
spec:
  containers:
  - name: legacy
    image: registry.cn-shanghai.aliyuncs.com/cnlxh/busybox
    args:
    - /bin/sh
    - -c
    - >
      i=0;
      while true;
      do
        echo "$i: $(date)" >> /var/log/legacy-app.log;
        i=$((i+1));
        sleep 1;
      done

EOF
kubectl apply -f /root/sidecar.yaml &> /dev/null
rm -rf /root/sidecar.yaml
}

function highcpu {
    echo 'Preparing metrics server'
    kubectl apply -f https://gitee.com/cnlxh/Kubernetes/raw/master/cka-yaml/metrics-components.yaml &> /dev/null
    kubectl label pod foobar name=cpu-user --overwrite &> /dev/null
}

function fixnode {
    echo 'Preparing cka-worker1 state into NotReady and SchedulingDisabled'
    while `kubectl get pod -A | grep -qi ContainerCreating`;do
      sleep 1s
    done
    sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@cka-worker1 systemctl disable kubelet docker.service docker.socket --now &> /dev/null
}

# Excution for Preparing

if ! ping -c2 cka-master &> /dev/null && ping -c2 cka-worker1 &> /dev/null && ping -c2 cka-worker2 &> /dev/null;then
  echo "please make sure cka-master cka-worker1 cka-worker2 node is poweron"
fi

while true; do 
if ! kubectl get nodes &> /dev/null;then
  echo "your cluster is not running now, I'm waiting for cluster ready, Please check it"
  sleep 1
else
  if kubectl get pod -A | grep -i -E 'error|back|init|creati' &> /dev/null;then
    sleep 1
  else
    break
  fi
fi
done

rbac
node_maintenance
upgrade
networkpolicy
service
ingress
scale
assignpod
health_node_count
multi_container
pv
pvc
log
sidecar
highcpu
fixnode
backup


# check if script not completed run

if ! kubectl get namespace app-team1 &> /dev/null;then
  rbac &> /dev/null
fi

if kubectl get namespace cka-etcd-backup-check &> /dev/null;then
  kubectl delete namespace cka-etcd-backup-check &> /dev/null
elif ! [ -e /srv/etcd_exam_backup.db ];then
  ETCDCTL_API=3 etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    snapshot save /srv/etcd_exam_backup.db &> /dev/null 
fi

if ! kubectl get pod internlpod -n internal &> /dev/null || kubectl get pod corppod -n corp &> /dev/null;then
  networkpolicy &> /dev/null
fi

if ! kubectl get deployment front-end &> /dev/null;then
  service &> /dev/null
fi

if ! kubectl -n ing-internal get pod hi &> /dev/null || kubectl -n ing-internal get service hi &> /dev/null;then
  ingress &> /dev/null 
fi

if ! kubectl get deployment loadbalancer &> /dev/null;then
  scale &> /dev/null  
fi

if ! kubectl get nodes --show-labels | grep -q disk;then
  assignpod &> /dev/null   
fi


if ! [ -e /srv/app-data ];then
  pv &> /dev/null  
fi

if ! kubectl get storageclasses csi-hostpath-sc &> /dev/null || ! kubectl get deployment nfs-client-provisioner &> /dev/null;then
  pvc &> /dev/null 
fi

if ! kubectl get pod foobar &> /dev/null;then
  log &> /dev/null 
fi

if ! kubectl get pod legacy-app &> /dev/null;then
  sidecar &> /dev/null  
fi

if ! kubectl top nodes &> /dev/null;then
  highcpu &> /dev/null   
fi

if ! sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@cka-worker1 systemctl is-active kubelet &> /dev/null;then
  fixnode &> /dev/null      
fi

echo
echo
echo "Please don't poweroff or disconnect from internet quickly, may be container image is still in downloading now."
echo
echo
