#!/bin/bash

# CREO VPC 

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.10.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NUBEALEX-EXAMEN}]' \
     --query Vpc.VpcId --output text) 

echo "se ha lanzado una nueva VPC | ID -> $VPC_ID"

# Creo gateway

GW_ID=$(aws ec2 create-internet-gateway \
     --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=EXAM-alex}]' \
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

SUBPUB_ID1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.10.1.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=EXAM_subredpub1_alex}]' \
    --query Subnet.SubnetId --output text)

SUBPRIV_ID1=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.10.2.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=EXAM_subredpriv1_alex}]' \
    --query Subnet.SubnetId --output text)

SUBPUB_ID2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.10.3.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=EXAM_subredpub2_alex}]' \
    --query Subnet.SubnetId --output text)

SUBPRIV_ID2=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.10.4.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=EXAM_subredpriv2_alex}]' \
    --query Subnet.SubnetId --output text)

echo "SE HA CREADO $SUBPUB_ID1, $SUBPRIV_ID1, $SUBPUB_ID2 y $SUBPRIV_ID2"

# Habilitar asignacion de la ip publica en las subredes publicas

aws ec2 modify-subnet-attribute --subnet-id $SUBPUB_ID1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $SUBPUB_ID2 --map-public-ip-on-launch

# Creo la tabla de rutas para la subredes publicas

RTBPUB_ID1=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-alex-pub1}]' \
    --query RouteTable.RouteTableId --output text)

echo "se ha creado una nueva tabla de rutas | ID -> $RTBPUB_ID1"

RTBPUB_ID2=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-alex-pub2}]' \
    --query RouteTable.RouteTableId --output text)

echo "se ha creado una nueva tabla de rutas | ID -> $RTBPUB_ID2"

# Añado las rutas a las tablas de rutas

aws ec2 create-route --route-table-id $RTBPUB_ID1 \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $GW_ID > /dev/null

aws ec2 create-route --route-table-id $RTBPUB_ID2 \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $GW_ID > /dev/null


# Asocio las tablas de rutas a las subredes

aws ec2 associate-route-table \
    --route-table-id $RTBPUB_ID1 \
    --subnet-id $SUBPUB_ID1 > /dev/null

aws ec2 associate-route-table \
    --route-table-id $RTBPUB_ID2 \
    --subnet-id $SUBPUB_ID2 > /dev/null

# Creo grupo de seguridad y le doy permisos

SGpub_ID=$(aws ec2 create-security-group \
    --group-name gspub-ntgw \
    --description "Grupo de seguridad publico" \
    --vpc-id $VPC_ID \
    --query GroupId \
    --output text)
    
echo "se ha creado un nuevo grupo de seguridad | ID -> $SGpub_ID"

aws ec2 authorize-security-group-ingress \
    --group-id $SGpub_ID \
    --ip-permissions '[{"IpProtocol": "tcp","FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow_SSH"}]}]' > /dev/null

echo "Se ha habilitado el puerto 22 a $SGpub_ID"

aws ec2 authorize-security-group-ingress \
    --group-id $SGpub_ID \
    --ip-permissions '[{"IpProtocol": "icmp","FromPort": -1,"ToPort": -1,"IpRanges": [{"CidrIp": "0.0.0.0/0","Description": "Allow_All_ICMP"}]}]' > /dev/null

SGpriv_ID=$(aws ec2 create-security-group \
    --group-name gspriv-ntgw \
    --description "Grupo de seguridad privado" \
    --vpc-id $VPC_ID \
    --query GroupId \
    --output text)

aws ec2 authorize-security-group-ingress \
    --group-id $SGpriv_ID \
    --ip-permissions '[{"IpProtocol":"tcp","FromPort":22,"ToPort":22,"UserIdGroupPairs":[{"GroupId":"'"$SGpub_ID"'","Description":"Allow_SSH_from_SG"}]}]' > /dev/null

