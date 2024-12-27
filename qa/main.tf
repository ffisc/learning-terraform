module "qa" {
  source = "../modules/blog"

  # override default for `environment` variable
  environment = {
    name = "qa"
    network_prefix = "10.1"
  }

  # override others
  asg_max_size = 1
}