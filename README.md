# Kubernetes + ArgoCD on AWS

This Terraform configuration creates an EC2 instance with Kubernetes (kubeadm) and ArgoCD pre-installed on AWS.

## What's Included

- **EC2 Instance**: Amazon Linux 2 with Kubernetes cluster initialized using kubeadm
- **Networking**: VPC, public subnet, internet gateway, and security groups
- **Kubernetes**: Single-node cluster with Flannel CNI
- **ArgoCD**: GitOps continuous delivery tool pre-installed and configured
- **Security**: Proper security groups with required ports for Kubernetes and ArgoCD

## Prerequisites

1. **AWS CLI configured** with appropriate permissions
2. **Terraform installed** (version >= 1.0)
3. **Existing VPC and Subnet** in your AWS account
4. **SSH key pair** (optional) for accessing the EC2 instance

## Infrastructure Configuration

This configuration uses hardcoded AWS infrastructure resources:

- **VPC ID**: `vpc-2dc2d444`
- **Subnet ID**: `subnet-5f25ec37` 
- **Internet Gateway ID**: `igw-6098f609`
- **Route Table ID**: `rtb-cf9378a7`

These resources are pre-configured and don't need to be specified in your `terraform.tfvars` file.

## Quick Start

1. **Clone and navigate to the repository**:
   ```bash
   git clone <your-repo>
   cd kube_agro
   ```

2. **Generate SSH key pair** (optional - only if you want SSH access):
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/kube-agro-key
   ```

3. **Configure variables** (optional):
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars to customize:
   # - Instance type, volume size, region
   # - Optional: Your public key (leave empty to disable SSH access)
   # Note: VPC, subnet, and IGW are already hardcoded
   ```

4. **Initialize and apply Terraform**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

5. **Access your cluster**:
   ```bash
   # Get the public IP from terraform output
   terraform output instance_public_ip
   
   # If SSH key is configured:
   ssh -i ~/.ssh/kube-agro-key ec2-user@<public-ip>
   
   # If no SSH key, use AWS Systems Manager Session Manager:
   aws ssm start-session --target <instance-id>
   
   # Check if setup is complete
   ls -la /home/ec2-user/kube-setup-complete
   ```

## Accessing ArgoCD

### Method 1: Direct Access (HTTP)
```bash
# Get the public IP
terraform output instance_public_ip

# Access ArgoCD UI
http://<public-ip>
```

### Method 2: Port Forward (Recommended)
```bash
# If SSH key is configured:
ssh -i ~/.ssh/kube-agro-key ec2-user@<public-ip>

# If no SSH key, use AWS Systems Manager Session Manager:
aws ssm start-session --target <instance-id>

# Port forward ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access locally
https://localhost:8080
```

### ArgoCD Login Credentials
- **Username**: `admin`
- **Password**: Check `/home/ec2-user/argocd-password.txt` on the instance

## Configuration Options

Edit `terraform.tfvars` to customize:

- **AWS Region**: Change `aws_region` (default: us-west-2)
- **Instance Type**: Modify `instance_type` (default: t3.medium)
- **Volume Size**: Adjust `volume_size` (default: 20GB)
- **Infrastructure**: Uses hardcoded VPC, subnet, and IGW IDs

### Required Variables:
- None (all infrastructure IDs are hardcoded)

### Optional Variables:
- `public_key`: SSH public key (leave empty to disable SSH access)
- `instance_type`: EC2 instance type (default: t3.medium)
- `volume_size`: Root volume size (default: 20GB)
- `aws_region`: AWS region (default: us-west-2)

## Important Notes

- **Single Node Cluster**: This creates a single-node Kubernetes cluster suitable for development/testing
- **Setup Time**: Initial setup takes 5-10 minutes after instance launch
- **Security**: The instance is publicly accessible - consider using VPN or bastion host for production
- **Cost**: Monitor AWS costs as the instance runs continuously

## Troubleshooting

### Check Setup Status
```bash
# If SSH key is configured:
ssh -i ~/.ssh/kube-agro-key ec2-user@<public-ip>
sudo journalctl -u kubelet -f  # Check kubelet logs
kubectl get pods --all-namespaces  # Check pod status

# If no SSH key, use AWS Systems Manager Session Manager:
aws ssm start-session --target <instance-id>
sudo journalctl -u kubelet -f
kubectl get pods --all-namespaces
```

### Common Issues
1. **Setup incomplete**: Wait a few more minutes and check `/home/ec2-user/kube-setup-complete`
2. **ArgoCD not accessible**: Ensure security group allows ports 80/443
3. **SSH connection refused**: Check security group allows port 22

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Architecture

```
Internet Gateway (existing)
       |
   Existing VPC
       |
   Existing Subnet
       |
   EC2 Instance (t3.medium)
   ├── Kubernetes Master Node
   ├── ArgoCD Server
   └── Flannel CNI
```

**Note**: This configuration uses your existing VPC and subnet infrastructure instead of creating new ones.

## Security Groups

The configuration includes security groups with the following ports:
- **22**: SSH access
- **80/443**: ArgoCD web interface
- **6443**: Kubernetes API server
- **10250**: Kubelet API
- **30000-32767**: NodePort services
- **2379-2380**: etcd server
- **10257/10259**: Controller manager and scheduler
