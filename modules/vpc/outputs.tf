output "vpc_id" {
  value = aws_vpc.alb_vpc.id
}

output "web_subnet_ids" {
  description = "IDs of all web-tier subnets, keyed by AZ"
  value = {
    for k, v in local.subnets : v.az => aws_subnet.this[k].id
    if v.tier == "web"
  }
}

output "app_subnet_ids" {
  description = "IDs of all the app-tier subnets, keyed by AZ"
  value = {
    for k, v in local.subnets : v.az => aws_subnet.this[k].id
    if v.tier == "web"
  }
}