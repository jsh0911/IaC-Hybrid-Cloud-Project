data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "jenkins" {
  name_prefix = "${var.name_prefix}-jenkins-"
  description = "Jenkins EC2 in private subnet (SSM only)"
  vpc_id      = var.vpc_id

  # inbound: none (SSM-only)

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS outbound"
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.3.0/24"]
    description = "SSH to on-prem for Ansible"
  }


  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-jenkins-sg" })
}

resource "aws_iam_role" "jenkins" {
  name = "${var.name_prefix}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3 업로드 정책: count 없이 항상 생성 (s3_bucket_arn은 필수 변수)
resource "aws_iam_policy" "jenkins_s3" {
  name = "${var.name_prefix}-jenkins-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "S3WriteReadArtifacts"
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
      Resource = [var.s3_bucket_arn, "${var.s3_bucket_arn}/*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_s3_attach" {
  role       = aws_iam_role.jenkins.name
  policy_arn = aws_iam_policy.jenkins_s3.arn
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.name_prefix}-jenkins-instance-profile"
  role = aws_iam_role.jenkins.name
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  associate_public_ip_address = false
  key_name                    = var.key_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data_jenkins.sh.tpl", {
    jenkins_admin_user = var.jenkins_admin_user
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-jenkins-ec2" })
}
