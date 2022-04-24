
# CLB DNS name
output "clb_dns_name" {
  value       = aws_elb.webapps_elb.dns_name
  description = "The domain name of the load balancer"
}

# RDS address
output "rds_address" {
  value       = aws_db_instance.mysql_rds.address
  description = "Connect to the database at this endpoint"
}