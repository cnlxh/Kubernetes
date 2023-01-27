#!/bin/bash

echo "######################################################################################################
#    Author：Xiaohui Li
#    Contact me via WeChat: Lxh_Chat
#    Contact me via QQ: 939958092
#    Version： 2022-03-01
#
#    please make sure you have three node and have been done as below:
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
#    4. this tools will only install kubernetes v1.26.0 for CKA Exam upgrade, if you want other version, please modify kubeadm kubelet kubectl version in script
#
######################################################################################################"
echo
echo -ne "\033[4;96m if any step fail, please restore clean system snapshot and run script again \033[0m\t"
echo
echo
echo -n 'Have you done the above? yes or no: '
read input
case $input in
yes)
  echo
	echo Now deploy k8s cluster on three node
  echo
;;
no)
	echo Please correct it && exit 1
;;
*)
	echo Please input yes or no
  exit 1
;;
esac

# if [ $input = "yes" ];then
#	sleep 1;
#else
#	echo you enter a word without yes && exit 1;
#fi

cd /root

cat > /etc/apt/sources.list <<EOF
deb https://mirror.nju.edu.cn/ubuntu focal main restricted
deb https://mirror.nju.edu.cn/ubuntu focal-updates main restricted
deb https://mirror.nju.edu.cn/ubuntu focal universe
deb https://mirror.nju.edu.cn/ubuntu focal-updates universe
deb https://mirror.nju.edu.cn/ubuntu focal multiverse
deb https://mirror.nju.edu.cn/ubuntu focal-updates multiverse
deb https://mirror.nju.edu.cn/ubuntu focal-backports main restricted universe multiverse
deb https://mirror.nju.edu.cn/ubuntu focal-security main restricted
deb https://mirror.nju.edu.cn/ubuntu focal-security universe
deb https://mirror.nju.edu.cn/ubuntu focal-security multiverse
EOF

