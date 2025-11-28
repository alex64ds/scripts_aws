

# Asocio la tabla de rutas a la subred

aws ec2 associate-route-table \
    --route-table-id $RTB_ID \
    --subnet-id $GW_ID