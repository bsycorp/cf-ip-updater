data "aws_ip_ranges" "cloudfront_ips" {
  services = ["CLOUDFRONT"]
}

locals {
  max_rules_per_sg = 50

  # Chunk the list of all CloudFront CIDRs into blocks of N. Each block
  # will go into it's own security group.
  cfips = "${chunklist(
      data.aws_ip_ranges.cloudfront_ips.cidr_blocks, 
      local.max_rules_per_sg
  )}"

  # We append 3 empty lists below because we're going to construct 3 security
  # groups and we want to make sure we never index past the end of cfips. 
  cfips_padded = "${concat(local.cfips, list(list(), list(), list()))}"
}

resource "aws_security_group" "ext-ingress-cf" {
  name = "${var.resource_prefix}-ext-ingress-cf-${count.index}"
  description = "Security group for external ingress ALB CloudFront CIDRs ${count.index + 1} / 3"
  vpc_id = "${var.vpc_id}"
  count = 3
  revoke_rules_on_delete = true

  # allow localhost, this is to avoid unecessary cf-ip-updater applies
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["127.0.0.1/32"]
  }

  # From cloudfront -> ALB port 443
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [
      "${local.cfips_padded[count.index]}"
    ]
  }
}
