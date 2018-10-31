# Cloudfront IP updater

## What does it do
It periodically check Cloudfront edge server IP addresses, and update the kube external ingress security group to lock access down to Cloudfront only.

## Components

#### Terraform
The terraform script only contains `aws_security_group` and `aws_security_group` resources, and uses local state.

#### Kubernetes cronjob
The terraform job runs as a Kubernetes cronjob hourly

#### IAM
A kube2iam role be attached to kube deployment which allows access to the security group.