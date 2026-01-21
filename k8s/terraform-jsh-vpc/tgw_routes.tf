########################################
# VPC Route -> TGW (to On-Prem)
########################################

# Private RT에서 온프렘(192.168.3.0/24)로 가는 트래픽은 TGW로 보낸다.
# 이 RT는 당신 콘솔에서 확인한 jsh-rt-private(Private Subnet용 RT)여야 합니다.
resource "aws_route" "private_to_onprem_192_168_3" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "192.168.3.0/24"
  transit_gateway_id     = aws_ec2_transit_gateway_vpc_attachment.jsh.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.jsh]
}
