variable "consul_flavor" {
  default = "m1.small"
}

variable "bastion_flavor" {
  default = "m1.tiny"
}

variable "docker_flavor" {
  default = "m1.large"
}

variable "ssh_key_file" {
  default = "~/.ssh/id_rsa.terraform"
}

variable "ssh_user_name" {
  default = "debian"
}

variable "external_gateway" {}

variable "pool" {
  default = "public"
}
