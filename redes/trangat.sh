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

# Creo EC2

EC2vir_ID1=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --key-name vockey \
    --subnet-id $SUB1vir_ID \
    --security-group-ids $SGvir_ID1 \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2publicovir}]' \
    --query Instances[].InstanceId --output text)


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2vir_ID1"

EC2ore_ID1=$(aws ec2 run-instances \
    --image-id ami-00f46ccd1cbfb363e \
    --instance-type t3.micro \
    --region us-west-2 \
    --subnet-id $SUB1ore_ID \
    --security-group-ids $SGore_ID1 \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2publicoore}]' \
    --query Instances[].InstanceId --output text)


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2ore_ID1"

EC2vir_ID2=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --key-name vockey \
    --subnet-id $SUB2vir_ID \
    --security-group-ids $SGvir_ID2 \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2publicovir}]' \
    --query Instances[].InstanceId --output text)


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2vir_ID2"

EC2ore_ID2=$(aws ec2 run-instances \
    --image-id ami-00f46ccd1cbfb363e \
    --instance-type t3.micro \
    --region us-west-2 \
    --subnet-id $SUB2ore_ID \
    --security-group-ids $SGore_ID2 \
    --associate-public-ip-address \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2publicoore}]' \
    --query Instances[].InstanceId --output text)


echo "se ha lanzado una nueva instancia EC2 | ID -> $EC2ore_ID2"

# Creamos los transits gateways

TGvir=$(aws ec2 create-transit-gateway \
    --description MyTGW \
    --options AmazonSideAsn=64516,AutoAcceptSharedAttachments=enable,DefaultRouteTableAssociation=enable,DefaultRouteTablePropagation=enable,VpnEcmpSupport=enable,DnsSupport=enable \
    --query 'TransitGateway.TransitGatewayId' \
    --output text)


echo "Se ha creado un transit gateway | ID -> $TGvir"

TGvir_state=$(aws ec2 describe-transit-gateways --transit-gateway-ids $TGvir --query "TransitGateways[*].State" --output text )

while [ $TGvir_state != "available" ]; do

    TGvir_state=$(aws ec2 describe-transit-gateways --transit-gateway-ids $TGvir --query "TransitGateways[*].State" --output text )

done

echo "$TGvir ya disponible"

TGore=$(aws ec2 create-transit-gateway \
    --description MyTGW \
    --options AmazonSideAsn=64516,AutoAcceptSharedAttachments=enable,DefaultRouteTableAssociation=enable,DefaultRouteTablePropagation=enable,VpnEcmpSupport=enable,DnsSupport=enable \
    --region us-west-2 \
    --query 'TransitGateway.TransitGatewayId' \
    --output text)

echo "Se ha creado un transit gateway | ID -> $TGore"

TGore_state=$(aws ec2 describe-transit-gateways --transit-gateway-ids $TGore --query "TransitGateways[*].State" --region us-west-2 --output text )

while [ $TGore_state != "available" ]; do

    TGore_state=$(aws ec2 describe-transit-gateways --transit-gateway-ids $TGore --query "TransitGateways[*].State" --region us-west-2 --output text )

done

echo "$TGore ya disponible"

# Creamos los attachments para los transit gateways


ATT1_VIR=$(aws ec2 create-transit-gateway-vpc-attachment \
    --transit-gateway-id $TGvir \
    --vpc-id $VPC1_IDvir \
    --subnet-id $SUB1vir_ID \
    --query 'TransitGatewayVpcAttachment.TransitGatewayAttachmentId' \
    --output text)

echo "Attachment creado: $ATT1_VIR "


# Esperar ATT1_VIR
STATE=$(aws ec2 describe-transit-gateway-vpc-attachments \
    --transit-gateway-attachment-ids $ATT1_VIR \
    --query 'TransitGatewayVpcAttachments[0].State' \
    --output text)

while [ "$STATE" != "available" ]; do
    STATE=$(aws ec2 describe-transit-gateway-vpc-attachments \
        --transit-gateway-attachment-ids $ATT1_VIR \
        --query 'TransitGatewayVpcAttachments[0].State' \
        --output text)
done

echo " $ATT1_VIR ya esta disponible."


ATT2_VIR=$(aws ec2 create-transit-gateway-vpc-attachment \
    --transit-gateway-id $TGvir \
    --vpc-id $VPC2_IDvir \
    --subnet-id $SUB2vir_ID \
    --query 'TransitGatewayVpcAttachment.TransitGatewayAttachmentId' \
    --output text)

echo "Attachment creado: $ATT2_VIR "


# Esperar ATT2_VIR
STATE=$(aws ec2 describe-transit-gateway-vpc-attachments \
    --transit-gateway-attachment-ids $ATT2_VIR \
    --region us-east-1 \
    --query 'TransitGatewayVpcAttachments[0].State' \
    --output text)

while [ "$STATE" != "available" ]; do
    STATE=$(aws ec2 describe-transit-gateway-vpc-attachments \
        --transit-gateway-attachment-ids $ATT2_VIR \
        --query 'TransitGatewayVpcAttachments[0].State' \
        --output text)
