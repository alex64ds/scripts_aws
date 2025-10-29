# CREO VPC Y DEVUELVO SU ID

VPC_ID=$(aws ec2 create-vpc --cidr-block 192.168.1.0/24 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NUBEALEX}]' \
     --query Vpc.VpcId --output text) 

# muestro ID de la VPC

echo "se ha lanzado una nueva VPC | ID -> $VPC_ID"

# HABILITO DNS en LA VPC

aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames "{\"Value\":true}"