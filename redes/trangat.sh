# Creamos 2 VPC para cada region

VPC1_IDvir=$(aws ec2 create-vpc --cidr-block 10.1.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NUBEALEXvir1},{Key=entorno,Value=prueba}]' \
     --query Vpc.VpcId --output text) 

echo "se ha lanzado una nueva VPC | ID -> $VPC1_IDvir"

VPC2_IDvir=$(aws ec2 create-vpc --cidr-block 10.2.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NUBEALEXvir2},{Key=entorno,Value=prueba}]' \
     --query Vpc.VpcId --output text) 

echo "se ha lanzado una nueva VPC | ID -> $VPC2_IDvir"

VPC1_IDore=$(aws ec2 create-vpc --cidr-block 192.168.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NUBEALEXore1},{Key=entorno,Value=prueba}]' \
     --query Vpc.VpcId \
     --region us-west-2 --output text) 

echo "se ha lanzado una nueva VPC | ID -> $VPC1_IDore"

VPC2_IDore=$(aws ec2 create-vpc --cidr-block 192.224.0.0/16 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NUBEALEXore2},{Key=entorno,Value=prueba}]' \
     --query Vpc.VpcId \
     --region us-west-2 --output text) 

echo "se ha lanzado una nueva VPC | ID -> $VPC2_IDore"

# Creo gateway

GW1_IDvir=$(aws ec2 create-internet-gateway \
     --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=vir-alex}]' \
      --query InternetGateway.InternetGatewayId \
      --output text)


echo "se ha creado un nuevo gateway | ID -> $GW1_IDvir"

GW1_IDore=$(aws ec2 create-internet-gateway \
     --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=ore-alex}]' \
      --query InternetGateway.InternetGatewayId --region us-west-2 \
      --output text)


echo "se ha creado un nuevo gateway | ID -> $GW1_IDore"

GW2_IDvir=$(aws ec2 create-internet-gateway \
     --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=vir-alex}]' \
      --query InternetGateway.InternetGatewayId \
      --output text)


echo "se ha creado un nuevo gateway | ID -> $GW2_IDvir"

GW2_IDore=$(aws ec2 create-internet-gateway \
     --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=ore-alex}]' \
      --query InternetGateway.InternetGatewayId --region us-west-2 \
      --output text)


echo "se ha creado un nuevo gateway | ID -> $GW2_IDore"

# Asocio el gateway a la VPC

aws ec2 attach-internet-gateway \
    --internet-gateway-id $GW1_IDvir \
    --vpc-id $VPC1_IDvir

aws ec2 attach-internet-gateway \
    --internet-gateway-id $GW1_IDore \
    --vpc-id $VPC1_IDore --region us-west-2

aws ec2 attach-internet-gateway \
    --internet-gateway-id $GW2_IDvir \
    --vpc-id $VPC2_IDvir

aws ec2 attach-internet-gateway \
    --internet-gateway-id $GW2_IDore \
    --vpc-id $VPC2_IDore --region us-west-2

# HABILITO DNS en LA VPC

aws ec2 modify-vpc-attribute \
    --vpc-id $VPC1_IDvir \
    --enable-dns-hostnames "{\"Value\":true}"

aws ec2 modify-vpc-attribute \
    --vpc-id $VPC1_IDore \
    --enable-dns-hostnames "{\"Value\":true}" --region us-west-2

aws ec2 modify-vpc-attribute \
    --vpc-id $VPC2_IDvir \
    --enable-dns-hostnames "{\"Value\":true}"

aws ec2 modify-vpc-attribute \
    --vpc-id $VPC2_IDore \
    --enable-dns-hostnames "{\"Value\":true}" --region us-west-2

# Ahora creo las subredes publicas

SUB1vir_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC1_IDvir \
    --cidr-block 10.1.0.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=mi_subred1_alex},{Key=entorno,Value=prueba}]' \
    --query Subnet.SubnetId --output text)

SUB1ore_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC1_IDore \
    --cidr-block 192.168.0.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=mi_subred2_alex},{Key=entorno,Value=prueba}]' \
    --query Subnet.SubnetId \
    --region us-west-2 --output text)

SUB2vir_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC2_IDvir \
    --cidr-block 10.2.0.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=mi_subred1_alex},{Key=entorno,Value=prueba}]' \
    --query Subnet.SubnetId --output text)

SUB2ore_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC2_IDore \
    --cidr-block 192.224.0.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=mi_subred2_alex},{Key=entorno,Value=prueba}]' \
    --query Subnet.SubnetId \
    --region us-west-2 --output text)

echo "se han creado las subredes $SUB1vir_ID, $SUB1ore_ID, $SUB2vir_ID y $SUB2ore_ID"


aws ec2 modify-subnet-attribute --subnet-id $SUB1vir_ID --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $SUB1ore_ID --region us-west-2 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $SUB2vir_ID --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $SUB2ore_ID --region us-west-2 --map-public-ip-on-launch

# Creo la tabla de rutas para la subredes publicas

RTBPUBvir_ID1=$(aws ec2 create-route-table --vpc-id $VPC1_IDvir \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-alex-pub1}]' \
    --query RouteTable.RouteTableId --output text)

echo "se ha creado una nueva tabla de rutas | ID -> $RTBPUBvir_ID1"

RTBPUBore_ID1=$(aws ec2 create-route-table --vpc-id $VPC1_IDore \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-alex-pub2}]' \
    --query RouteTable.RouteTableId --region us-west-2 --output text)

echo "se ha creado una nueva tabla de rutas | ID -> $RTBPUBore_ID1"