echo 'Install utility tool on cka-master'
apt update &> /dev/null 
apt install sshpass wget bash-completion ansible -y &> /dev/null
sed -i 's/^#host_key_checking = False/host_key_checking = False/' /etc/ansible/ansible.cfg
echo
echo 'Create and copy ssh key to workers'
ls /root/.ssh/*.pub &> /dev/null
case $? in
0)
	sleep 1
;;
*)
	ssh-keygen -t rsa -f /root/.ssh/id_rsa -N '' &> /dev/null
;;
esac

sshpass -p 1 ssh-copy-id -o StrictHostKeyChecking=no root@cka-master &> /dev/null

sshpass -p 1 ssh-copy-id -o StrictHostKeyChecking=no root@cka-worker1 &> /dev/null

sshpass -p 1 ssh-copy-id -o StrictHostKeyChecking=no root@cka-worker2 &> /dev/null

cat > /etc/ansible/hosts <<EOF
[master]
cka-master ansible_user=root ansible_password=1
[worker]
cka-worker1 ansible_user=root ansible_password=1
cka-worker2 ansible_user=root ansible_password=1
EOF

cat > create-k8s.yaml <<'EOF'
---
- name: Configure Kubernetes
  hosts: all
  become: yes
  remote_user: root
  tasks:
    - name: clean apt lock
      shell: |
        rm -rf /var/lib/apt/lists/lock
        rm -rf /var/cache/apt/archives/lock
        rm -rf /var/lib/dpkg/lock*
        dpkg --configure -a
    - name: Modify Ubuntu Repository to Nanjing Edu
      shell: |
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
        sed -i 's/^deb.*archive.ubuntu.com/deb https:\/\/mirrors.nju.edu.cn/' /etc/apt/sources.list
    - name: Deploy Nanjing Edu Docker Repository
      shell: |
        apt-get update
        apt-get -y install apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://mirror.nju.edu.cn/docker-ce/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://mirror.nju.edu.cn/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
        apt-get -y update
    - name: clean apt lock
      shell: |
        rm -rf /var/lib/apt/lists/lock
        rm -rf /var/cache/apt/archives/lock
        rm -rf /var/lib/dpkg/lock*
        dpkg --configure -a
        apt update
    - name: Deploy chrony for make sure time on all node is same
      apt:
        pkg:
          - chrony
    - name: restart chronyd service for timesync
      systemd:
        state: restarted
        daemon_reload: yes
        name: chronyd
        enabled: yes
    - name: set timezone to Asia/Shanghai
      shell: |
        timedatectl set-timezone Asia/Shanghai
    - name: Deploy Docker on all node
      apt:
        pkg:
        - docker-ce
        - docker-ce-cli
        - containerd.io
        - docker-compose-plugin
    - name: ADD 163 docker mirror
      shell: |
        mkdir -p /etc/docker
        tee /etc/docker/daemon.json <<-'EOF'
        {
          "registry-mirrors": ["http://hub-mirror.c.163.com"],
          "exec-opts": ["native.cgroupdriver=systemd"]
        }
        EOF
    - name: starting docker service
      systemd:
        state: restarted
        daemon_reload: yes
        name: docker
        enabled: yes

    - block:
        - name: clean apt lock
          shell: |
            rm -rf /var/lib/apt/lists/lock
            rm -rf /var/cache/apt/archives/lock
            rm -rf /var/lib/dpkg/lock*
            dpkg --configure -a
            apt update  
        - name: Deploy CRI-Docker
          apt:
            deb: https://ghproxy.com/https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.0/cri-dockerd_0.3.0.3-0.ubuntu-focal_amd64.deb

      rescue:
        - name: clean apt lock
          shell: |
            rm -rf /var/lib/apt/lists/lock
            rm -rf /var/cache/apt/archives/lock
            rm -rf /var/lib/dpkg/lock*
            dpkg --configure -a
            apt update  
        - name: Deploy CRI-Docker
          apt:
            deb: https://ghproxy.com/https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.0/cri-dockerd_0.3.0.3-0.ubuntu-focal_amd64.deb

    - name: modify sandbox image to aliyun
      shell: |
        sed -i 's/ExecStart=.*/ExecStart=\/usr\/bin\/cri-dockerd --container-runtime-endpoint fd:\/\/ --network-plugin=cni --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com\/google_containers\/pause:3.8/' /lib/systemd/system/cri-docker.service
    - name: starting cri-docker service
      systemd:
        state: restarted
        daemon_reload: yes
        name: cri-docker
        enabled: yes
    - name: disable swap on /etc/fstab
      lineinfile:
        path: /etc/fstab
        regexp: '.*swap.*'
        state: absent
    - name: disable swap runtime
      shell: swapoff -a
    - name: configure iptables module
      lineinfile:
        path: /etc/modules-load.d/k8s.conf
        line: br_netfilter
        state: present
        create: true
    - name: configure iptables bridge
      lineinfile:
        path: /etc/sysctl.d/k8s.conf
        line: |
          net.bridge.bridge-nf-call-ip6tables = 1
          net.bridge.bridge-nf-call-iptables = 1
          net.ipv4.ip_forward = 1
        create: true
    - name: apply sysctl
      shell: |
        modprobe br_netfilter
        sysctl --system
    - name: add Nanjing Edu kubernetes repo on ubuntu
      shell: |
        cat > /etc/apt/sources.list.d/k8s.list <<EOF
        deb https://mirror.nju.edu.cn/kubernetes/apt/ kubernetes-xenial main
        EOF
        curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
        apt update
      when: ansible_facts.distribution == 'Ubuntu'
      #- name: add kubernetes repo
      #  apt_repository:
      #  repo: deb https://mirrors.tuna.tsinghua.edu.cn/kubernetes/apt/ kubernetes-xenial main
      #  validate_certs: false
      #  state: present
      #  filename: k8s
      #  update_cache: true
    # - name: add kubernetes repo on RHEL
    #   shell: |
    #     cat > /etc/yum.repos.d/kubernetes.repo <<EOF
    #     [kubernetes]
    #     name=Kubernetes
    #     baseurl=https://mirrors.tuna.tsinghua.edu.cn/kubernetes/yum/repos/kubernetes-el7-x86_64/
    #     enabled=1
    #     gpgcheck=0
    #     EOF
    #   when: ansible_facts.distribution == 'RedHat' or ansible_facts.distribution == 'CentOS'
    - name: install kubeadm kubectl kubelet
      package:
        name:
          - kubeadm=1.26.0-00
          - kubelet=1.26.0-00
          - kubectl=1.26.0-00
          - sshpass
        state: present
    - name: clean apt lock
      shell: |
        rm -rf /var/lib/apt/lists/lock
        rm -rf /var/cache/apt/archives/lock
        rm -rf /var/lib/dpkg/lock*
        dpkg --configure -a
        apt update
    - name: integrate with docker
      shell: crictl config runtime-endpoint unix:///run/cri-dockerd.sock
    - name: creating kubeadm.yaml
      shell: kubeadm config print init-defaults > kubeadm.yaml
      when: "'master' in group_names"
    - name: modify api server address
      lineinfile:
        path: kubeadm.yaml
        regexp: '.*advert.*'
        line: '  advertiseAddress: 192.168.30.130'
        state: present
      when: "'master' in group_names"
    - name: modify cluster name
      lineinfile:
        path: kubeadm.yaml
        regexp: '.*name.*'
        line: '  name: cka-master'
        state: present
      when: "'master' in group_names"
    - name: modify image repository
      lineinfile:
        path: kubeadm.yaml
        regexp: 'imageRepo.*'
        line: 'imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers'
        state: present
      when: "'master' in group_names"
    - name: modify crisock to cri-docker
      lineinfile:
        path: kubeadm.yaml
        regexp: '  criSocket.*'
        line: '  criSocket: unix:///run/cri-dockerd.sock'
        state: present
      when: "'master' in group_names"      
    - name: restart docker cri-docker kubelet service
      systemd:
        state: restarted
        daemon_reload: yes
        name: "{{ item }}"
        enabled: yes
      loop:
        - docker
        - cri-docker
        - kubelet            
    - name: Deploy kubernetes on Master node
      shell: kubeadm init --config kubeadm.yaml | tee /root/installdetails.log
      when: "'master' in group_names"
    - name: pause 30s after cluster init
      shell: sleep 30s
      when: "'master' in group_names"

    - name: set up admin role
      shell: |
        mkdir -p $HOME/.kube
        cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        chown $(id -u):$(id -g) $HOME/.kube/config
        sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@cka-worker1 mkdir /root/.kube 
        sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@cka-worker2 mkdir /root/.kube
        scp /etc/kubernetes/admin.conf root@cka-worker1:/root/.kube/config
        scp /etc/kubernetes/admin.conf root@cka-worker2:/root/.kube/config
        sleep 30s
      when: "'master' in group_names"
    - name: Deploy Calico
      shell: |
        kubectl create -f https://gitee.com/cnlxh/Kubernetes/raw/master/cka-yaml/calico.yaml
        sleep 30s
      when: "'master' in group_names"
    - name: join workers
      shell: |
        sleep 30
        join=`sshpass -p 1 ssh -A -g -o StrictHostKeyChecking=no root@cka-master kubeadm token create --print-join-command`
        echo $join --cri-socket=unix:///var/run/cri-dockerd.sock | bash
      when: "'worker' in group_names"
    - name: assign worker role label to workers
      shell: |
        sleep 30
        kubectl label nodes cka-worker2 cka-worker1 node-role.kubernetes.io/worker=
      when: "'master' in group_names"

EOF

cp /etc/ansible/ansible.cfg /root/ansible.cfg

sed -i '/^# command_warnings.*/a\command_warnings = False' /root/ansible.cfg

echo
echo 'Deploy K8S Cluster now'
echo
ansible-playbook create-k8s.yaml

rm -rf create-k8s.yaml /root/ansible.cfg /root/kubeadm.yaml /root/Create-K8S-With-Docker.sh /root/installdetails.log

kubectl completion bash > /etc/bash_completion.d/kubectl
kubeadm completion bash > /etc/bash_completion.d/kubeadm
source /etc/bash_completion.d/kubectl
source /etc/bash_completion.d/kubeadm

echo

echo "Please wait one minute for nodes ready"

echo

echo

sleep 1m

kubectl get nodes

echo

echo