done

echo "$ATT2_VIR ya esta disponible."


ATT1_ORE=$(aws ec2 create-transit-gateway-vpc-attachment \
    --transit-gateway-id $TGore \
    --vpc-id $VPC1_IDore \
    --subnet-id $SUB1ore_ID \
    --region us-west-2 \
    --query 'TransitGatewayVpcAttachment.TransitGatewayAttachmentId' \
    --output text)

echo "Attachment creado: $ATT1_ORE"


# Esperar ATT1_ORE
STATE=$(aws ec2 describe-transit-gateway-vpc-attachments \
    --transit-gateway-attachment-ids $ATT1_ORE \
    --region us-west-2 \
    --query 'TransitGatewayVpcAttachments[0].State' \
    --output text)

while [ "$STATE" != "available" ]; do
    STATE=$(aws ec2 describe-transit-gateway-vpc-attachments \
        --transit-gateway-attachment-ids $ATT1_ORE \
        --region us-west-2 \
        --query 'TransitGatewayVpcAttachments[0].State' \
        --output text)
done

echo "$ATT1_ORE ya disponible."

ATT2_ORE=$(aws ec2 create-transit-gateway-vpc-attachment \
    --transit-gateway-id $TGore \
    --vpc-id $VPC2_IDore \
    --subnet-id $SUB2ore_ID \
    --region us-west-2 \
    --query 'TransitGatewayVpcAttachment.TransitGatewayAttachmentId' \
    --output text)

echo "Attachment creado: $ATT2_ORE"


# Esperar ATT2_ORE
STATE=$(aws ec2 describe-transit-gateway-vpc-attachments \
    --transit-gateway-attachment-ids $ATT2_ORE \
    --region us-west-2 \
    --query 'TransitGatewayVpcAttachments[0].State' \
    --output text)

while [ "$STATE" != "available" ]; do
    STATE=$(aws ec2 describe-transit-gateway-vpc-attachments \
        --transit-gateway-attachment-ids $ATT2_ORE \
        --region us-west-2 \
        --query 'TransitGatewayVpcAttachments[0].State' \
        --output text)
done

echo "$ATT2_ORE ya disponible."



aws ec2 create-route --route-table-id $RTBPUBvir_ID1 \
    --destination-cidr-block 10.2.0.0/16 \
    --transit-gateway-id $TGvir > /dev/null

aws ec2 create-route --route-table-id $RTBPUBvir_ID2 \
    --destination-cidr-block 10.1.0.0/16  \
    --transit-gateway-id $TGvir > /dev/null

aws ec2 create-route --route-table-id $RTBPUBore_ID1 \
    --destination-cidr-block 192.224.0.0/16 \
    --transit-gateway-id $TGore --region us-west-2 > /dev/null

aws ec2 create-route --route-table-id $RTBPUBore_ID2 \
    --destination-cidr-block 192.168.0.0/16 \
    --transit-gateway-id $TGore --region us-west-2 > /dev/null

# Creamos un transit gateway de tipo peer connection

ATTpeer_ID=$(aws ec2 create-transit-gateway-peering-attachment \
  --transit-gateway-id $TGvir \
  --peer-transit-gateway-id $TGore \
  --peer-account-id 433934801640 \
  --peer-region us-west-2 \
  --query 'TransitGatewayPeeringAttachment.TransitGatewayAttachmentId' \
  --output text)

echo "Attachment del peer connection creado | ID -> $ATTpeer_ID"

STATE=$(aws ec2 describe-transit-gateway-peering-attachments \
    --transit-gateway-attachment-ids $ATTpeer_ID \
    --query 'TransitGatewayPeeringAttachments[0].State' \
    --output text)

while [ "$STATE" != "pendingAcceptance" ]; do
    STATE=$(aws ec2 describe-transit-gateway-peering-attachments \
        --transit-gateway-attachment-ids $ATTpeer_ID \
        --query 'TransitGatewayPeeringAttachments[0].State' \
        --output text)
done


aws ec2 accept-transit-gateway-peering-attachment \
  --transit-gateway-attachment-id $ATTpeer_ID \
  --region us-west-2

STATE=$(aws ec2 describe-transit-gateway-peering-attachments \
    --transit-gateway-attachment-ids $ATTpeer_ID \
    --query 'TransitGatewayPeeringAttachments[0].State' \
    --output text)

while [ "$STATE" != "available" ]; do
    STATE=$(aws ec2 describe-transit-gateway-peering-attachments \
        --transit-gateway-attachment-ids $ATTpeer_ID \
        --query 'TransitGatewayPeeringAttachments[0].State' \
        --output text)
done

echo "$ATTpeer_ID ya disponible."

RTB_ID=$(aws ec2 describe-transit-gateway-route-tables \
    --filters Name=transit-gateway-id,Values=$TGW_ID \
    --query 'TransitGatewayRouteTables[0].TransitGatewayRouteTableId' \
    --output text)

echo "La tabla de rutas del TGW es: $RTB_ID"


