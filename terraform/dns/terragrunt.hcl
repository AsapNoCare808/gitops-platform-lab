include "root" {
  path = find_in_parent_folders()
}

dependency "infrastructure" {
  config_path = "../infrastructure"
  mock_outputs = {
    Public_IP_EC2_Instance = "0.0.0.0"
    vpc_id                 = "mock-vpc-id"
    subnet_id              = "mock-subnet-id"
  }
  mock_outputs_allowed_terraform_commands = ["destroy", "plan"]
}
