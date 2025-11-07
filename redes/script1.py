import boto3

def crear_vpc():
    # Crear cliente de EC2
    ec2 = boto3.client('ec2')
    vpc = ec2.create_vpc(CidrBlock='192.168.5.0/16')
    vpc_id = ['Vpc']['VpcId']
    print("VPC creada con ID: {vpc_id}")
    # Habilitar DNS support
    ec2.modify_vpc_attribute(
        VpcId=vpc_id,
        EnableDnsHostnames={'Value': True}
    )

    # Etiquetar VPC

    ec2.create_tags(
        Resources=[vpc_id],
        Tags=[{'Key': 'Name', 'Value': 'MiVPC-Boto3'}]
    )

    print("DNS HABILITADO y etiqueta asignada")
    return vpc_id



if __name__ == "__main__":
    vpc_id = crear_vpc()
    print('PROCESO COMPLETADO. ID: {vpc_id}') 