aws ec2 authorize-security-group-ingress \
    --group-id $SGpriv_ID \
    --ip-permissions '[{"IpProtocol": "icmp","FromPort": -1,"ToPort": -1,"IpRanges": [{"CidrIp": "0.0.0.0/0","Description": "Allow_All_ICMP"}]}]' > /dev/null


echo "se ha creado un nuevo grupo de seguridad | ID -> $SGpriv_ID"

# Creo EC2 

EC2PUB_ID1=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --key-name vockey \
    --subnet-id $SUBPUB_ID1 \
    --security-group-ids $SGpub_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2publico1}]' \
    --query Instances[].InstanceId --output text)

echo "Lanzando instancia $EC2PUB_ID1"

aws ec2 wait instance-running \
    --instance-ids $EC2PUB_ID1


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2PUB_ID1"

EC2PRIV_ID1=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --key-name vockey \
    --subnet-id $SUBPRIV_ID1 \
    --security-group-ids $SGpriv_ID \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2privado1}]' \
    --query Instances[].InstanceId --output text)

echo "Lanzando instancia $EC2PRIV_ID1"

aws ec2 wait instance-running \
    --instance-ids $EC2PRIV_ID1


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2PRIV_ID1"

EC2PUB_ID2=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --key-name vockey \
    --subnet-id $SUBPUB_ID2 \
    --security-group-ids $SGpub_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2publico2}]' \
    --query Instances[].InstanceId --output text)

echo "Lanzando instancia $EC2PUB_ID2"

aws ec2 wait instance-running \
    --instance-ids $EC2PUB_ID2


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2PUB_ID2"

EC2PRIV_ID2=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --key-name vockey \
    --subnet-id $SUBPRIV_ID2 \
    --security-group-ids $SGpriv_ID \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2privado2}]' \
    --query Instances[].InstanceId --output text)

echo "Lanzando instancia $EC2PRIV_ID2"

aws ec2 wait instance-running \
    --instance-ids $EC2PRIV_ID2


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2PRIV_ID2"

# Creamos las IPs elastica

ELS_IP1=$(aws ec2 allocate-address \
    --query AllocationId \
     --output text)

echo "Nueva ip Elastica | ID -> $ELS_IP1"

ELS_IP2=$(aws ec2 allocate-address \
    --query AllocationId \
     --output text)

echo "Nueva ip Elastica | ID -> $ELS_IP2"

# Y ahora los nat gateways

NGW_ID1=$(aws ec2 create-nat-gateway \
    --subnet-id $SUBPUB_ID1 \
    --allocation-id $ELS_IP1 \
    --query NatGateway.NatGatewayId \
    --output text)

echo "Se ha creado un NAT gateway | ID -> $NGW_ID1"

aws ec2 wait nat-gateway-available \
    --nat-gateway-ids $NGW_ID1

echo "$NGW_ID1 ya disponible" 

NGW_ID2=$(aws ec2 create-nat-gateway \
    --subnet-id $SUBPUB_ID2 \
    --allocation-id $ELS_IP2 \
    --query NatGateway.NatGatewayId \
    --output text)

echo "Se ha creado un NAT gateway | ID -> $NGW_ID2"

aws ec2 wait nat-gateway-available \
    --nat-gateway-ids $NGW_ID2


echo "$NGW_ID2 ya disponible" 

# Creo las tablas de rutas para las subredes privadas

RTBPRIV_ID1=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-alex-priv}]' \
    --query RouteTable.RouteTableId --output text)

echo "se ha creado una nueva tabla de rutas | ID -> $RTBPRIV_ID1"

RTBPRIV_ID2=$(aws ec2 create-route-table --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-alex-priv}]' \
    --query RouteTable.RouteTableId --output text)

echo "se ha creado una nueva tabla de rutas | ID -> $RTBPRIV_ID2"

# Añado las rutas a las tablas de rutas

aws ec2 create-route --route-table-id $RTBPRIV_ID1 \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NGW_ID1

