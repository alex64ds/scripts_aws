#!/bin/bash

# Creo un nuevo grupo de seguridad

GS_ID=$(aws ec2 create-security-group \
    --group-name vpc-bc \
     --description "Grupo de seguridad para el balanceador" \
      --vpc-id vpc-050e504cff33ea6c7 \
      --query GroupId \
      --output text )

echo $GS_ID

# Autorizo los servicios SSH y web al grupo de seguridad

aws ec2 authorize-security-group-ingress \
    --group-id $GS_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 > /dev/null

aws ec2 authorize-security-group-ingress \
    --group-id $GS_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 > /dev/null


# CReo el target group

TG_ARN=$(aws elbv2 create-target-group \
    --name TG-BG-CLI \
    --protocol HTTP \
    --port 80 \
    --target-type instance \
    --vpc-id vpc-050e504cff33ea6c7 \
    --query "TargetGroups[].TargetGroupArn" --output text)

echo $TG_ARN

aws elbv2 register-targets \
    --target-group-arn $TG_ARN \
    --targets Id=i-0d7bd2c755b92c6db Id=i-0fd49a8f345979f4c

# Creo el balanceador 

LB_ARN=$(aws elbv2 create-load-balancer \
    --name balanceador-cli \
    --type application \
    --subnets subnet-0c709c7ea670a67a8 subnet-05f39c5ec006769ab \
    --security-groups $GS_ID \
    --query LoadBalancers[].LoadBalancerArn \
    --output text )

echo $LB_ARN


aws elbv2 create-listener \
    --load-balancer-arn $LB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN > /dev/null
