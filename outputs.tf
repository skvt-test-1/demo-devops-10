output "public_ip_address" {
    # public IP address of my EC2 instance
    value = aws_instance.ec2-ubuntu-datawarehouse.public_ip
}