output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_a_id" {
  value = aws_subnet.public_a.id
}

output "public_subnet_c_id" {
  value = aws_subnet.public_c.id
}

output "private_subnet_a_id" {
  value = aws_subnet.private_a.id
}

output "private_subnet_c_id" {
  value = aws_subnet.private_c.id
}

output "artifacts_bucket_name" {
  value = aws_s3_bucket.artifacts.bucket
}

# Jenkins (모듈 output 참조)
output "jenkins_instance_id" {
  value = module.jenkins.instance_id
}

output "jenkins_private_ip" {
  value = module.jenkins.private_ip
}

output "jenkins_security_group_id" {
  value = module.jenkins.security_group_id
}

