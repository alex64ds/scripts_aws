#!/bin/bash

# CREO VPC 

VPC_ID=$(aws ec2 create-vpc --cidr-block 172.16.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NUBEALEX}]' \
     --query Vpc.VpcId --output text) 

echo "se ha lanzado una nueva VPC | ID -> $VPC_ID"

# Creo gateway

GW_ID=$(aws ec2 create-internet-gateway \
     --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-alex}]' \
      --query InternetGateway.InternetGatewayId \
      --output text)


echo "se ha creado un nuevo gateway | ID -> $GW_ID"

# Asocio el gateway a la VPC

aws ec2 attach-internet-gateway \
    --internet-gateway-id $GW_ID \
    --vpc-id $VPC_ID

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

# Creo una tabla de rutas para la vpc

RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-alex}]' \
    --query RouteTable.RouteTableId --output text)

echo "se ha creado una nueva tabla de rutas | ID -> $RTB_ID"

# Añado la ruta a la tabla de rutas

aws ec2 create-route --route-table-id $RTB_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $GW_ID


# Asocio la tabla de rutas a la subred

aws ec2 associate-route-table \
    --route-table-id $RTB_ID \
    --subnet-id $SUB_ID


aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --ip-permissions '[{"IpProtocol": "tcp","FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow_SSH"}]}]' > /dev/null

echo "Se ha habilitado el puerto 22 a $SG_ID"

# Creo EC2

EC2_ID=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --key-name vockey \
    --subnet-id $SUB_ID \
    --security-group-ids $SG_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2}]' \
    --query Instances.InstanceId --output text)


sleep 15


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2_ID"