aws ec2 create-route --route-table-id $RTBPRIV_ID2 \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NGW_ID2


# Asocio las tablas de rutas a las subredes

aws ec2 associate-route-table \
    --route-table-id $RTBPRIV_ID1 \
    --subnet-id $SUBPRIV_ID1

aws ec2 associate-route-table \
    --route-table-id $RTBPRIV_ID2 \
    --subnet-id $SUBPRIV_ID2

# Detectar NACLs públicas
PUB_NACL1=$(aws ec2 describe-network-acls \
  --filters Name=association.subnet-id,Values=$SUBPUB_ID1 \
  --query "NetworkAcls[0].NetworkAclId" \
  --output text)

PUB_NACL2=$(aws ec2 describe-network-acls \
  --filters Name=association.subnet-id,Values=$SUBPUB_ID2 \
  --query "NetworkAcls[0].NetworkAclId" \
  --output text)


# Detectar NACLs privadas
PRIV_NACL1=$(aws ec2 describe-network-acls \
  --filters Name=association.subnet-id,Values=$SUBPRIV_ID1 \
  --query "NetworkAcls[0].NetworkAclId" \
  --output text)

PRIV_NACL2=$(aws ec2 describe-network-acls \
  --filters Name=association.subnet-id,Values=$SUBPRIV_ID2 \
  --query "NetworkAcls[0].NetworkAclId" \
  --output text)


# Configuramos reglas de ACL publica

# HTTP
aws ec2 create-network-acl-entry \
  --network-acl-id $PUB_NACL1 \
  --rule-number 105 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --cidr-block 0.0.0.0/0 \
  --port-range From=80,To=80

aws ec2 create-network-acl-entry \
  --network-acl-id $PUB_NACL2 \
  --rule-number 105 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --cidr-block 0.0.0.0/0 \
  --port-range From=80,To=80

# HTTPS
aws ec2 create-network-acl-entry \
  --network-acl-id $PUB_NACL1 \
  --rule-number 110 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --cidr-block 0.0.0.0/0 \
  --port-range From=443,To=443

aws ec2 create-network-acl-entry \
  --network-acl-id $PUB_NACL2 \
  --rule-number 110 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --cidr-block 0.0.0.0/0 \
  --port-range From=443,To=443

# SSH
aws ec2 create-network-acl-entry \
  --network-acl-id $PUB_NACL1 \
  --rule-number 120 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --cidr-block 0.0.0.0/0 \
  --port-range From=22,To=22

aws ec2 create-network-acl-entry \
  --network-acl-id $PUB_NACL2 \
  --rule-number 120 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --cidr-block 0.0.0.0/0 \
  --port-range From=22,To=22

# Denegar cualquier otro tráfico entrante
aws ec2 create-network-acl-entry \
  --network-acl-id $PUB_NACL1 \
  --rule-number 200 \
  --protocol -1 \
  --rule-action deny \
  --ingress \
  --cidr-block 0.0.0.0/0
# Denegar cualquier otro tráfico entrante
aws ec2 create-network-acl-entry \
  --network-acl-id $PUB_NACL2 \
  --rule-number 200 \
  --protocol -1 \
  --rule-action deny \
  --ingress \
  --cidr-block 0.0.0.0/0

echo "ACLs PUBLICAs ARREGLADAs | PERMISOS: HTTP, HTTPS Y SSH"

# Denegar todo tráfico externo entrante
aws ec2 create-network-acl-entry \
  --network-acl-id $PRIV_NACL1 \
  --rule-number 105 \
  --protocol -1 \
  --rule-action deny \
  --ingress \
  --cidr-block 0.0.0.0/0
aws ec2 create-network-acl-entry \
  --network-acl-id $PRIV_NACL2 \
  --rule-number 105 \
  --protocol -1 \
  --rule-action deny \
  --ingress \
  --cidr-block 0.0.0.0/0


echo "Se ha denegado en la ACL privada todo el trafico al exterior"