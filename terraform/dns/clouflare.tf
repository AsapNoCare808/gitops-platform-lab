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

resource "cloudflare_record" "app" {
  zone_id = var.zone_id
  name    = "app.staging"
  type    = "A"
  value   = data.terraform_remote_state.infra.outputs.Public_IP_EC2_Instance
  ttl     = 300
  proxied = false
}

data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket = "my-tfstate-maxtop-latform.cloud"
    key    = "infrastructure/terraform.tfstate"
    region = "eu-west-3"
  }
}