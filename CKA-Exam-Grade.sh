#!/bin/bash
echo "######################################################################################################
#    Author: Xiaohui Li
#    Contact me via WeChat: Lxh_Chat
#    Contact me via QQ: 939958092
#    Version: 2022-03-01
#
#    Make sure you have a 3-node k8s cluster and have done the following:
#
#    1. complete /etc/hosts file
#    
#       192.168.8.3 k8s-master
#       192.168.8.4 k8s-worker1
#       192.168.8.5 k8s-worker2
#
#    2. root password has been set to vagrant on all of node
#
#       tips:
#         sudo echo root:vagrant | chpasswd
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

# defined global vars

function pass {
  echo -ne "\033[32m PASS \033[0m\t"
}

function fail {
  echo -ne "\033[31m FAIL \033[0m\t"
}

score=0

# start grade cka exam

function etcdbackup {
  echo 'ETC备份题目: 正在判定ETCD数据库备份恢复'
  echo
  if [ -f /srv/etcd-snapshot.db ];then
    score=$(expr $score + 2 )
    pass && echo 'ETCD 备份文件已存在'
  else
    fail && echo 'ETCD 备份文件不存在'
  fi  
  cp /srv/etcd-snapshot.db /srv/etcd-snapshot.db.bak &> /dev/null
  if ETCDCTL_API=3 etcdctl --write-out=table snapshot status /srv/etcd-snapshot.db.bak &> /dev/null;then
    score=$(expr $score + 2 )
    rm -rf /srv/etcd-snapshot.db.bak
    pass && echo 'ETCD 备份文件已就绪'
  else
    fail && echo 'ETCD 备份文件的内容好像不对'
  fi  
    
  if kubectl get namespaces | grep -q cka-etcd-backup-check;then
    score=$(expr $score + 2 )
    pass && echo 'ETCD 数据库已成功恢复'
  else
    fail && echo 'ETCD 没有恢复成功'
  fi
  echo
  echo
}

function rbac {
  echo 'RBAC授权题目: 正在判定RBAC授权'
  echo
  if kubectl describe clusterrole deployment-clusterrole &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'deployment-clusterrole 已存在'
  else
    fail && echo 'deployment-clusterrole ClusterRole不存在'
  fi
  if kubectl describe clusterrole deployment-clusterrole 2> /dev/null | grep daemonsets.apps | grep -q create;then
    score=$(expr $score + 2 )
    pass && echo 'deployment-clusterrole 可以创建daemonsets'
  else
    fail && echo 'deployment-clusterrole不存在或无法创建daemonsets'
  fi
  if kubectl describe clusterrole deployment-clusterrole 2> /dev/null | grep deployments.apps | grep -q create;then
    score=$(expr $score + 2 )
    pass && echo 'deployment-clusterrole 可以创建deployments'
  else
    fail && echo 'deployment-clusterrole不存在或无法创建deployments'    
  fi
  if kubectl describe clusterrole deployment-clusterrole 2> /dev/null | grep statefulsets.apps | grep -q create;then
    score=$(expr $score + 2 )
    pass && echo 'deployment-clusterrole 可以创建statefulsets'
  else
    fail && echo 'deployment-clusterrole不存在或无法创建statefulsets'     
  fi
  if kubectl get serviceaccounts -n app-team1 cicd-token &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'app-team1命名空间下的服务账号cicd-token已存在'
  else
    fail && echo 'app-team1下的cicd-token 服务账号不存在'
  fi
  if kubectl -n app-team1 describe rolebindings.rbac.authorization.k8s.io 2> /dev/null | tr -s '\t' ' ' | grep -A 12 "Name: deployment-clusterrole" | grep -E 'cicd-token|app-team1|deployment-clusterrole' &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'app-team1下cicd-token服务账号的rolebindings已存在'
  else
    fail && echo 'app-team1下cicd-token服务账号的rolebindings不存在'
  fi
  echo
  echo
}

function node_maintenance {
  echo '禁用节点调度题目: 正在判定k8s-master是否不可调度'  
  echo
  if kubectl get nodes | grep k8s-master | grep -q SchedulingDisabled;then
    score=$(expr $score + 2 )
    pass && echo 'k8s-master已设置不可调度'
  else
    fail && echo 'k8s-master节点没有设置为不调度'
  fi  
  echo
  echo  
}

