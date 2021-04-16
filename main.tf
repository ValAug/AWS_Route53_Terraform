#--main/root--

data "aws_availability_zone" "dedicateaz" {
  name = "us-west-2a"
}

resource "aws_vpc" "dns_env" {
  cidr_block           = cidrsubnet("10.0.0.0/20", 1, var.region_number[data.aws_availability_zone.dedicateaz.region])
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dnsenv"
  }
}

resource "aws_subnet" "pub_dns" {
  vpc_id                  = aws_vpc.dns_env.id
  cidr_block              = cidrsubnet(aws_vpc.dns_env.cidr_block, 1, var.az_number[data.aws_availability_zone.dedicateaz.name_suffix])
  map_public_ip_on_launch = false

  tags = {
    Name = "publicsubnet"
  }
}

resource "aws_internet_gateway" "webig" {
  vpc_id = aws_vpc.dns_env.id

  tags = {
    Name = "webinternetgw"
  }
}

resource "aws_route_table" "dnsenv_rt" {
  vpc_id = aws_vpc.dns_env.id
}

resource "aws_route" "rt_route" {
  route_table_id         = aws_route_table.dnsenv_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.webig.id
}


resource "aws_route_table_association" "rt_pub_access" {
  route_table_id = aws_route_table.dnsenv_rt.id
  subnet_id      = aws_subnet.pub_dns.id
}

resource "aws_instance" "myweb" {
  ami                         = "ami-0518bb0e75d3619ca"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.pub_dns.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  depends_on                  = [aws_internet_gateway.webig]


  user_data = <<-EOF
                  #!/bin/bash -xe
          yum -y update
          yum install -y httpd wget git
          cd /tmp
          git clone https://github.com/acantril/aws-sa-associate-saac02.git 
          cp ./aws-sa-associate-saac02/11-Route53/r53_zones_and_failover/01_a4lwebsite/* /var/www/html
          usermod -a -G apache ec2-user   
          chown -R ec2-user:apache /var/www
          chmod 2775 /var/www
          find /var/www -type d -exec chmod 2775 {} \;
          find /var/www -type f -exec chmod 0664 {} \;
          systemctl enable httpd
          systemctl start httpd
                  EOF

  tags = {
    Name = "mywebec2"
  }
}

resource "aws_eip" "webeip" {
  vpc = true

  tags = {
    Name = "mywebec2eip"
  }
}

resource "aws_eip_association" "webeip_assoc" {
  instance_id   = aws_instance.myweb.id
  allocation_id = aws_eip.webeip.id
}


resource "aws_security_group" "web_sg" {
  name        = "dnsevnsg"
  description = "Security group for pub  access"
  vpc_id      = aws_vpc.dns_env.id


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# resource "aws_s3_bucket" "webbucket" {
#   bucket = "www.augustovaldivia.ca"
#   acl = "public-read"
#   website {
#     index_document = "index.html"
#   }

#   tags = {
#     Name = "stacticweb"
#   }
# }

# resource "aws_s3_bucket_policy" "wbpolicy" {
#   bucket = aws_s3_bucket.webbucket.id
#   policy = jsonencode(
#       {
#           Version = "2012-10-17"
#           Id = "Thisbucketpolicy"
#           Statement = [
#               {
#                   Sid       = "PublicReadGetObject"
#                   Effect    = "Allow"
#                   Principal = "*"
#                   Action    = ["s3:GetObject"]
#                   Resource = [
#                     "${aws_s3_bucket.webbucket.arn}/*"
#                   ]
#               }
#           ]
#       }
#   )
# }

# resource "aws_s3_bucket_object" "object" {
#   bucket = aws_s3_bucket.webbucket.id
#   key = "index.html"
#   source = "/Users/katherinekruk/Desktop/Terraform/r53_tf/AWS_Route53_Terraform/s3file/index.html"
#   content_type = "text/html"
# }


# # resource "aws_route53_zone" "selected" {
# #   name         = "augustovaldivia.ca"

# # }

# data "aws_route53_zone" "my_zone" {
#     name = var.name
#     zone_id = var.zone_id

# }

# resource "aws_route53_health_check" "dnshcheck" {
#   fqdn              = "www.augustovaldiva.ca"
#   port              = 80
#   type              = "HTTP"
#   resource_path     = "/index.html"
#   failure_threshold = "3"
#   request_interval  = "10"
#   ip_address = aws_eip.webeip.public_ip

#   tags = {
#     Name = "primary-health-check"
#   }
# }

# resource "aws_route53_record" "ec2" {
#   zone_id = data.aws_route53_zone.my_zone.zone_id
#   name    = "www.${data.aws_route53_zone.my_zone.name}"
#   type    = "A"
#   ttl     = "60"
#   health_check_id = aws_route53_health_check.dnshcheck.id
#   records = [aws_eip.webeip.public_ip]
#   set_identifier = "ec2"

#   failover_routing_policy {
#     type = "PRIMARY"
#   }
# }

# resource "aws_route53_record" "s3" {
#   zone_id = data.aws_route53_zone.my_zone.zone_id
#   name = "www.${data.aws_route53_zone.my_zone.name}"
#   type = "A"
#   set_identifier = "s3"

#   alias {
#     name = aws_s3_bucket.webbucket.website_domain
#     zone_id = aws_s3_bucket.webbucket.hosted_zone_id
#     evaluate_target_health = true
#   }

#   failover_routing_policy {
#     type = "SECONDARY"
#   }
# }