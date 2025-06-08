# Include root terragrunt.hcl which contains all common configuration
include "root" {
  path           = find_in_parent_folders("root.hcl")
  expose         = true
  merge_strategy = "deep"
}
