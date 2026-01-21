########################################
# TGW <-> VPC Attachment
########################################

# 이미 존재하는 TGW에 VPC를 붙인다.
# TGW ID는 콘솔에서 확인한 값으로 고정.
resource "aws_ec2_transit_gateway_vpc_attachment" "jsh" {
  transit_gateway_id = "tgw-0da00b6c0a3194988"
  vpc_id             = aws_vpc.main.id

  # TGW Attachment는 일반적으로 private subnet에 붙입니다.
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_c.id
  ]

  dns_support  = "enable"
  ipv6_support = "disable"

  tags = merge(var.tags, { Name = "${var.name_prefix}-tgw-attach" })
}