function upgrade {
  echo '集群升级题目：正在判定集群是否升级成功' 
  echo
  if kubectl get nodes | grep k8s-master | grep -q 1.31.1;then
    score=$(expr $score + 2 )
    pass && echo 'k8s-master已升级到1.31.1'
  else
    fail && echo 'k8s-master没有成功升级到1.31.1'
  fi  
  if kubectl version 2> /dev/null | grep -q v1.31.1 &> /dev/null &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'kubectl已升级到1.31.1'
  else
    fail && echo 'kubectl没有成功升级到1.31.1'
  fi  
  if kubelet --version | grep -q v1.31.1 &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'kubelet已升级到1.31.1'
  else
    fail && echo 'kubelet没有成功升级到1.31.1'
  fi  
  echo
  echo  
}

function networkpolicy {
  echo '创建网络策略题目：正在判定网络策略是否生效'   
  echo   
  if kubectl get networkpolicies.networking.k8s.io allow-port-from-namespace -n internal &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'internal命名空间中已存在allow-port-from-namespace网络策略'
  else
    fail && echo 'internal命名空间中的allow-port-from-namespace 网络策略不存在'
  fi
  if kubectl describe networkpolicies.networking.k8s.io allow-port-from-namespace -n internal 2> /dev/null | grep -q 'To Port: 80/TCP';then
    score=$(expr $score + 2 )
    pass && echo 'allow-port-from-namespace网络策略已开放TCP 80端口'
  else
    fail && echo 'internal命名空间中的allow-port-from-namespace 网络策略不存在或开放的端口不是80端口'
  fi
  if kubectl describe networkpolicies.networking.k8s.io allow-port-from-namespace -n internal 2> /dev/null | grep NamespaceSelector | grep -q metadata.name=corp;then
    score=$(expr $score + 2 )
    pass && echo 'allow-port-from-namespace 网络策略已允许来自corp命名空间的访问'
  else
    fail && echo 'internal命名空间中的allow-port-from-namespace 网络策略不存在或没有允许来自corp命名空间的访问'
  fi 
  echo
  echo     
}

function createservice {
  echo '创建服务并暴露端口题目: 正在判定服务是否以nodePort方式开放了容器80端口'   
  echo  
  if kubectl get deployments.apps front-end -o yaml 2> /dev/null | grep -A 20 'image: ' | grep "name: http" &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo '开放的端口名称是http'
  else
    fail && echo '开放的端口名称不是http'
  fi
  if kubectl get deployments.apps front-end -o yaml 2> /dev/null | grep -A 20 'image: ' | grep "containerPort: 80" &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo '开放的端口是80'
  else
    fail && echo '开放的不是80端口'
  fi
  if kubectl get service front-end-svc &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'front-end-svc服务已存在'
  else
    fail && echo 'front-end-svc服务不存在'
  fi  
  if kubectl get service front-end-svc -o yaml 2> /dev/null | grep -q nodePort;then
    score=$(expr $score + 2 )
    pass && echo 'front-end-svc服务类型是nodePort'
  else
    fail && echo 'front-end-svc服务不存在或服务类型不是nodePort'
  fi  
  echo
  echo         
}

function ingress {
  echo '创建ingress题目: 正在判定是否可以通过ingress来访问/hi' 
  echo   
  if kubectl describe ingress pong -n ing-internal &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'ing-internal命名空间中已存在pong ingress'
  else
    fail && echo 'ing-internal命名空间中没有pong ingress'
  fi
  if curl -kL k8s-worker2/hi 2> /dev/null | grep -q hi &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo '已经可以访问ingress暴露的url'
  else
    fail && echo '无法访问ingress暴露的url'
  fi
  echo
  echo         
}

function scale {
  echo '扩容Deployment副本数题目: 正在判定loadbalancer副本数是为6'   
  echo
  if kubectl get deployments.apps loadbalancer -o yaml 2> /dev/null | grep -q 'replicas: 6';then
    score=$(expr $score + 2 )
    pass && echo 'loadbalancer 副本数是6'
  else
    fail && echo 'loadbalancer 副本数不是6'
  fi
  if kubectl rollout history deployment loadbalancer 2> /dev/null | grep -q 'record=true';then
    score=$(expr $score + 2 )
    pass && echo '已成功记录本次扩容操作'
  else
    fail && echo '没有记录本次扩容操作'
  fi
  echo
  echo      
}

function assignpod {
  echo '定向调度到指定节点题目: 正在判定是否将pod分配到了预期的节点上'   
  echo
  if kubectl get pod nginx-kusc00401 -o yaml 2> /dev/null | grep spinning &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'nginx-kusc00401已经分配到合适的节点'
  else
    fail && echo 'nginx-kusc00401分配的节点不对哦'
  fi
  echo
  echo
}

