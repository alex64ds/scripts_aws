#!/bin/bash

# CREO VPC 

VPC_ID=$(aws ec2 create-vpc --cidr-block 172.16.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NUBEALEX-NGW}]' \
     --query Vpc.VpcId --output text) 

echo "se ha lanzado una nueva VPC | ID -> $VPC_ID"

# Creo gateway

GW_ID=$(aws ec2 create-internet-gateway \
     --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-alexngw}]' \
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

# Creo subredes

SUBPUB_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 172.16.0.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=mi_subredpub_alex}]' \
    --query Subnet.SubnetId --output text)

SUBPRIV_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 172.16.128.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=mi_subredpriv_alex}]' \
    --query Subnet.SubnetId --output text)

echo "SE HA CREADO $SUBPUB_ID Y $SUBPRIV_ID"

# Habilitar asignacion de la ip publica en la subred publica

aws ec2 modify-subnet-attribute --subnet-id $SUBPUB_ID --map-public-ip-on-launch

# Creo la tabla de rutas para la subred publica

RTBPUB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-alex-pub}]' \
    --query RouteTable.RouteTableId --output text)

echo "se ha creado una nueva tabla de rutas | ID -> $RTBPUB_ID"

# Añado la ruta a la tabla de rutas

aws ec2 create-route --route-table-id $RTBPUB_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $GW_ID


# Asocio la tabla de rutas a la subred

aws ec2 associate-route-table \
    --route-table-id $RTBPUB_ID \
    --subnet-id $SUBPUB_ID

# Creo grupo de seguridad y le doy permisos

SG_ID=$(aws ec2 create-security-group \
    --group-name gs-ntgw \
    --description "Grupo de seguridad para ssh y ping" \
    --vpc-id $VPC_ID \
    --query GroupId \
    --output text)
    
echo "se ha creado un nuevo grupo de seguridad | ID -> $SG_ID"

aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --ip-permissions '[{"IpProtocol": "tcp","FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow_SSH"}]}]' > /dev/null

echo "Se ha habilitado el puerto 22 a $SG_ID"

aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --ip-permissions '[{"IpProtocol": "icmp","FromPort": -1,"ToPort": -1,"IpRanges": [{"CidrIp": "0.0.0.0/0","Description": "Allow_All_ICMP"}]}]' > /dev/null


# Creo EC2

EC2PUB_ID=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --key-name vockey \
    --subnet-id $SUBPUB_ID \
    --security-group-ids $SG_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2publico}]' \
    --query Instances[].InstanceId --output text)

echo "Lanzando instancia $EC2PUB_ID"

aws ec2 wait instance-running \
    --instance-ids $EC2PUB_ID


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2PUB_ID"

EC2PRIV_ID=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --key-name vockey \
    --subnet-id $SUBPRIV_ID \
    --security-group-ids $SG_ID \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2privado}]' \
    --query Instances[].InstanceId --output text)

echo "Lanzando instancia $EC2PRIV_ID"

aws ec2 wait instance-running \
    --instance-ids $EC2PRIV_ID


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2PRIV_ID"

# Creamos la IP elastica

ELS_IP=$(aws ec2 allocate-address \
    --query AllocationId \
     --output text)

echo "Nueva ip Elastica | ID -> $ELS_IP"

# Y ahora el nat gateway

NGW_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $SUBPUB_ID \
    --allocation-id $ELS_IP \
    --query NatGateway.NatGatewayId \
    --output text)

echo "Se ha creado un NAT gateway | ID -> $NGW_ID"

aws ec2 wait nat-gateway-available \
    --nat-gateway-ids $NGW_ID


# Creo la tabla de rutas para la subred privada

RTBPRIV_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-alex-priv}]' \
    --query RouteTable.RouteTableId --output text)

echo "se ha creado una nueva tabla de rutas | ID -> $RTBPRIV_ID"

# Añado la ruta a la tabla de rutas

aws ec2 create-route --route-table-id $RTBPRIV_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NGW_ID


# Asocio la tabla de rutas a la subred

aws ec2 associate-route-table \
    --route-table-id $RTBPRIV_ID \
    --subnet-id $SUBPRIV_ID