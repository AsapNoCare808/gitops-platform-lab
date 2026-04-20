remote_state {
  backend = "s3"
  config = {
    bucket = "my-bucket-maxto-platform.cloud"
    key    = "${path_relative_to_include()}/terraform.tfstate"
    region = "eu-west-3"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
