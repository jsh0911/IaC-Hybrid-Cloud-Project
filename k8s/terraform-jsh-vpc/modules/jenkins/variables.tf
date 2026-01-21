variable "name_prefix" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "root_volume_size" {
  type = number
}

variable "key_name" {
  type    = string
  default = null
}

# S3는 이번 단계에서 "필수"로 강제 (count 분기 제거 목적)
variable "s3_bucket_arn" {
  type = string
}

variable "jenkins_admin_user" {
  type    = string
  default = "admin"
}
