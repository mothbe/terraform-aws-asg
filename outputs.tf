output "lb_endpoint" {
  value = "http://${aws_lb.terra.dns_name}"
}

