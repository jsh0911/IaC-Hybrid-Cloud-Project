#!/bin/bash
set -e

apt-get update -y
apt-get install -y curl unzip git ca-certificates gnupg lsb-release fontconfig

# Docker (DockerHub push 용)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker ubuntu

# Java + Jenkins
apt-get install -y openjdk-17-jre
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins
systemctl enable jenkins
systemctl start jenkins

# AWS CLI v2 (S3 업로드)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# Ansible (온프렘 배포)
apt-get install -y ansible

# 초기 암호를 로그 파일로 남김 (SSM 접속 후 확인)
echo "Jenkins initial admin password:" > /var/log/jenkins-init-pass.txt
cat /var/lib/jenkins/secrets/initialAdminPassword >> /var/log/jenkins-init-pass.txt

