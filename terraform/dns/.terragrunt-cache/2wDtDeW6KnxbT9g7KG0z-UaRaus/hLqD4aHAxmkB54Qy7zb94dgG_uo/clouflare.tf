terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

provider "cloudflare" {
  api_token = file("/Users/maxto/.clouflare/dns_api_token")
}

# Create DNS records for the staging environment

resource "cloudflare_dns_record" "app-staging" {
  zone_id = var.zone_id
  name    = "app.staging"
  type    = "A"
  content   = data.terraform_remote_state.infra.outputs.Public_IP_EC2_Instance
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "grafana-staging" {
  zone_id = var.zone_id
  name    = "grafana.staging"
  type    = "A"
  content   = data.terraform_remote_state.infra.outputs.Public_IP_EC2_Instance
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "argocd-staging" {
  zone_id = var.zone_id
  name    = "argocd.staging"
  type    = "A"
  content   = data.terraform_remote_state.infra.outputs.Public_IP_EC2_Instance
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "defectdojo-staging" {
  zone_id = var.zone_id
  name    = "defectdojo.staging"
  type    = "A"
  content   = data.terraform_remote_state.infra.outputs.Public_IP_EC2_Instance
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "vault-staging" {
  zone_id = var.zone_id
  name    = "vault.staging"
  type    = "A"
  content   = data.terraform_remote_state.infra.outputs.Public_IP_EC2_Instance
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "lab-staging" {
  zone_id = var.zone_id
  name    = "lab.staging"
  type    = "A"
  content   = data.terraform_remote_state.infra.outputs.Public_IP_EC2_Instance
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "registry-staging" {
  zone_id = var.zone_id
  name    = "registry.staging"
  type    = "A"
  content   = data.terraform_remote_state.infra.outputs.Public_IP_EC2_Instance
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "kas-staging" {
  zone_id = var.zone_id
  name    = "kas.staging"
  type    = "A"
  content   = data.terraform_remote_state.infra.outputs.Public_IP_EC2_Instance
  ttl     = 300
  proxied = false
}

resource "cloudflare_dns_record" "minio-staging" {
  zone_id = var.zone_id
  name    = "minio.staging"
  type    = "A"
  content   = data.terraform_remote_state.infra.outputs.Public_IP_EC2_Instance
  ttl     = 300
  proxied = false
}

data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket = "my-bucket-maxto-platform.cloud"
    key    = "infrastructure/terraform.tfstate"
    region = "eu-west-3"
  }
}