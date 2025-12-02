import boto3
import time

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

    # Añadimos regla de engtrada del SSH y ping (ICMP)

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

def lanzar_instancias(subpub_id, subpriv_id, sg_id):
    ec2 = boto3.client('ec2')
    waiter = ec2.get_waiter('instance_running')

    # Lanzamos Instancia pública (usamos network interface para asegurar una ip publica)
    resp_pub = ec2.run_instances(
        ImageId="ami-0360c520857e3138f",
        InstanceType="t3.micro",
        KeyName="vockey",
        MinCount=1,
        MaxCount=1,
        TagSpecifications=[{
            'ResourceType': 'instance',
            'Tags': [{'Key': 'Name', 'Value': 'MiEC2publicoBOTO'}]
        }],
        NetworkInterfaces=[{
            'AssociatePublicIpAddress': True,
            'DeviceIndex': 0,
            'SubnetId': subpub_id,
            'Groups': [sg_id]
        }]
    )
    ec2_pub_id = resp_pub['Instances'][0]['InstanceId']
    print("Instancia pública empezando a lanzarse")

    # Esperar al lanzamiento completo
    waiter.wait(InstanceIds=[ec2_pub_id])
    print(f"Lanzada instancia pública: {ec2_pub_id}")

    # Lanzamos instancia privada
    resp_priv = ec2.run_instances(
        ImageId="ami-0360c520857e3138f",
        InstanceType="t3.micro",
        KeyName="vockey",
        MinCount=1,
        MaxCount=1,
        SubnetId=subpriv_id,
        SecurityGroupIds=[sg_id],
        TagSpecifications=[{
            'ResourceType': 'instance',
            'Tags': [{'Key': 'Name', 'Value': 'MiEC2privadoBOTOs'}]
        }]
    )
    ec2_priv_id = resp_priv['Instances'][0]['InstanceId']
    print("Instancia privada empezando a lanzarse")
    

    waiter.wait(InstanceIds=[ec2_priv_id])
    print(f"Lanzada instancia privada: {ec2_priv_id}")

    return ec2_pub_id, ec2_priv_id


def crear_nat_gateway(subpub_id):
    ec2 = boto3.client('ec2')
    # Crear IP Elastica
    eip_response = ec2.allocate_address(Domain='vpc')
    allocation_id = eip_response['AllocationId']
    public_ip = eip_response['PublicIp']
    print(f"IP elastica creada | ID -> {allocation_id} | IP -> {public_ip}")

    # Crear NAT Gateway
    nat_response = ec2.create_nat_gateway(
        SubnetId=subpub_id,
        AllocationId=allocation_id
    )
    nat_gateway_id = nat_response['NatGateway']['NatGatewayId']
    print(f"NAT Gateway creado | ID -> {nat_gateway_id}")

    # Esperar a que esté disponible
    waiter = ec2.get_waiter('nat_gateway_available')
    print("Esperando a que el NAT Gateway esté disponible...")
    waiter.wait(NatGatewayIds=[nat_gateway_id])
    print(f"NAT Gateway {nat_gateway_id} ya está disponible")

    return nat_gateway_id, allocation_id, public_ip

def crear_rtb_privada(vpc_id, subpriv_id, nat_gateway_id):
    ec2 = boto3.client('ec2')

    # Crear la tabla de rutas privada
    rtb = ec2.create_route_table(
        VpcId=vpc_id,
        TagSpecifications=[
            {
                'ResourceType': 'route-table',
                'Tags': [{'Key': 'Name', 'Value': 'rtb-alex-priv-boto'}]
            }
        ]
    )
    rtbpriv_id = rtb['RouteTable']['RouteTableId']
    print(f"Tabla de rutas privada creada | ID -> {rtbpriv_id}")

    # Añadir ruta 0.0.0.0/0 hacia el NAT Gateway
    ec2.create_route(
        RouteTableId=rtbpriv_id,
        DestinationCidrBlock='0.0.0.0/0',
        NatGatewayId=nat_gateway_id
    )
    print("Ruta 0.0.0.0/0 añadida hacia el NAT Gateway")

    # Asociar la tabla de rutas a la subred privada
    ec2.associate_route_table(
        RouteTableId=rtbpriv_id,
        SubnetId=subpriv_id
    )
    print(f"Tabla de rutas asociada a la subred privada {subpriv_id}")

    return rtbpriv_id


if __name__ == "__main__":
    vpc_id = crear_vpc()
    igw_id = crear_igw_y_asociar(vpc_id)
    subpub, subpriv = crear_subredes(vpc_id)
    rtbpub_id = crear_rtb_publica(vpc_id, igw_id, subpub)
    sg_id = crear_security_group(vpc_id)
    ec2_pub_id, ec2_priv_id = lanzar_instancias(subpub, subpriv, sg_id)
    nat_gateway_id, allocation_id, public_ip = crear_nat_gateway(subpub)
    rtbpriv_id = crear_rtb_privada(vpc_id, subpriv, nat_gateway_id)
    print("Proceso de CREACION COMPLETADO.")