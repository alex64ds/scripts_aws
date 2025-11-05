# Creo grupo de seguridad 

SG_ID=$(aws ec2 create-security-group $VPC_ID \
    --group-name gs-mio \
     --description "Mi grupo de seguridad para abrir el puerto 22" \
     --query GroupId \
     --output text)

echo "se ha creado un nuevo grupo de seguridad | ID -> $SG_ID"

 
# Autorizo el SSH a la instancia

aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    # --protocol tcp \
    # --port 22 \
    # --cidr 0.0.0.0/0 
        --ip-permissions '[{"IpProtocol":"tcp","FromPort":22,"ToPort":22,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"AllowIp"}]}]'