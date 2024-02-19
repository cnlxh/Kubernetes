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
#    4. this tools will only install kubernetes v1.29.1-1.1 for CKA Exam upgrade, if you want other version, please modify kubeadm kubelet kubectl version in script
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

echo 'Install utility tool on k8s-master'
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
      shell: |
        cat > /etc/apt/sources.list <<EOF1
        deb https://mirror.nju.edu.cn/docker-ce/linux/ubuntu focal stable
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
        deb https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /
        EOF1

    - name: Deoloy docker and k8s gpg key
      shell: |
        cat > /etc/apt/docker.gpg <<'EOF2'
        -----BEGIN PGP PUBLIC KEY BLOCK-----

        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
        YT90qFF93M3v01BbxP+EIY2/9tiIPbrd
        =0YYh
        -----END PGP PUBLIC KEY BLOCK-----
        EOF2
        cat > /etc/apt/k8s.gpg <<'EOF3'
        -----BEGIN PGP PUBLIC KEY BLOCK-----
        Version: GnuPG v2.0.15 (GNU/Linux)

        mQENBGMHoXcBCADukGOEQyleViOgtkMVa7hKifP6POCTh+98xNW4TfHK/nBJN2sm
        u4XaiUmtB9UuGt9jl8VxQg4hOMRf40coIwHsNwtSrc2R9v5Kgpvcv537QVIigVHH
        WMNvXeoZkkoDIUljvbCEDWaEhS9R5OMYKd4AaJ+f1c8OELhEcV2dAQLLyjtnEaF/
        qmREN+3Y9+5VcRZvQHeyBxCG+hdUGE740ixgnY2gSqZ/J4YeQntQ6pMUEhT6pbaE
        10q2HUierj/im0V+ZUdCh46Lk/Rdfa5ZKlqYOiA2iN1coDPIdyqKavcdfPqSraKF
        Lan2KLcZcgTxP+0+HfzKefvGEnZa11civbe9ABEBAAG0PmlzdjprdWJlcm5ldGVz
        IE9CUyBQcm9qZWN0IDxpc3Y6a3ViZXJuZXRlc0BidWlsZC5vcGVuc3VzZS5vcmc+
        iQE+BBMBCAAoBQJjB6F3AhsDBQkEHrAABgsJCAcDAgYVCAIJCgsEFgIDAQIeAQIX
        gAAKCRAjRlTamilkNhnRCADud9iv+2CUtJGyZhhdzzd55wRKvHGmSY4eIAEKChmf
        1+BHwFnzBzbdNtnglY2xSATqKIWikzXI1stAwi8qR0dK32CS+ofMS6OUklm26Yd1
        jBWFg4LCCh8S21GLcuudHtW9QNCCjlByS4gyEJ+eYTOo2dWp88NWEzVXIKRtfLHV
        myHJnt2QLmWOeYTgmCzpeT8onl2Lp19bryRGla+Ms0AmlCltPn8j+hPeADDtR2bv
        7cTLDi/nA46u3SLV1P6yjC1ejOOswtgxppTxvLgYniS22aSnoqm47l111zZiZKJ5
        bCm1Th6qJFJwOrGEOu3aV1iKaQmN2k4G2DixsHFAU3ZeiQIcBBMBAgAGBQJjB6F3
        AAoJEM8Lkoze1k873TQP/0t2F/jltLRQMG7VCLw7+ps5JCW5FIqu/S2i9gSdNA0E
        42u+LyxjG3YxmVoVRMsxeu4kErxr8bLcA4p71W/nKeqwF9VLuXKirsBC7z2syFiL
        Ndl0ARnC3ENwuMVlSCwJO0MM5NiJuLOqOGYyD1XzSfnCzkXN0JGA/bfPRS5mPfoW
        0OHIRZFhqE7ED6wyWpHIKT8rXkESFwszUwW/D7o1HagX7+duLt8WkrohGbxTJ215
        YanOKSqyKd+6YGzDNUoGuMNPZJ5wTrThOkTzEFZ4HjmQ16w5xmcUISnCZd4nhsbS
        qN/UyV9Vu3lnkautS15E4CcjP1RRzSkT0jka62vPtAzw+PiGryM1F7svuRaEnJD5
        GXzj9RCUaR6vtFVvqqo4fvbA99k4XXj+dFAXW0TRZ/g2QMePW9cdWielcr+vHF4Z
        2EnsAmdvF7r5e2JCOU3N8OUodebU6ws4VgRVG9gptQgfMR0vciBbNDG2Xuk1WDk1
        qtscbfm5FVL36o7dkjA0x+TYCtqZIr4x3mmfAYFUqzxpfyXbSHqUJR2CoWxlyz72
        XnJ7UEo/0UbgzGzscxLPDyJHMM5Dn/Ni9FVTVKlALHnFOYYSTluoYACF1DMt7NJ3
        oyA0MELL0JQzEinixqxpZ1taOmVR/8pQVrqstqwqsp3RABaeZ80JbigUC29zJUVf
        =F4EX
        -----END PGP PUBLIC KEY BLOCK-----
        EOF3

        cat /etc/apt/docker.gpg | apt-key add -
        cat /etc/apt/k8s.gpg | apt-key add -
        apt update
    # - name: Deploy Docker Repository
    #   shell: |
    #     apt-get -y install apt-transport-https ca-certificates curl software-properties-common gnupg
    #     install -m 0755 -d /etc/apt/keyrings
    #     curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    #     chmod a+r /etc/apt/keyrings/docker.gpg
    #     curl -fsSL https://mirror.nju.edu.cn/docker-ce/linux/ubuntu/gpg | apt-key add -
    #     add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable"
    #     apt-get -y update

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
        - ca-certificates
        - curl
        - gnupg
        - docker-ce
        - docker-ce-cli
        - containerd.io
        - docker-buildx-plugin
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
        - name: Deploy CRI-Docker
          apt:
            deb: https://ghproxy.net/https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.10/cri-dockerd_0.3.10.3-0.ubuntu-focal_amd64.deb

      rescue:
        - name: clean apt lock
          shell: |
            rm -rf /var/lib/apt/lists/lock
            rm -rf /var/cache/apt/archives/lock
            rm -rf /var/lib/dpkg/lock*
            apt update  
        - name: Deploy CRI-Docker
          apt:
            deb: https://mirror.ghproxy.com/https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.10/cri-dockerd_0.3.10.3-0.ubuntu-focal_amd64.deb

    - name: modify sandbox image to aliyun
      shell: |
        sed -i 's/ExecStart=.*/ExecStart=\/usr\/bin\/cri-dockerd --container-runtime-endpoint fd:\/\/ --network-plugin=cni --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com\/google_containers\/pause:3.9/' /lib/systemd/system/cri-docker.service
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
    # - name: add kubernetes gpg key on ubuntu
    #   shell: |
    #     # cat > /etc/apt/sources.list.d/k8s.list <<EOF
    #     # deb https://mirror.nju.edu.cn/kubernetes/apt/ kubernetes-xenial main
    #     # EOF
    #     curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | apt-key add -
    #     apt update
    #   when: ansible_facts.distribution == 'Ubuntu'
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
          - kubeadm=1.29.1-1.1
          - kubelet=1.29.1-1.1
          - kubectl=1.29.1-1.1
          - sshpass
        state: present
    - name: clean apt lock
      shell: |
        rm -rf /var/lib/apt/lists/lock
        rm -rf /var/cache/apt/archives/lock
        rm -rf /var/lib/dpkg/lock*
        apt update
    - name: integrate with docker
      shell: crictl config runtime-endpoint unix:///run/cri-dockerd.sock
    - name: creating kubeadm.yaml
      shell: kubeadm config print init-defaults > kubeadm.yaml
      when: "'master' in group_names"
    - name: modify api server address
      shell: sed -i '/.*advertiseAddress.*/d' kubeadm.yaml
      when: "'master' in group_names"
    # - name: modify api server address
    #   lineinfile:
    #     path: kubeadm.yaml
    #     regexp: '.*advert.*'
    #     line: '  advertiseAddress: 192.168.8.3'
    #     state: present
    #   when: "'master' in group_names"
    - name: modify cluster name
      lineinfile:
        path: kubeadm.yaml
        regexp: '.*name.*'
        line: '  name: k8s-master'
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
        sshpass -p vagrant ssh -A -g -o StrictHostKeyChecking=no root@k8s-worker1 mkdir /root/.kube 
        sshpass -p vagrant ssh -A -g -o StrictHostKeyChecking=no root@k8s-worker2 mkdir /root/.kube
        scp /etc/kubernetes/admin.conf root@k8s-worker1:/root/.kube/config
        scp /etc/kubernetes/admin.conf root@k8s-worker2:/root/.kube/config
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
        join=`sshpass -p vagrant ssh -A -g -o StrictHostKeyChecking=no root@k8s-master kubeadm token create --print-join-command`
        echo $join --cri-socket=unix:///var/run/cri-dockerd.sock | bash
      when: "'worker' in group_names"
    - name: assign worker role label to workers
      shell: |
        sleep 30
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
ansible-playbook create-k8s.yaml
if [ $? -ne 0 ];then
exit;
fi
rm -rf create-k8s.yaml /root/ansible.cfg /root/kubeadm.yaml /root/Create-K8S-With-Docker.sh /root/installdetails.log

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