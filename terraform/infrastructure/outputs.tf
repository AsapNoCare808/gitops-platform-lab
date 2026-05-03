output "Public_IP_EC2_Instance" {
  value = aws_instance.Infra_GitOps.public_ip
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id" {
  value = aws_subnet.main.id
}