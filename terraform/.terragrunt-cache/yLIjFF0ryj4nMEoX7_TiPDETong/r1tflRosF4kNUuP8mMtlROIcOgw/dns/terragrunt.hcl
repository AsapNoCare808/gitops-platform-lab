include "root" {
  path = find_in_parent_folders()
}

dependency "infrastructure" {
  config_path = "../infrastructure"
}
