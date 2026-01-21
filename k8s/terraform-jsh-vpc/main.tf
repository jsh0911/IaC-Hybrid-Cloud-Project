data "aws_availability_zones" "available" {
  state = "available"
}

########################################
# VPC
########################################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

########################################
# Subnets (당신이 이미 쓰던 이름 그대로)
########################################
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_a_cidr
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-a"
  })
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_c_cidr
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-c"
  })
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_a_cidr
  availability_zone = "ap-northeast-2a"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-a"
  })
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_c_cidr
  availability_zone = "ap-northeast-2c"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-c"
  })
}

########################################
# Route tables
########################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-rt-public" })
}

resource "aws_route" "public_0" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

########################################
# NAT (프라이빗 Jenkins가 DockerHub/S3 나가려면 필수)
########################################
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-nat-eip" })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags          = merge(var.tags, { Name = "${var.name_prefix}-natgw" })

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-rt-private" })
}

resource "aws_route" "private_0" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}

########################################
# S3 Artifact bucket
########################################
resource "random_id" "s3_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.name_prefix}-artifacts-${random_id.s3_suffix.hex}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

########################################
# Jenkins module (Private EC2 + SSM + S3 권한)
########################################
module "jenkins" {
  source = "./modules/jenkins"

  name_prefix       = var.name_prefix
  tags              = var.tags
  vpc_id            = aws_vpc.main.id
  private_subnet_id = aws_subnet.private_a.id

  instance_type    = "t3.medium"
  root_volume_size = 30
  key_name         = null

  s3_bucket_arn      = aws_s3_bucket.artifacts.arn
  jenkins_admin_user = "admin"
}

