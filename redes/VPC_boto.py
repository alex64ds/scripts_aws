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


if __name__ == "__main__":
    vpc_id = crear_vpc()
    print(f'PROCESO COMPLETADO. ID: {vpc_id}')

