variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "name_prefix" {
  type    = string
  default = "jsh"
}

variable "vpc_cidr" {
  type    = string
  default = "172.3.0.0/16"
}

# Public (NAT/IGW용)
variable "public_a_cidr" {
  type    = string
  default = "172.3.1.0/24"
}

variable "public_c_cidr" {
  type    = string
  default = "172.3.2.0/24"
}

# Private (Jenkins 등)
variable "private_a_cidr" {
  type    = string
  default = "172.3.11.0/24"
}

variable "private_c_cidr" {
  type    = string
  default = "172.3.12.0/24"
}

variable "tags" {
  type = map(string)
  default = {
    Owner = "jsh"
  }
}

