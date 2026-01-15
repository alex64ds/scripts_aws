# Creamos una VPC para cada region

VPC_IDvir=$(aws ec2 create-vpc --cidr-block 192.168.0.0/20 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NUBEALEXvir},{Key=entorno,Value=prueba}]' \
     --query Vpc.VpcId --output text) 

echo "se ha lanzado una nueva VPC | ID -> $VPC_IDvir"

VPC_IDore=$(aws ec2 create-vpc --cidr-block 10.0.0.0/20 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NUBEALEXore},{Key=entorno,Value=prueba}]' \
     --query Vpc.VpcId \
     --region us-west-2 --output text) 

echo "se ha lanzado una nueva VPC | ID -> $VPC_IDore"

# Creo gateway

GW_IDvir=$(aws ec2 create-internet-gateway \
     --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=vir-alex}]' \
      --query InternetGateway.InternetGatewayId \
      --output text)


echo "se ha creado un nuevo gateway | ID -> $GW_IDvir"

GW_IDore=$(aws ec2 create-internet-gateway \
     --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=ore-alex}]' \
      --query InternetGateway.InternetGatewayId --region us-west-2 \
      --output text)


echo "se ha creado un nuevo gateway | ID -> $GW_IDore"

# Asocio el gateway a la VPC

aws ec2 attach-internet-gateway \
    --internet-gateway-id $GW_IDvir \
    --vpc-id $VPC_IDvir

aws ec2 attach-internet-gateway \
    --internet-gateway-id $GW_IDore \
    --vpc-id $VPC_IDore --region us-west-2

# HABILITO DNS en LA VPC

aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_IDvir \
    --enable-dns-hostnames "{\"Value\":true}"

aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_IDore \
    --enable-dns-hostnames "{\"Value\":true}" --region us-west-2

# Ahora creo las subredes publicas

SUB1_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_IDvir \
    --cidr-block 192.168.0.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=mi_subred1_alex},{Key=entorno,Value=prueba}]' \
    --query Subnet.SubnetId --output text)

SUB2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_IDore \
    --cidr-block 10.0.0.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=mi_subred2_alex},{Key=entorno,Value=prueba}]' \
    --query Subnet.SubnetId \
    --region us-west-2 --output text)

echo "se han creado las subredes $SUB1_ID y $SUB2_ID"


aws ec2 modify-subnet-attribute --subnet-id $SUB1_ID --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $SUB2_ID --region us-west-2 --map-public-ip-on-launch

# Creo la tabla de rutas para la subredes publicas

RTBPUB_ID1=$(aws ec2 create-route-table --vpc-id $VPC_IDvir \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-alex-pub1}]' \
    --query RouteTable.RouteTableId --output text)

echo "se ha creado una nueva tabla de rutas | ID -> $RTBPUB_ID1"

RTBPUB_ID2=$(aws ec2 create-route-table --vpc-id $VPC_IDore \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-alex-pub2}]' \
    --query RouteTable.RouteTableId --region us-west-2 --output text)

echo "se ha creado una nueva tabla de rutas | ID -> $RTBPUB_ID2"

# Añado las rutas a las tablas de rutas

aws ec2 create-route --route-table-id $RTBPUB_ID1 \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $GW_IDvir > /dev/null

aws ec2 create-route --route-table-id $RTBPUB_ID2 \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $GW_IDore --region us-west-2 > /dev/null


# Asocio las tablas de rutas a las subredes

aws ec2 associate-route-table \
    --route-table-id $RTBPUB_ID1 \
    --subnet-id $SUB1_ID > /dev/null

aws ec2 associate-route-table \
    --route-table-id $RTBPUB_ID2 \
    --subnet-id $SUB2_ID --region us-west-2 > /dev/null

# Creo grupo de seguridad y le doy permisos

SGvir_ID=$(aws ec2 create-security-group \
    --group-name gs-vir \
    --description "Grupo de seguridad publico" \
    --vpc-id $VPC_IDvir \
    --query GroupId \
    --output text)
    
echo "se ha creado un nuevo grupo de seguridad | ID -> $SGvir_ID"

aws ec2 authorize-security-group-ingress \
    --group-id $SGvir_ID \
    --ip-permissions '[{"IpProtocol": "tcp","FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow_SSH"}]}]' > /dev/null

echo "Se ha habilitado el puerto 22 a $SGvir_ID"

aws ec2 authorize-security-group-ingress \
    --group-id $SGvir_ID \
    --ip-permissions '[{"IpProtocol": "icmp","FromPort": -1,"ToPort": -1,"IpRanges": [{"CidrIp": "0.0.0.0/0","Description": "Allow_All_ICMP"}]}]' > /dev/null

SGore_ID=$(aws ec2 create-security-group \
    --group-name gs-ore \
    --description "Grupo de seguridad publico" \
    --vpc-id $VPC_IDore --region us-west-2 \
    --query GroupId \
    --output text)
    
echo "se ha creado un nuevo grupo de seguridad | ID -> $SGore_ID"

aws ec2 authorize-security-group-ingress \
    --group-id $SGore_ID --region us-west-2 \
    --ip-permissions '[{"IpProtocol": "tcp","FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow_SSH"}]}]' > /dev/null

echo "Se ha habilitado el puerto 22 a $SGore_ID"

aws ec2 authorize-security-group-ingress \
    --group-id $SGore_ID --region us-west-2 \
    --ip-permissions '[{"IpProtocol": "icmp","FromPort": -1,"ToPort": -1,"IpRanges": [{"CidrIp": "0.0.0.0/0","Description": "Allow_All_ICMP"}]}]' > /dev/null

# creo EC2


EC2_ID1=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --key-name vockey \
    --subnet-id $SUB1_ID \
    --security-group-ids $SGvir_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2publico1}]' \
    --query Instances[].InstanceId --output text)


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2_ID1"

EC2_ID2=$(aws ec2 run-instances \
    --image-id ami-00f46ccd1cbfb363e \
    --instance-type t3.micro \
    --region us-west-2 \
    --subnet-id $SUB2_ID \
    --security-group-ids $SGore_ID \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2publico1}]' \
    --query Instances[].InstanceId --output text)


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2_ID2"

# Creamos el Peer connection y lo aceptamos

PCON_ID=$(aws ec2 create-vpc-peering-connection \
  --vpc-id $VPC_IDvir \
  --peer-vpc-id $VPC_IDore \
  --peer-region us-west-2 \
  --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
  --output text)

aws ec2 wait vpc-peering-connection-exists \
  --vpc-peering-connection-ids $PCCON_ID

echo "Se ha creado un nuevo Peer Connection | ID -> $PCON_ID"

aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $PCON_ID --region us-west-2 > /dev/null



# Asociamos el peer connection a las VPC

aws ec2 create-route --route-table-id $RTBPUB_ID1 \
    --destination-cidr-block 10.0.0.0/20  \
    --vpc-peering-connection-id $PCON_ID > /dev/null

aws ec2 create-route --route-table-id $RTBPUB_ID2 \
    --destination-cidr-block 192.168.0.0/20 \
    --vpc-peering-connection-id $PCON_ID --region us-west-2 > /dev/null