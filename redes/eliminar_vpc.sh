# Obtén los IDs de las VPCs que tienen la etiqueta entorno=prueba
VPC_IDS=$(aws ec2 describe-vpcs \
    --filters "Name=tag:entorno,Values=prueba" \
    --query "Vpcs[*].VpcId" \
    --output text)

# Recorre cada ID de VPC y elimínala
for VPC_ID in $VPC_IDS; do
    echo "Eliminando VPC $VPC_ID..."
    
    # Eliminar recursos asociados (puentes de internet, subredes, etc.) antes de eliminar la VPC
    # Ejemplo: elimina subredes
    SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text)
    for SUBNET_ID in $SUBNET_IDS; do
        EC2_SN=$(aws ec2 describe-instances \
            --query Reservations[].Instances[].NetworkInterfaces[].SubnetId \
            --output text | grep subnet-0be259b7524fba0fa | wc -l)
        if [ $EC2_SN -ne 0 ]; then

            aws ec2 describe-instances \
                --filters "Name=subnet-id,Values=subnet-0be259b7524fba0fa" \
                --query Reservations[].Instances[].InstanceId \
                --output text | tr '\t' '\n' > instancias
            while read line; do

            done < instancias
        fi
        # aws ec2 delete-subnet --subnet-id $SUBNET_ID
        # echo " Subnet $SUBNET_ID eliminada."
    done
    
    # (Opcional) Elimina más recursos aquí como Internet Gateways, Route Tables, etc., si existen
    
    # Elimina la VPC
    # aws ec2 delete-vpc --vpc-id $VPC_ID
    # echo "VPC $VPC_ID eliminada."
done
rm instancias
