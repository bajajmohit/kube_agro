# Instance Information
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.kube_master.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.kube_master_eip.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.kube_master.private_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.kube_master.public_dns
}

# Existing Infrastructure Information
output "vpc_id" {
  description = "ID of the existing VPC used"
  value       = data.aws_vpc.existing_vpc.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the existing VPC"
  value       = data.aws_vpc.existing_vpc.cidr_block
}

output "subnet_id" {
  description = "ID of the existing subnet used"
  value       = data.aws_subnet.existing_subnet.id
}

output "subnet_cidr_block" {
  description = "CIDR block of the existing subnet"
  value       = data.aws_subnet.existing_subnet.cidr_block
}

output "subnet_availability_zone" {
  description = "Availability zone of the existing subnet"
  value       = data.aws_subnet.existing_subnet.availability_zone
}

output "security_group_id" {
  description = "ID of the created security group"
  value       = aws_security_group.kube_master_sg.id
}

# Access Information
output "ssh_command" {
  description = "SSH command to connect to the instance (only if SSH key is configured)"
  value       = var.public_key != "" ? "ssh -i <your-private-key> ec2-user@${aws_eip.kube_master_eip.public_ip}" : "SSH key not configured - use AWS Systems Manager Session Manager or EC2 Instance Connect"
}

output "argocd_access_info" {
  description = "Information for accessing ArgoCD"
  value = {
    url      = "http://${aws_eip.kube_master_eip.public_ip}"
    username = "admin"
    password = "Check /home/ec2-user/argocd-password.txt on the instance"
    port_forward = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
  }
}

# Kubernetes Information
output "kubectl_config_command" {
  description = "Command to configure kubectl locally (only if SSH key is configured)"
  value       = var.public_key != "" ? "scp -i <your-private-key> ec2-user@${aws_eip.kube_master_eip.public_ip}:/home/ec2-user/.kube/config ~/.kube/config" : "SSH key not configured - use AWS Systems Manager Session Manager to access kubectl config"
}

output "setup_completion_check" {
  description = "Command to check if Kubernetes setup is complete (only if SSH key is configured)"
  value       = var.public_key != "" ? "ssh -i <your-private-key> ec2-user@${aws_eip.kube_master_eip.public_ip} 'ls -la /home/ec2-user/kube-setup-complete'" : "SSH key not configured - use AWS Systems Manager Session Manager to check setup status"
}
