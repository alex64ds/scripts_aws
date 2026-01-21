#!/bin/bash

# CREO VPC 

VPC_ID=$(aws ec2 create-vpc --cidr-block 192.168.0.0/24 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NUBEALEX},{Key=entorno,Value=prueba}]' \
     --query Vpc.VpcId --output text) 

echo "se ha lanzado una nueva VPC | ID -> $VPC_ID"

SUB1_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 192.168.0.0/28 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=mi_subred1_alex},{Key=entorno,Value=prueba}]' \
    --query Subnet.SubnetId --output text)

SUB2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 192.168.0.16/28 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=mi_subred2_alex},{Key=entorno,Value=prueba}]' \
    --query Subnet.SubnetId --output text)

echo "se han creado las subredes $SUB1_ID y $SUB2_ID"

# Creo grupo de seguridad y le doy permisos

SG_ID=$(aws ec2 create-security-group \
    --group-name gsalex \
    --description "Mi grupo de seguridad para abrir el puerto 22" \
    --vpc-id $VPC_ID \
    --query GroupId \
    --output text)
    
echo "se ha creado un nuevo grupo de seguridad | ID -> $SG_ID"

aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --ip-permissions '[{"IpProtocol": "tcp","FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow_SSH"}]}]' > /dev/null

echo "Se ha habilitado el puerto 22 a $SG_ID"

# Creo EC2

EC2_ID=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --key-name vockey \
    --subnet-id $SUB1_ID \
    --security-group-ids $SG_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2}]' \
    --query Instances.InstanceId --output text)


sleep 15


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2_ID"

