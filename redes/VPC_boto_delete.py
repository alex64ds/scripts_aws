import boto3
import time

ec2 = boto3.client('ec2')


def eliminar_instancias(vpc_id):
    print("Buscando instancias…")
    instances = ec2.describe_instances(
        Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}]
    )

    instance_ids = []
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            instance_ids.append(instance['InstanceId'])

    if instance_ids:
        print(f"Instancias encontradas: {instance_ids}")
        ec2.terminate_instances(InstanceIds=instance_ids)
        print("Las instancias se estan eliminando…")

        waiter = ec2.get_waiter('instance_terminated')
        waiter.wait(InstanceIds=instance_ids)
        print("Instancias eliminadas correctamente")
    else:
        print("No hay instancias que eliminar")


def eliminar_sg(vpc_id):
    print("Buscando Security Groups…")

    sgs = ec2.describe_security_groups(
        Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}]
    )

    for sg in sgs['SecurityGroups']:
        if sg['GroupName'] != 'default':
            print(f"Eliminando SG {sg['GroupId']} - {sg['GroupName']}")
            try:
                ec2.delete_security_group(GroupId=sg['GroupId'])
            except Exception as e:
                print(f"No se pudo eliminar SG {sg['GroupId']}: {e}")


def eliminar_route_tables(vpc_id):
    print("Buscando tablas de rutas…")
    rts = ec2.describe_route_tables(
        Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}]
    )

    for rt in rts['RouteTables']:
        # Saltar la main route table
        if any(assoc.get('Main', False) for assoc in rt['Associations']):
            continue

        rt_id = rt['RouteTableId']
        print(f"Eliminando tabla")

        # Eliminar rutas distintas de la local
        for route in rt['Routes']:
            if route.get('DestinationCidrBlock') == '0.0.0.0/0':
                try:
                    ec2.delete_route(
                        RouteTableId=rt_id,
                        DestinationCidrBlock='0.0.0.0/0'
                    )
                except:
                    pass

        # Eliminar asociaciones
        for assoc in rt['Associations']:
            if not assoc.get('Main', False):
                try:
                    ec2.disassociate_route_table(
                        AssociationId=assoc['RouteTableAssociationId']
                    )
                except:
                    pass

        ec2.delete_route_table(RouteTableId=rt_id)
        print(f"Tabla {rt_id} eliminada")


def eliminar_igw(vpc_id):
    print("Buscando Internet Gateway…")
    igws = ec2.describe_internet_gateways(
        Filters=[{'Name': 'attachment.vpc-id', 'Values': [vpc_id]}]
    )

    for igw in igws['InternetGateways']:
        igw_id = igw['InternetGatewayId']
        print(f"Desasociando IGW {igw_id}")
        ec2.detach_internet_gateway(VpcId=vpc_id, InternetGatewayId=igw_id)
        time.sleep(1)
        print(f"Eliminando IGW {igw_id}")
        ec2.delete_internet_gateway(InternetGatewayId=igw_id)


def eliminar_subnets(vpc_id):
    print("Buscando subredes…")
    subnets = ec2.describe_subnets(
        Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}]
    )

    for subnet in subnets['Subnets']:
        subnet_id = subnet['SubnetId']
        print(f"Eliminando subred {subnet_id}")
        ec2.delete_subnet(SubnetId=subnet_id)


def eliminar_vpc(vpc_id):
    print(f"Eliminando VPC {vpc_id}")
    ec2.delete_vpc(VpcId=vpc_id)
    print("VPC eliminada correctamente")


if __name__ == "__main__":
    vpc_id = input("Introduce el ID de la VPC a eliminar: ")

    eliminar_instancias(vpc_id)
    eliminar_sg(vpc_id)
    eliminar_route_tables(vpc_id)
    eliminar_igw(vpc_id)
    eliminar_subnets(vpc_id)
    eliminar_vpc(vpc_id)

    print("Proceso de ELIMINACIÓN COMPLETADO.")