function findhealthnode {
  echo '查询健康节点数量题目：正在判定健康的节点数量'    
  echo
  healthnumber=`kubectl describe node | grep -i taints|grep -v -i -e noschedule -e unreachable | wc -l`
  yournumber=`cat /opt/kusc00402.txt 2> /dev/null`
  if [ $healthnumber = "$yournumber" ];then
    score=$(expr $score + 2 )
    pass && echo '健康的节点数量正确'
  else
    fail && echo '健康的节点数量好像不对哦'
  fi
  echo
  echo
}

function multicontainer {
  echo '创建一个pod并包含4个容器题目: 正在判定kucc1 Pod是否包括了4个容器'    
  echo
  if kubectl get pod kucc1 -o yaml 2> /dev/null | grep -E -qi image:.*nginx && kubectl get pod kucc1 -o yaml 2> /dev/null | grep -q image:.*redis && \
     kubectl get pod kucc1 -o yaml 2> /dev/null | grep -qi image:.*memcached && kubectl get pod kucc1 -o yaml 2> /dev/null | grep -q image:.*httpd;then
    score=$(expr $score + 2 )
    pass && echo 'kucc1 pod已经同时包含httpd、nginx、memcached、redis'
  else
    fail && echo 'kucc1 pod必须同时包含httpd、nginx、memcached、redis'
  fi
  echo
  echo
}

function pvcreate {
  echo 'app-config pv创建题目: 正在判定app-config pv设置是否正确'   
  echo 
  if kubectl get pv app-config &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'app-config pv已存在'
  else
    fail && echo 'app-config pv不存在'
  fi
  if kubectl get pv app-config -o yaml 2> /dev/null | grep -q 'storage: 2Gi' &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'app-config pv大小是2Gi'
  else
    fail && echo 'app-config pv不存在或大小不是2Gi'
  fi
  if kubectl get pv app-config -o yaml 2> /dev/null | grep -q ReadWriteMany &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'app-config pv权限是ReadWriteMany'
  else
    fail && echo 'app-config pv不存在或权限不是ReadWriteMany'
  fi
  if kubectl get pv app-config -o yaml 2> /dev/null | grep -qi hostPath &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'app-config pv volume类型是hostPath'
  else
    fail && echo 'app-config pv不存在或volume类型不是hostPath'
  fi  
  if kubectl get pv app-config -o yaml 2> /dev/null | grep -qi '/srv/app-config' &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'app-config pv volume路径是/srv/app-config'
  else
    fail && echo 'app-config pv不存在或volume路径不是/srv/app-config'
  fi  
  echo
  echo  
}

function pvc_create {
  echo 'pv-volume pvc创建题目: 正在判定pv-volume pvc以及web-server pod设置是否正确'   
  echo 
  if kubectl get pvc pv-volume  &> /dev/null ;then
    score=$(expr $score + 2 )
    pass && echo 'pv-volume pvc已存在'
  else
    fail && echo 'pv-volume pvc不存在'
  fi
  if kubectl get pvc pv-volume 2> /dev/null | grep -i Bound &> /dev/null ;then
    score=$(expr $score + 2 )
    pass && echo 'pv-volume pvc 正在使用中'
  else
    fail && echo 'pv-volume pvc 未可用状态'
  fi  
  if kubectl get pvc -o yaml 2> /dev/null | grep -qi csi-hostpath-sc &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'pv-volume pvc的storageClassName是csi-hostpath-sc'
  else
    fail && echo 'pv-volume pvc不存在或storageClassName不是csi-hostpath-sc'
  fi
  if kubectl get pvc -o yaml 2> /dev/null | grep -qi 'storage: 10Mi' &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'pv-volume pvc的大小是10Mi'
  else
    fail && echo 'pv-volume pvc不存在或大小不是10Mi'
  fi
  if kubectl get pod web-server -o yaml &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'web-server pod已存在'
  else
    fail && echo 'web-server pod不存在'
  fi  
  if kubectl get pod web-server -o yaml 2> /dev/null | grep -i image:.*nginx &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'web-server pod镜像是nginx'
  else
    fail && echo 'web-server pod不存在或镜像不是nginx'
  fi  
  if kubectl get pod web-server -o yaml 2> /dev/null | grep -i 'mountPath: /usr/share/nginx/html' &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'web-server pod挂载点是/usr/share/nginx/html'
  else
    fail && echo 'web-server pod不存在或挂载点不是/usr/share/nginx/html'
  fi  
  if kubectl get pod web-server -o yaml 2> /dev/null | grep -i 'claimName: pv-volume' &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'web-server pod已经挂载预期的pvc'
  else
    fail && echo 'web-server pod不存在或没有挂载预期的pvc'
  fi  
  echo
  echo  
}

