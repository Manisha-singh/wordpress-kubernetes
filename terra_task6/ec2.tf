resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

variable "enter_your_key_name"{
  type = string
  default= "keypair"
}
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41 email@example.com"
}
provider "aws" {
  region    = "ap-south-1"
  profile   = "mannu"
}
 

resource "aws_instance" "instance1" {
  ami          = "ami-052c08d70def0ac62"
  instance_type = "t2.large"
  key_name = "keypair"
  security_groups = [ "allow_tls" ]
  user_data     = <<-EOF
	#!/bin/bash
	sudo su
	cd /root
	yum -y install httpd wget zip 
	curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
  && chmod +x minikube
	sudo mkdir -p /usr/local/bin/
	sudo cp /root/minikube /usr/bin
	sudo setenforce 0
	sudo sed -i "s/^SELINUX=enforcing$/SELINUX=permissive/" /etc/selinux/config
	sudo touch /etc/yum.repos.d/kubernetes.repo 
	echo " 
	[kubernetes]
	name=Kubernetes
	baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
	enabled=1
	gpgcheck=1
	repo_gpgcheck=1
	gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
	exclude=kubelet kubeadm kubectl " >> /etc/yum.repos.d/kubernetes.repo 
	sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
	sudo systemctl enable --now kubelet
	sudo minikube start --driver=none
  	sudo curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
	sudo touch /etc/yum.repos.d/docker.repo 
	echo "
	[docker]
	baseurl=https://download.docker.com/linux/centos/7/x86_64/stable/
	gpgcheck=0 " >> /etc/yum.repos.d/docker.repo 
	sudo yum install docker-ce --nobest -y
	sudo systemctl start docker
	sudo systeemctl enable docker.service
	sudo minikube start --driver=none
	sudo touch /root/wordpress.yml
	echo "
	---
  apiVersion: v1
  kind: Service
  metadata:
    name: wordpress
    labels:
      app: wordpress
  spec:
    ports:
      - port: 80
        nodePort: 31565
        protocol: TCP 
    selector:
      app: wordpress
      tier: frontend
    type: LoadBalancer" >> /root/service.yml
	echo "
	---
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: wp-pv-claim1
    labels:
      app: wordpress
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 20Gi" >>/root/volume.yml
	echo "
	---
  apiVersion: apps/v1 # for versions before 1.9.0 use apps/v1beta2
  kind: Deployment
  metadata:
    name: wordpress
    labels:
      app: wordpress
  spec:
    selector:
      matchLabels:
        app: wordpress
        tier: frontend
    strategy:
      type: Recreate
    template:
      metadata:
        labels:
          app: wordpress
          tier: frontend
      spec:
        containers:
        - image: wordpress
          name: wordpress
          ports:
          - containerPort: 80
            name: wordpress
          volumeMounts:
          - name: wordpress-persistent-storage
            mountPath: /var/www/html
        volumes:
        - name: wordpress-persistent-storage
          persistentVolumeClaim:
            claimName: wp-pv-claim1" >> /root/wordpress.yml
	sudo kubectl apply -f /root/service.yml
	sudo kubectl apply -f /root/volume.yml
	sudo kubectl apply -f /root/wordpress.yml
	sudo wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-386.tgz
	sudo tar -xvf ngrok-stable-linux-386.tgz
	EOF
  tags = {
    Name = "Linuxos"
  }

}

resource "aws_db_instance" "default" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "mydb"
  username             = "admin"
  password             = "manishasingh"
  port                       =  "3306"
  publicly_accessible= "true"
  backup_retention_period= 0
  final_snapshot_identifier="mysql-backup"
  skip_final_snapshot="true"
  parameter_group_name = "default.mysql5.7"
}


