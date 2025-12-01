import boto3

def crear_vpc():
    ec2 = boto3.client('ec2')

    # Crear la VPC
    vpc = ec2.create_vpc(CidrBlock='192.168.5.0/16')
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


if __name__ == "__main__":
    vpc_id = crear_vpc()
    print(f'PROCESO COMPLETADO. VPC ID: {vpc_id}')

    igw_id = crear_igw_y_asociar(vpc_id)
    print(f"IGW creado y asociado correctamente: {igw_id}")



