# 기존 state 주소를 새 코드 주소로 "이동"시켜서 destroy/add를 없앰 (마이그레이션 정석)

moved {
  from = aws_route.public_default
  to   = aws_route.public_0
}

moved {
  from = aws_route.private_default
  to   = aws_route.private_0
}

moved {
  from = aws_security_group.jenkins
  to   = module.jenkins.aws_security_group.jenkins
}
