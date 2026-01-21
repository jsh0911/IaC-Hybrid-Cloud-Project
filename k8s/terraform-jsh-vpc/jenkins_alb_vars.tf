variable "admin_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDRs allowed to access Jenkins ALB (80). For security, use your public IP/32."
}
