# CREO VPC Y ALMACENO EN UNA VARIABLE EN UNA ID

VPC_ID=$(aws ec2 create-vpc --cidr-block 192.168.1.0/24 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NUBEALEX}]' \
     --query Vpc.VpcId --output text) 

# muestro ID de la VPC

echo "se ha lanzado una nueva VPC | ID -> $VPC_ID"

# HABILITO DNS en LA VPC

aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames "{\"Value\":true}"

# Creo subred 

SUB_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 192.168.1.0/28 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=mi_subred1_alex}]' \
    --query Subnet.SubnetId --output text)

echo "se ha lanzado una nueva subred para $VPC_ID que es $SUB_ID"

# Habilitar asignacion de la ip publica en la subred

aws ec2 modify-subnet-attribute --subnet-id $SUB_ID --map-public-ip-on-launch

# Creo grupo de seguridad 

SG_ID=$(aws ec2 create-security-group $VPC_ID \
    --group-name gsalex \
    --description "Mi grupo de seguridad para abrir el puerto 22" \
    --vpc-id $VPC_ID \
    --query GroupId --output text)


echo "se ha creado un nuevo grupo de seguridad | ID -> $SG_ID"