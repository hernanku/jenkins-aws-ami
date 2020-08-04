output "vpc_id" {
    value = aws_vpc.jenkinscc_vpc.id
}

output "load_balancer_dns" {
    value = aws_elb.jenkinscc_elb.dns_name
}

