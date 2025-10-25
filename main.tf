# Configure the AWS Provider
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source to get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source to get existing VPC
data "aws_vpc" "existing_vpc" {
  id = var.vpc_id
}

# Data source to get existing subnet
data "aws_subnet" "existing_subnet" {
  id = var.subnet_id
}

# Data source to get existing internet gateway (if any)
data "aws_internet_gateway" "existing_igw" {
  count = var.internet_gateway_id != "" ? 1 : 0
  internet_gateway_id = var.internet_gateway_id
}

# Security Group for Kubernetes Master Node
resource "aws_security_group" "kube_master_sg" {
  name_prefix = "${var.project_name}-master-sg"
  vpc_id      = data.aws_vpc.existing_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # etcd server client API
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.existing_vpc.cidr_block]
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.existing_vpc.cidr_block]
  }

  # kube-scheduler
  ingress {
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.existing_vpc.cidr_block]
  }

  # kube-controller-manager
  ingress {
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.existing_vpc.cidr_block]
  }

  # NodePort Services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ArgoCD Server (default port)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-master-sg"
  }
}

# Key Pair for SSH access
resource "aws_key_pair" "kube_key" {
  key_name   = "${var.project_name}-key"
  public_key = var.public_key

  tags = {
    Name = "${var.project_name}-key"
  }
}

# User data script for EC2 instance initialization
locals {
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    
    # Install Docker
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
    
    # Install kubeadm, kubelet, kubectl
    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
    enabled=1
    gpgcheck=1
    gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
    exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
    EOF
    
    # Set SELinux in permissive mode
    setenforce 0
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    
    # Install kubelet, kubeadm, kubectl
    yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    systemctl enable kubelet
    
    # Configure containerd
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    systemctl restart containerd
    systemctl enable containerd
    
    # Configure sysctl
    cat <<EOF > /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-ip6tables = 1
    net.bridge.bridge-nf-call-iptables = 1
    net.ipv4.ip_forward = 1
    EOF
    sysctl --system
    
    # Load br_netfilter module
    modprobe br_netfilter
    echo 'br_netfilter' >> /etc/modules-load.d/k8s.conf
    
    # Initialize Kubernetes cluster
    kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    
    # Configure kubectl for ec2-user
    mkdir -p /home/ec2-user/.kube
    cp -i /etc/kubernetes/admin.conf /home/ec2-user/.kube/config
    chown ec2-user:ec2-user /home/ec2-user/.kube/config
    
    # Install Flannel CNI
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
    
    # Install ArgoCD
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo "ArgoCD admin password: $ARGOCD_PASSWORD" > /home/ec2-user/argocd-password.txt
    chown ec2-user:ec2-user /home/ec2-user/argocd-password.txt
    
    # Install ArgoCD CLI
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
    
    # Create a simple script to access ArgoCD
    cat <<EOF > /home/ec2-user/access-argocd.sh
    #!/bin/bash
    echo "ArgoCD is accessible at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
    echo "Admin password: \$(cat /home/ec2-user/argocd-password.txt)"
    echo ""
    echo "To port-forward ArgoCD locally:"
    echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "Then access: https://localhost:8080"
    EOF
    chmod +x /home/ec2-user/access-argocd.sh
    chown ec2-user:ec2-user /home/ec2-user/access-argocd.sh
    
    # Signal completion
    touch /home/ec2-user/kube-setup-complete
    chown ec2-user:ec2-user /home/ec2-user/kube-setup-complete
  EOF
}

# EC2 Instance for Kubernetes Master Node
resource "aws_instance" "kube_master" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.kube_key.key_name
  vpc_security_group_ids = [aws_security_group.kube_master_sg.id]
  subnet_id              = data.aws_subnet.existing_subnet.id
  user_data              = base64encode(local.user_data)

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-master"
    Type = "Kubernetes-Master"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP for the instance
resource "aws_eip" "kube_master_eip" {
  instance = aws_instance.kube_master.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-master-eip"
  }

  depends_on = [data.aws_internet_gateway.existing_igw]
}
