output "Public_IP_EC2_Instance" {
  value = aws_instance.Infra_GitOps.public_ip
}

output "vpc_id" {
  value = aws_vpc.Infra_GitOps.id
}

output "subnet_id" {
  value = aws_subnet.Infra_GitOps.id
}