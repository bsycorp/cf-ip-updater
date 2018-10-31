#!/bin/bash
set -e

# if the number of rules exceed this count then trigger a warning
SG_NUMBER_OF_RULES_WARNING=100

function onError {
  # if plan succeeded but apply failed wide open the first SG
  if test -f /tmp/plan-success && test ! -f /tmp/apply-success; then
    echo "Terraform apply failed, openning up ext ingress SG as emergency remedy."
    sendWarning "\`[cf-ip-updater][$TF_VAR_cluster_label]\` Terraform apply failed, opening up ext ingress security group as emergency remedy." || true
    aws ec2 authorize-security-group-ingress --group-id $TF_VAR_sg_id_0 --protocol tcp --port 443 --cidr 0.0.0.0/0
  else
    rm /tmp/plan-success || true
    rm /tmp/apply-success || true
  fi
  exit 1
}

# trap exit
trap onError EXIT

# get aws creds
eval $(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ | jq 'to_entries | [ .[] | select(.key | (contains("Expiration") or contains("RoleArn"))  | not) ] |  map(if .key == "AccessKeyId" then . + {"key":"AWS_ACCESS_KEY_ID"} else . end) | map(if .key == "SecretAccessKey" then . + {"key":"AWS_SECRET_ACCESS_KEY"} else . end) | map(if .key == "Token" then . + {"key":"AWS_SESSION_TOKEN"} else . end) | map("export \(.key)=\(.value)") | .[]' -r)

# terraform init, import and apply
terraform init
terraform import 'aws_security_group.ext-ingress-cf[0]' $TF_VAR_sg_id_0
terraform import 'aws_security_group.ext-ingress-cf[1]' $TF_VAR_sg_id_1
terraform import 'aws_security_group.ext-ingress-cf[2]' $TF_VAR_sg_id_2
# BUG workaround: remove the imported sg rules from tf state 
# as this will cause the first run to remove all sg rules
terraform state rm 'aws_security_group_rule.ext-ingress-cf[0]'
terraform state rm 'aws_security_group_rule.ext-ingress-cf[1]'
terraform state rm 'aws_security_group_rule.ext-ingress-cf[2]'

# check CIDRs count and alert if close to threshold
cidr_count=`curl -s https://ip-ranges.amazonaws.com/ip-ranges.json | jq '.prefixes[] | select(.service == "CLOUDFRONT") | .ip_prefix' | wc -l | xargs`
if test $cidr_count -gt ${SG_NUMBER_OF_RULES_WARNING}; then
  sendWarning "\`[cf-ip-updater][$TF_VAR_cluster_label]\` There are now \`$cidr_count\` CIDRs need to be whitelisted, the max capacity is \`150\`. Please consider adding extra security groups."
fi

# send slack alert
function sendWarning {
  if [ ! -z "$WARNING_WEBHOOK_URL" ]; then
    sendWebhook "{\"text\":\"$1\"}" || true
  fi
}
function sendWebhook {
    PAYLOAD=$1

    curl -X POST -H "Content-type: application/json" --data "$PAYLOAD" $WARNING_WEBHOOK_URL
}

# mark plan as success
touch /tmp/plan-success

# terraform apply
terraform apply -input=false -auto-approve
# mark apply as success
touch /tmp/apply-success

# no error, empty trap and exit 0
trap '' EXIT
exit 0
