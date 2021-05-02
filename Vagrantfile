# -*- mode: ruby -*-
# vi: set ft=ruby :

NODES_NUM = 1
IP_BASE = "192.168.33"

scriptHost = <<SCRIPT
cat >> /etc/hosts <<EOF
192.168.33.10 kmaster
192.168.33.11 kslave1
192.168.33.12 kslave2
EOF
SCRIPT

scriptNodePort = <<SCRIPT
cat > k8_db_nodeport.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  namespace: kubernetes-dashboard
  name: k8-svc-dashboard-nodeport
  labels:
    k8s-app: kubernetes-dashboard
spec:
  type: NodePort
  ports:
  - port: 8443
    nodePort: 30002
    targetPort: 8443
    protocol: TCP
  selector:
    k8s-app: kubernetes-dashboard
EOF
SCRIPT

ts = Time.now.to_i

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"
  config.vm.synced_folder ".", "/vagrant", disabled: false
  # config.ssh.forward_agent = true

  config.trigger.after :up do |trigger|
    trigger.name = "POST ALL Provision"
    trigger.info = "Cluster is up!!"
    #trigger.run_remote = {inline: "pg_dump dbname > /vagrant/outfile"}
  end

  #-- Master Node
  config.vm.define "kmaster" do | k8m |
    k8m.vm.hostname = "kmaster"
    k8m.vm.network "private_network", ip: "#{IP_BASE}.10"
    k8m.vm.network "forwarded_port", guest: 6443, host: 6443, protocol: "tcp"
    k8m.vm.network "forwarded_port", guest: 30002, host: 30002, protocol: "tcp"
    k8m.vm.provider "virtualbox" do |vb|
      vb.name = "kmaster"

      vb.memory = "4096"
      vb.cpus = 2

      vb.customize ["modifyvm", :id, "--ioapic", "on"]
      vb.customize ['modifyvm', :id, '--clipboard', 'bidirectional']

      vb.gui = false
      # vb.customize ["modifyvm", :id, "--graphicscontroller", "vboxvga"]
      # vb.customize ["modifyvm", :id, "--vram", "64"]
      # vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
      # vb.customize ["modifyvm", :id, "--accelerate3d", "on"]
    end
    k8m.vm.provision "setup-hosts", :type => "shell", :path => "bootstrap-k8.sh" do |s|
    end
    k8m.vm.provision "shell", :inline => scriptHost
    k8m.vm.provision "shell", :inline => scriptNodePort
    k8m.vm.provision "shell", inline: <<-SHELL
      # apt-get install -y apache2

      echo "------------- Configuring Kubernetes -------------"
      kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=#{IP_BASE}.10 --node-name kmaster
      mkdir -p /home/vagrant/.kube
      cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
      chown vagrant:vagrant /home/vagrant/.kube/config

      export KUBECONFIG=/etc/kubernetes/admin.conf

      echo "------------- Deploying Calico -------------"
      kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
      kubeadm token create --print-join-command > /vagrant/join-#{ts}.sh

      sleep 5

      echo "------------- Installing Dashboard + Nodeport -------------"
      kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml
      kubectl apply -f k8_db_nodeport.yaml
      kubectl get pods -A
      kubectl create serviceaccount dashboard -n default
      kubectl create clusterrolebinding dashboard-admin -n default --clusterrole=cluster-admin --serviceaccount=default:dashboard
      kubectl create clusterrolebinding cluster-system-anonymous --clusterrole=cluster-admin --user=system:anonymous
      kubectl label nodes kslave01 kubernetes.io/role=worker
      kubectl proxy &
      sleep 5

      echo "------------- Validating Cluster -------------"
      echo "External Link: https://#{IP_BASE}.10:30002/"
      tail -10 /var/log/syslog
      kubectl cluster-info
      kubectl get pods -o wide --all-namespaces
      kubectl get nodes -o wide

      echo "------------- Dashboard Details -------------"
      echo "External Link: https://#{IP_BASE}.10:30002/#/login"
      kubectl -n kubernetes-dashboard describe service kubernetes-dashboard
      kubectl describe secret $(kubectl get serviceaccount dashboard -o jsonpath="{.secrets[0].name}")
      
    SHELL
  end

  #-- Slave Node(s)
  (1..NODES_NUM).each do |i|
    config.vm.define "kslave#{i}" do | k8s |
      k8s.vm.hostname = "kslave#{i}"
      k8s.vm.network "private_network", ip: "#{IP_BASE}.#{i + 10}"
      k8s.vm.provider "virtualbox" do |vb|
        vb.name = "kslave#{i}"
  
        vb.memory = "1024"
        vb.cpus = 1
  
        vb.customize ["modifyvm", :id, "--ioapic", "on"]
        vb.customize ['modifyvm', :id, '--clipboard', 'bidirectional']
  
        # vb.gui = true
        # vb.customize ["modifyvm", :id, "--graphicscontroller", "vboxvga"]
        # vb.customize ["modifyvm", :id, "--vram", "64"]
        # vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
        # vb.customize ["modifyvm", :id, "--accelerate3d", "on"]
      end
      k8s.vm.provision "setup-hosts", :type => "shell", :path => "bootstrap-k8.sh" do |s|
      end
      k8s.vm.provision "shell", inline: <<-SHELL
        apt-get install -y apache2
  
        echo "------------- Joining Cluster -------------"
        chmod +x /vagrant/join-#{ts}.sh
        bash /vagrant/join-#{ts}.sh
        #kubectl label nodes kslave01 kubernetes.io/role=worker
      SHELL
    end
  end
end

