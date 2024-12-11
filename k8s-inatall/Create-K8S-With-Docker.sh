#!/bin/bash

echo "######################################################################################################
#    Author: Xiaohui Li
#    Contact me via WeChat: Lxh_Chat
#    Contact me via QQ: 939958092
#    Version: 2022-03-01
#
#    please make sure you have three node and have been done as below:
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


read -p "Please input your Docker Hub username: " dockerhub_username

echo

read -sp "Please input your Docker Hub password: " dockerhub_password
echo
echo

# if [ $input = "yes" ];then
#	sleep 1;
#else
#	echo you enter a word without yes && exit 1;
#fi

cd /root

echo 'Install utility tool on k8s-master, Please wait'
apt update &> /dev/null 
apt install sshpass wget bash-completion ansible -y &> /dev/null
apt install sshpass wget bash-completion ansible -y &> /dev/null
mkdir /etc/ansible &> /dev/null
cat > /etc/ansible/ansible.cfg <<'EOF'
[defaults]
command_warnings=False
inventory=/etc/ansible/hosts
host_key_checking=False
remote_user=root
EOF

if [ $? -ne 0 ];then
exit;
fi
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

sshpass -p vagrant ssh-copy-id -o StrictHostKeyChecking=no root@k8s-master &> /dev/null

sshpass -p vagrant ssh-copy-id -o StrictHostKeyChecking=no root@k8s-worker1 &> /dev/null

sshpass -p vagrant ssh-copy-id -o StrictHostKeyChecking=no root@k8s-worker2 &> /dev/null

if [ $? -ne 0 ];then
exit;
fi

