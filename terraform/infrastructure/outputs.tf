output "Public_IP_EC2_Instance" {
  value = aws_instance.Infra_GitOps.public_ip
}