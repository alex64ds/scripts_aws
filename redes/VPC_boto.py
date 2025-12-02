import boto3

def crear_vpc():
    ec2 = boto3.client('ec2')

    # Crear la VPC
    vpc = ec2.create_vpc(CidrBlock='192.168.0.0/16')
    vpc_id = vpc['Vpc']['VpcId']
    print(f'VPC creada con ID: {vpc_id}')

    # Habilitar soporte DNS
    ec2.modify_vpc_attribute(
        VpcId=vpc_id,
        EnableDnsSupport={'Value': True}
    )

    ec2.modify_vpc_attribute(
        VpcId=vpc_id,
        EnableDnsHostnames={'Value': True}
    )

    # Etiquetas
    ec2.create_tags(
        Resources=[vpc_id],
        Tags=[{'Key': 'Name', 'Value': 'MiVPC-Boto3'}]
    )

    print("DNS habilitado y etiqueta asignada")
    return vpc_id
    
def crear_igw_y_asociar(vpc_id):
    ec2 = boto3.client('ec2')

    # Crear Internet Gateway con etiqueta
    response = ec2.create_internet_gateway(
        TagSpecifications=[
            {
                'ResourceType': 'internet-gateway',
                'Tags': [
                    {'Key': 'Name', 'Value': 'igw-alexngw-boto'}
                ]
            }
        ]
    )

    gw_id = response['InternetGateway']['InternetGatewayId']
    print(f"Internet Gateway creado | ID -> {gw_id}")

    # Asociar el IGW a la VPC
    ec2.attach_internet_gateway(
        InternetGatewayId=gw_id,
        VpcId=vpc_id
    )
    print(f"Internet Gateway asociado a la VPC {vpc_id}")

    # Asegurar hostnames DNS habilitados
    ec2.modify_vpc_attribute(
        VpcId=vpc_id,
        EnableDnsHostnames={'Value': True}
    )
    print("DNS Hostnames habilitado en la VPC")

    return gw_id

def crear_subredes(vpc_id):
    ec2 = boto3.client('ec2')

    # Crear subred pública
    subred_pub = ec2.create_subnet(
        VpcId=vpc_id,
        CidrBlock='192.168.0.0/24',
        TagSpecifications=[
            {
                'ResourceType': 'subnet',
                'Tags': [{'Key': 'Name', 'Value': 'mi_subredpub_alex_boto'}]
            }
        ]
    )
    subpub_id = subred_pub['Subnet']['SubnetId']
    print(f"Subred pública creada: {subpub_id}")

    # Crear subred privada
    subred_priv = ec2.create_subnet(
        VpcId=vpc_id,
        CidrBlock='192.168.128.0/24',
        TagSpecifications=[
            {
                'ResourceType': 'subnet',
                'Tags': [{'Key': 'Name', 'Value': 'mi_subredpriv_alex_boto'}]
            }
        ]
    )
    subpriv_id = subred_priv['Subnet']['SubnetId']
    print(f"Subred privada creada: {subpriv_id}")

    # Habilitar IP pública automática en la subred pública
    ec2.modify_subnet_attribute(
        SubnetId=subpub_id,
        MapPublicIpOnLaunch={'Value': True}
    )
    print("Asignación automática de IP pública habilitada en la subred pública")

    return subpub_id, subpriv_id

def crear_rtb_publica(vpc_id, igw_id, subpub_id):
    ec2 = boto3.client('ec2')

    # Crear la tabla de rutas pública
    rtb = ec2.create_route_table(
        VpcId=vpc_id,
        TagSpecifications=[
            {
                'ResourceType': 'route-table',
                'Tags': [{'Key': 'Name', 'Value': 'rtb-alex-pub-boto'}]
            }
        ]
    )

    rtbpub_id = rtb['RouteTable']['RouteTableId']
    print(f"Tabla de rutas pública creada | ID -> {rtbpub_id}")

    # Añadir ruta 0.0.0.0/0 hacia el IGW
    ec2.create_route(
        RouteTableId=rtbpub_id,
        DestinationCidrBlock='0.0.0.0/0',
        GatewayId=igw_id
    )
    print("Ruta 0.0.0.0/0 añadida hacia el Internet Gateway")

    # Asociar la tabla de rutas a la subred pública
    ec2.associate_route_table(
        RouteTableId=rtbpub_id,
        SubnetId=subpub_id
    )
    print(f"Tabla de rutas asociada a la subred pública {subpub_id}")

    return rtbpub_id

def crear_security_group(vpc_id):
    ec2 = boto3.client('ec2')

    # Crear el Security Group
    response = ec2.create_security_group(
        GroupName='gs-ntgw',
        Description='Grupo de seguridad para ssh y ping',
        VpcId=vpc_id
    )

    sg_id = response['GroupId']
    print(f"Security Group creado | ID -> {sg_id}")

    # Regla de entrada: SSH (22/tcp)
    ec2.authorize_security_group_ingress(
        GroupId=sg_id,
        IpPermissions=[
            {
                'IpProtocol': 'tcp',
                'FromPort': 22,
                'ToPort': 22,
                'IpRanges': [
                    {'CidrIp': '0.0.0.0/0', 'Description': 'Allow_SSH'}
                ]
            }
        ]
    )
    print("Regla SSH añadida al SG")

    # Regla de entrada: ICMP (ping)
    ec2.authorize_security_group_ingress(
        GroupId=sg_id,
        IpPermissions=[
            {
                'IpProtocol': 'icmp',
                'FromPort': -1,
                'ToPort': -1,
                'IpRanges': [
                    {'CidrIp': '0.0.0.0/0', 'Description': 'Allow_All_ICMP'}
                ]
            }
        ]
    )
    print("Regla ICMP añadida al SG")

    return sg_id




if __name__ == "__main__":
    vpc_id = crear_vpc()
    print(f'PROCESO COMPLETADO. VPC ID: {vpc_id}')

    igw_id = crear_igw_y_asociar(vpc_id)
    print(f"IGW creado y asociado correctamente: {igw_id}")

    subpub, subpriv = crear_subredes(vpc_id)

    print(f"SE HAN CREADO: Subred pública={subpub} | Subred privada={subpriv}")

    rtbpub_id = crear_rtb_publica(vpc_id, igw_id, subpub)
    print(f"RTB pública creada correctamente: {rtbpub_id}")


    sg_id = crear_security_group(vpc_id)
    print(f"Security Group creado correctamente: {sg_id}")