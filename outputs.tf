#---output/root---

output "ec2_public_dns" {
  value = aws_instance.myweb.public_dns
}

# output "s3_website_endpoint" {
#   value = aws_s3_bucket.webbucket.website_endpoint
# }