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
    echo $SUBNET_IDS
    for SUBNET_ID in $SUBNET_IDS; do
        EC2_SN=$(aws ec2 describe-instances \
            --query Reservations[].Instances[].NetworkInterfaces[].SubnetId \
            --output text | grep $SUBNET_ID | wc -l)
        echo $SUBNET_ID
        if [ $EC2_SN -ne 0 ]; then


            aws ec2 describe-instances \
                --filters "Name=subnet-id,Values=$SUBNET_ID" \
                --query Reservations[].Instances[].InstanceId \
                --output text | tr '\t' '\n' > instancias
            while read line; do

            comterec2=$(aws ec2 describe-instances \
                --instance-ids $line  \
                --query Reservations[].Instances[].State.Name \
                --output text)
            
            if [ $comterec2 != "terminated" ]; then

                aws ec2 terminate-instances \
                    --instance-ids $line > /dev/null

                echo "Terminando instancia $line"
                aws ec2 wait instance-terminated \
                    --instance-ids $line
                echo "Instancia $line terminada"
            fi

            done < instancias
            rm instancias
        fi
        aws ec2 delete-subnet --subnet-id $SUBNET_ID
        echo " Subnet $SUBNET_ID eliminada."
    done
    
    
    # Elimina la VPC
    aws ec2 delete-vpc --vpc-id $VPC_ID
    echo "VPC $VPC_ID eliminada."
done