cat > /etc/ansible/hosts <<EOF
[master]
k8s-master ansible_user=root ansible_password=vagrant
[worker]
k8s-worker1 ansible_user=root ansible_password=vagrant
k8s-worker2 ansible_user=root ansible_password=vagrant
EOF
if [ $? -ne 0 ];then
exit;
fi
cat > create-k8s.yaml <<'EOF'
---
- name: Configure Kubernetes
  hosts: all
  become: yes
  remote_user: root
  tasks:
    - name: Deploy repos on ubuntu
      copy:
        content: |
          deb https://mirrors.nju.edu.cn/docker-ce/linux/ubuntu focal stable
          deb https://mirrors.nju.edu.cn/ubuntu focal main restricted
          deb https://mirrors.nju.edu.cn/ubuntu focal-updates main restricted
          deb https://mirrors.nju.edu.cn/ubuntu focal universe
          deb https://mirrors.nju.edu.cn/ubuntu focal-updates universe
          deb https://mirrors.nju.edu.cn/ubuntu focal multiverse
          deb https://mirrors.nju.edu.cn/ubuntu focal-updates multiverse
          deb https://mirrors.nju.edu.cn/ubuntu focal-backports main restricted universe multiverse
          deb https://mirrors.nju.edu.cn/ubuntu focal-security main restricted
          deb https://mirrors.nju.edu.cn/ubuntu focal-security universe
          deb https://mirrors.nju.edu.cn/ubuntu focal-security multiverse
          deb https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.32/deb /
        dest: /etc/apt/sources.list
    - name: Deoloy k8s gpg key
      apt_key:
        url: "{{ item }}"
        state: present
      loop:
        - https://mirrors.nju.edu.cn/docker-ce/linux/ubuntu/gpg
        - https://mirrors.nju.edu.cn/kubernetes/core%3A/stable%3A/v1.32/deb/Release.key
    - name: Update apt sources
      shell: apt update
      register: result
      until: result.rc == 0
      retries: 5
      delay: 2
      ignore_errors: yes
    - name: Check if chrony is installed, If this task failed, don't worry
      shell: dpkg -l chrony
      register: chrony_installed
      ignore_errors: true
    - name: Deploy chrony for make sure time on all node is same
      apt:
        pkg:
          - chrony
      register: result
      until: result.changed == true
      retries: 5
      delay: 2
      ignore_errors: yes
      when: chrony_installed.rc != 0
    - name: Restart chronyd service for timesync
      systemd:
        state: restarted
        daemon_reload: yes
        name: chronyd
        enabled: yes
      ignore_errors: yes
    - name: Configure timezone to Asia/Shanghai
      timezone:
        name: Asia/Shanghai
    - block:
        - name: Deploy Docker on all node
          apt:
            pkg:
              - ca-certificates
              - curl
              - gnupg
              - docker-ce
              - docker-ce-cli
              - containerd.io
              - docker-buildx-plugin
              - docker-compose-plugin
      rescue:
        - name: Deploy Docker on all node again
          apt:
            pkg:
              - ca-certificates
              - curl
              - gnupg
              - docker-ce
              - docker-ce-cli
              - containerd.io
              - docker-buildx-plugin
              - docker-compose-plugin
    - name: Create /etc/docker directory
      file:
        path: /etc/docker
        state: directory
    - name: Create daemon file for Docker hub mirror
      copy:
        content: |
          {
            "registry-mirrors": ["https://class-docker.myk8s.cn"],
            "exec-opts": ["native.cgroupdriver=systemd"]
          }
        dest: /etc/docker/daemon.json
    - name: Starting docker service
      systemd:
        state: restarted
        daemon_reload: yes
        name: docker
        enabled: yes
    - block:
        - name: Download CRI-Docker on master node
          get_url:
            url: https://class-git.myk8s.cn/Mirantis/cri-dockerd/releases/download/v0.3.15/cri-dockerd_0.3.15.3-0.ubuntu-focal_amd64.deb
            dest: /root/cri-dockerd_0.3.15.3-0.ubuntu-focal_amd64.deb
          register: result
          until: result.status_code == 200
          retries: 5
          delay: 2
          when: "'master' in group_names"
      rescue:
        - name: Download CRI-Docker on all node again
          get_url:
            url: https://gh-proxy.com/https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.15/cri-dockerd_0.3.15.3-0.ubuntu-focal_amd64.deb
            dest: /root/cri-dockerd_0.3.15.3-0.ubuntu-focal_amd64.deb
          register: result
          until: result.status_code == 200
          retries: 5
          delay: 2            
          when: "'master' in group_names"
    - name: Copy CRI-Docker package to node
      copy:
        src: /root/cri-dockerd_0.3.15.3-0.ubuntu-focal_amd64.deb
        dest: /root/cri-dockerd_0.3.15.3-0.ubuntu-focal_amd64.deb
        force: yes
    - name: Deploy CRI-Docker
      apt:
        deb: /root/cri-dockerd_0.3.15.3-0.ubuntu-focal_amd64.deb
      register: result
      until: result.changed == true
      retries: 5
      delay: 2
    - name: clean apt lock
      shell: |
        rm -rf /var/lib/apt/lists/lock
        rm -rf /var/cache/apt/archives/lock
        rm -rf /var/lib/dpkg/lock*
        apt update
      register: result
      until: result.rc == 0
      retries: 5
      delay: 2
      ignore_errors: yes
    - name: modify sandbox image repo
      shell: |
        sed -i 's/ExecStart=.*/ExecStart=\/usr\/bin\/cri-dockerd --container-runtime-endpoint fd:\/\/ --network-plugin=cni --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com\/google_containers\/pause:3.10/' /lib/systemd/system/cri-docker.service
    - name: starting cri-docker service
      systemd:
        state: restarted
        daemon_reload: yes
        name: cri-docker
        enabled: yes
    - name: Login docker hub with your password
      shell:
        docker login class-docker.myk8s.cn -u "{{ dockerhub_username }}" -p "{{ dockerhub_password }}"
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
    - name: install kubeadm kubectl kubelet
      package:
        name:
          - kubeadm=1.32.0-1.1
          - kubelet=1.32.0-1.1
          - kubectl=1.32.0-1.1
          - sshpass
          - socat
        state: present
      register: result
      until: result.failed == false
      retries: 5
      delay: 10
    - name: clean apt lock
      shell: |
        rm -rf /var/lib/apt/lists/lock
        rm -rf /var/cache/apt/archives/lock
        rm -rf /var/lib/dpkg/lock*
        apt update
      register: result
      until: result.rc == 0
      retries: 5
      delay: 2
    - name: integrate with docker
      shell: crictl config runtime-endpoint unix:///run/cri-dockerd.sock
    - name: creating kubeadm.yaml
      shell: kubeadm config print init-defaults > kubeadm.yaml
      when: "'master' in group_names"
    - name: Modify API server address
      lineinfile:
        path: kubeadm.yaml
        regexp: '(^\s*)advert.*'
        line: '\1advertiseAddress: 192.168.8.3'
        backrefs: yes
      when: "'master' in group_names"
    - name: Modify cluster name
      lineinfile:
        path: kubeadm.yaml
        regexp: '(^\s*)name.*'
        line: '\1name: k8s-master'
        backrefs: yes
      when: "'master' in group_names"
    - name: Modify image repository
      lineinfile:
        path: kubeadm.yaml
        regexp: '(^\s*)imageRepo.*'
        line: '\1imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers'
        backrefs: yes
      when: "'master' in group_names"
    - name: Modify criSocket to containerd
      lineinfile:
        path: kubeadm.yaml
        regexp: '(^\s*)criSocket.*'
        line: '\1criSocket: unix:///run/cri-dockerd.sock'
        backrefs: yes
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
      shell: kubeadm init --config kubeadm.yaml | tee /tmp/installdetails.log
      when: "'master' in group_names"
    - name: pause 30s after cluster init
      shell: sleep 30s
      when: "'master' in group_names"
    - name: Create .kube directory for root user
      file:
        path: /root/.kube
        state: directory
    - name: Copy admin.conf to .kube/config for root user
      copy:
        src: /etc/kubernetes/admin.conf
        dest: /root/.kube/config
        owner: root
        group: root
    - name: Create .kube directory for vagrant user
      file:
        path: /home/vagrant/.kube
        state: directory
        owner: vagrant
        group: vagrant        
    - name: Copy admin.conf to .kube/config for vagrant user
      copy:
        src: /etc/kubernetes/admin.conf
        dest: /home/vagrant/.kube/config
        owner: vagrant
        group: vagrant
      when: "'master' in group_names"
    - name: Deploy Network Plugins
      shell: |
        kubectl create -f https://class-git.myk8s.cn/cnlxh/Kubernetes/raw/refs/heads/master/cka-yaml/calico.yaml
      register: result
      until: result.rc == 0
      retries: 5
      delay: 2
      when: "'master' in group_names"
    - name: join workers
      shell: |
        join=`sshpass -p vagrant ssh -A -g -o StrictHostKeyChecking=no root@k8s-master kubeadm token create --print-join-command`
        echo $join --cri-socket=unix:///run/cri-dockerd.sock | bash
      register: result
      until: result.rc == 0
      retries: 5
      delay: 2
      when: "'worker' in group_names"
    - name: assign worker role label to workers
      shell: |
        sleep 10
        kubectl label nodes k8s-worker2 k8s-worker1 node-role.kubernetes.io/worker=
      when: "'master' in group_names"
