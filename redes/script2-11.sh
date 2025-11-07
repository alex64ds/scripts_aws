#!/bin/bash

# CREO VPC 

VPC_ID=$(aws ec2 create-vpc --cidr-block 172.16.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NUBEALEX}]' \
     --query Vpc.VpcId --output text) 


# Creo gateway

GW_ID=$(aws ec2 create-internet-gateway \
     --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-alex}]' \
      --query InternetGateway.InternetGatewayId \
      --output text)


echo "se ha lanzado una nueva VPC | ID -> $VPC_ID"

# HABILITO DNS en LA VPC

aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames "{\"Value\":true}"

# Creo subred 

SUB_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 172.16.0.0/20 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=mi_subred1_alex}]' \
    --query Subnet.SubnetId --output text)

echo "se ha lanzado una nueva subred para $VPC_ID que es $SUB_ID"

# Habilitar asignacion de la ip publica en la subred

aws ec2 modify-subnet-attribute --subnet-id $SUB_ID --map-public-ip-on-launch

# Creo el gateway para que las 2 subredes se puedan ver

exit 0

aws ec2 create-internet-gateway \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-alex}]'