RTBPUBvir_ID2=$(aws ec2 create-route-table --vpc-id $VPC2_IDvir \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-alex-pub1}]' \
    --query RouteTable.RouteTableId --output text)

echo "se ha creado una nueva tabla de rutas | ID -> $RTBPUBvir_ID2"

RTBPUBore_ID2=$(aws ec2 create-route-table --vpc-id $VPC2_IDore \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-alex-pub2}]' \
    --query RouteTable.RouteTableId --region us-west-2 --output text)

echo "se ha creado una nueva tabla de rutas | ID -> $RTBPUBvir_ID2"

# Añado las rutas a las tablas de rutas

aws ec2 create-route --route-table-id $RTBPUBvir_ID1 \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $GW1_IDvir > /dev/null

aws ec2 create-route --route-table-id $RTBPUBore_ID1 \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $GW1_IDore --region us-west-2 > /dev/null

aws ec2 create-route --route-table-id $RTBPUBvir_ID2 \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $GW2_IDvir > /dev/null

aws ec2 create-route --route-table-id $RTBPUBore_ID2 \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $GW2_IDore --region us-west-2 > /dev/null


# Asocio las tablas de rutas a las subredes

aws ec2 associate-route-table \
    --route-table-id $RTBPUBvir_ID1 \
    --subnet-id $SUB1vir_ID > /dev/null

aws ec2 associate-route-table \
    --route-table-id $RTBPUBore_ID1 \
    --subnet-id $SUB1ore_ID --region us-west-2 > /dev/null

aws ec2 associate-route-table \
    --route-table-id $RTBPUBvir_ID2 \
    --subnet-id $SUB2vir_ID > /dev/null

aws ec2 associate-route-table \
    --route-table-id $RTBPUBore_ID2 \
    --subnet-id $SUB2ore_ID --region us-west-2 > /dev/null

# Creo grupo de seguridad y le doy permisos

SGvir_ID1=$(aws ec2 create-security-group \
    --group-name gs-vir \
    --description "Grupo de seguridad publico" \
    --vpc-id $VPC1_IDvir \
    --query GroupId \
    --output text)
    
echo "se ha creado un nuevo grupo de seguridad | ID -> $SGvir_ID1"

aws ec2 authorize-security-group-ingress \
    --group-id $SGvir_ID1 \
    --ip-permissions '[{"IpProtocol": "tcp","FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow_SSH"}]}]' > /dev/null

echo "Se ha habilitado el puerto 22 a $SGvir_ID1"

aws ec2 authorize-security-group-ingress \
    --group-id $SGvir_ID1 \
    --ip-permissions '[{"IpProtocol": "icmp","FromPort": -1,"ToPort": -1,"IpRanges": [{"CidrIp": "0.0.0.0/0","Description": "Allow_All_ICMP"}]}]' > /dev/null

SGore_ID1=$(aws ec2 create-security-group \
    --group-name gs-ore \
    --description "Grupo de seguridad publico" \
    --vpc-id $VPC1_IDore --region us-west-2 \
    --query GroupId \
    --output text)
    
echo "se ha creado un nuevo grupo de seguridad | ID -> $SGore_ID1"

aws ec2 authorize-security-group-ingress \
    --group-id $SGore_ID1 --region us-west-2 \
    --ip-permissions '[{"IpProtocol": "tcp","FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow_SSH"}]}]' > /dev/null

echo "Se ha habilitado el puerto 22 a $SGore_ID1"

aws ec2 authorize-security-group-ingress \
    --group-id $SGore_ID1 --region us-west-2 \
    --ip-permissions '[{"IpProtocol": "icmp","FromPort": -1,"ToPort": -1,"IpRanges": [{"CidrIp": "0.0.0.0/0","Description": "Allow_All_ICMP"}]}]' > /dev/null

SGvir_ID2=$(aws ec2 create-security-group \
    --group-name gs-vir \
    --description "Grupo de seguridad publico" \
    --vpc-id $VPC2_IDvir \
    --query GroupId \
    --output text)
    
echo "se ha creado un nuevo grupo de seguridad | ID -> $SGvir_ID2"

aws ec2 authorize-security-group-ingress \
    --group-id $SGvir_ID2 \
    --ip-permissions '[{"IpProtocol": "tcp","FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow_SSH"}]}]' > /dev/null

echo "Se ha habilitado el puerto 22 a $SGvir_ID2"

aws ec2 authorize-security-group-ingress \
    --group-id $SGvir_ID2 \
    --ip-permissions '[{"IpProtocol": "icmp","FromPort": -1,"ToPort": -1,"IpRanges": [{"CidrIp": "0.0.0.0/0","Description": "Allow_All_ICMP"}]}]' > /dev/null

SGore_ID2=$(aws ec2 create-security-group \
    --group-name gs-ore \
    --description "Grupo de seguridad publico" \
    --vpc-id $VPC2_IDore --region us-west-2 \
    --query GroupId \
    --output text)
    
echo "se ha creado un nuevo grupo de seguridad | ID -> $SGore_ID2"

aws ec2 authorize-security-group-ingress \
    --group-id $SGore_ID2 --region us-west-2 \
    --ip-permissions '[{"IpProtocol": "tcp","FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow_SSH"}]}]' > /dev/null

echo "Se ha habilitado el puerto 22 a $SGore_ID2"

aws ec2 authorize-security-group-ingress \
    --group-id $SGore_ID2 --region us-west-2 \
    --ip-permissions '[{"IpProtocol": "icmp","FromPort": -1,"ToPort": -1,"IpRanges": [{"CidrIp": "0.0.0.0/0","Description": "Allow_All_ICMP"}]}]' > /dev/null