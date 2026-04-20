data "aws_ami" "amazon" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023.11.20260406.2-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"] # Canonical
}



resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDqsXkreyPvQgBKXt/hSHKZtM2FcqndLgkn4JIQAROD4Pi+/nw8PPN2vbsxdLwkJ/OwKapfpVRLU047t1jklvd2RqWf+xsHAmkt6ftmzMow4qKvY/J5kGkKA+GRbQUoOX51uYgNNsFkkWZ6iMyD79ZtDPEQgCXa3SJRzFw+zITaU2avKCm2Ve4+kjn+MstYueQTo4IZaUDhHAx09nqb20jDRyjHtgBuwzuoJY/JSihQt38e2sbt02MpJks1EqbMPPXt34x3oZC9qY22eVRkQq8SKvd9VkdHFBFtZhq51oATpV8AzgJVy3lKssNkhnHPQKdC9qskXIBsUdY2XB2wYdtoQzctofwJGTksCAmYZ2KkPCOaOb06IHe8qIy89FQJ09+rNYfkgGwV22DICaNCpuHXVX88XzTwHDW8XvMqkKBlefj924qYK6qoCWkEZi80ODcFQ3ePxSPAYvYoDowtirUdDCLY1PmT+9POgarLQVd4I2ODMFYcpxJ9o/q2ULOhEpMlU6L5sUbSCMZ8vM5Q9LAK83sNJjkd3nUTblzKhlSlMnFztufkBhSVAtmnOACvhRefMtQeQ/3lHv22cgaNh44Z6dsg0IjPn1A9QC8Gsoi7l7SfcnilRsTBPmfXHi7m8byH5eFJJd5l0IxfQfR31obBDJs1JWturSh4mVC81sEzjQ== toris.maxime@gmail.com"
}

resource "aws_instance" "Infra_GitOps" {
  ami                         = data.aws_ami.amazon.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.deployer.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.allow_tls_ssh.id]
  subnet_id                   = aws_subnet.main.id
  user_data = file("${path.module}/user_data.sh")
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "Infra_GitOps"
  }
}
