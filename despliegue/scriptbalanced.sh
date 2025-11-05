#!/bin/bash

# Creo un nuevo grupo de seguridad

GS_ID=$(aws ec2 create-security-group \
    --group-name vpc-bc \
     --description "Grupo de seguridad para el balanceador" \
      --vpc-id vpc-050e504cff33ea6c7 \
      --query GroupId \
      --output text )

echo "Se ha creado el grupo de seguridad cuyo id es $GS_ID"

# Autorizo los servicios SSH y web al grupo de seguridad

aws ec2 authorize-security-group-ingress \
    --group-id $GS_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id $GS_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0


# CReo el target group

TG_ARN=$(aws elbv2 create-target-group \
    --name TG-BG-CLI \
    --protocol HTTP \
    --port 80 \
    --target-type instance \
    --query TargetGroups.
    --vpc-id vpc-050e504cff33ea6c7)

echo $TG_ARN

aws elbv2 register-targets \
    --target-group-arn $TG_ARN \
    --targets Id=i-0d7bd2c755b92c6db Id=i-0fd49a8f345979f4c

# Creo el balanceador 

# aws elb create-load-balancer \
#      --load-balancer-name balanceador-cli \
#      --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" \
#      --subnets subnet-0c709c7ea670a67a8 --security-groups $GS_ID

# aws elbv2 create-listener \
#     --load-balancer-arn $TG_ARN \
#     --protocol HTTP \
#     --port 80 \
#     --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/my-targets/73e2d6bc24d8a067