function podlog {
  echo 'pod日志查询题目: 正在判定/opt/foobar.txt内容是否正确'   
  echo 
  if cat /opt/foobar.txt 2> /dev/null | grep -q unable-to-access-website ;then
    score=$(expr $score + 2 )
    pass && echo '/opt/foobar.txt中的内容正确'
  else
    fail && echo '/opt/foobar.txt中的内容不正常'
  fi
  echo
  echo    
}

function sidecar {
  echo 'sidecar 容器添加题目: 正在判定legacy-app中的sidecar容器以及挂载卷是否正确'    
  echo
  if kubectl get pod legacy-app | grep -i running &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'legacy-app pod正在运行'
  else
    fail && echo 'legacy-app pod状态不正常'
  fi  
  if kubectl get pod legacy-app -o yaml &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'legacy-app pod已存在'
  else
    fail && echo 'legacy-app pod不存在'
  fi
  if kubectl get pod legacy-app -o yaml 2> /dev/null | grep -i 'name: busybox' &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'legacy-app pod已包含busybox容器'
  else
    fail && echo 'legacy-app pod不存在或并没有包含busybox容器'
  fi
  if kubectl get pod legacy-app -o yaml 2> /dev/null | grep -i image:.*busybox &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'legacy-app pod已包含busybox镜像'
  else
    fail && echo 'legacy-app pod不存在或并没有包含busybox镜像'
  fi
  if kubectl get pod legacy-app -o yaml 2> /dev/null | grep -i 'tail -n+1 -f /var/log/legacy-app.log' &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'legacy-app pod执行的命令是tail -n+1 -f /var/log/legacy-app.log'
  else
    fail && echo 'legacy-app pod不存在或执行的命令不是tail -n+1 -f /var/log/legacy-app.log'
  fi  
  if kubectl get pod legacy-app -o yaml 2> /dev/null | grep -i 'name: logs' &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'legacy-app pod挂载的volume是logs'
  else
    fail && echo 'legacy-app pod不存在或挂载的volume不是logs'
  fi  
  if kubectl get pod legacy-app -o yaml 2> /dev/null | grep -i 'mountPath: /var/log' &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo 'legacy-app pod挂载的volume路径是/var/log/'
  else
    fail && echo 'legacy-app pod不存在或挂载的volume路径不是/var/log/'
  fi  
  echo
  echo   
}

function highcpu {
  echo '查询CPU占用题目: 正在判定哪个容器占用CPU最多'    
  echo
  highcpu=`kubectl top pod -l name=cpu-user -A --sort-by cpu 2> /dev/null | sed 1d | tr -s ' ' ' ' | cut -d ' ' -f2 | head -n1`
  yours=`cat /opt/findhighcpu.txt 2> /dev/null`
  if [ -f /opt/findhighcpu.txt ] && [ "$highcpu" == "$yours" ];then
    score=$(expr $score + 2 )
    pass && echo '没错, CPU占用最高的就是这个家伙'
  else
    fail && echo 'CPU占用最高的不是这个哦'
  fi
  echo
  echo 
}

function fixnode {
  echo '节点故障修复题目：正在判定故障节点是否已经修复'    
  echo
  if kubectl get nodes | grep k8s-worker1 | grep -w Ready &> /dev/null;then
    score=$(expr $score + 2 )
    pass && echo '恭喜恭喜，已成功修复'
  else
    fail && echo '快修快修, k8s-worker1这个节点还没有修好哦, 加油了'
  fi
  echo
  echo 
}


# check if hosts if down
if ! kubectl get pod &> /dev/null;then
  echo 噢my god, 集群让你玩坏了, 你得了0分
fi

# excution and verify

etcdbackup
rbac
node_maintenance
upgrade
networkpolicy
createservice
ingress
scale
assignpod
findhealthnode
multicontainer
pvcreate
pvc_create
podlog
sidecar
highcpu
fixnode

# output your score

echo '===================================================================='
echo

# check if your score is greater 66%
if [ $score -gt 66 ];then
  pass && echo "你本次得分为： $score 分，通过了考试" 
else
  fail && echo "你本次得分为： $score 分，暂未通过考试，加油哦，看好你" 
fi
echo
echo