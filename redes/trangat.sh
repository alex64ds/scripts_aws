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