EOF

cp /etc/ansible/ansible.cfg /root/ansible.cfg
if [ $? -ne 0 ];then
echo please review the output on screen and fix error before re-run && exit;
fi
sed -i '/^# command_warnings.*/a\command_warnings = False' /root/ansible.cfg
if [ $? -ne 0 ];then
exit;
fi
echo
echo 'Deploy K8S Cluster now'
echo
ansible-playbook create-k8s.yaml -e "dockerhub_username=$dockerhub_username dockerhub_password=$dockerhub_password"
if [ $? -ne 0 ];then
exit;
fi
rm -rf create-k8s.yaml /root/ansible.cfg /root/kubeadm.yaml /root/Create-K8S-With-Containerd.sh /tmp/installdetails.log cri-dockerd* wget-log
sshpass -p vagrant ssh -A -g -o StrictHostKeyChecking=no root@k8s-worker1 'rm -rf create-k8s.yaml /root/ansible.cfg /root/kubeadm.yaml /root/Create-K8S-With-Containerd.sh /tmp/installdetails.log cri-dockerd* wget-log'
sshpass -p vagrant ssh -A -g -o StrictHostKeyChecking=no root@k8s-worker2 'rm -rf create-k8s.yaml /root/ansible.cfg /root/kubeadm.yaml /root/Create-K8S-With-Containerd.sh /tmp/installdetails.log cri-dockerd* wget-log'


kubectl completion bash > /etc/bash_completion.d/kubectl
kubeadm completion bash > /etc/bash_completion.d/kubeadm
source /etc/bash_completion.d/kubectl
source /etc/bash_completion.d/kubeadm

echo

echo "Please wait one minute for nodes ready, please type: 'kubectl get pod -A' if not ready"

echo

echo

sleep 1m

kubectl get nodes

echo

echo