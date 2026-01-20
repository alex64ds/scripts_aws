import boto3
import time
from botocore.exceptions import ClientError

REGION_EAST = "us-east-1"
REGION_WEST = "us-west-2"

def crear_vpc(region, cidr, nombre):
    ec2 = boto3.client('ec2', region_name=region)
    vpc = ec2.create_vpc(CidrBlock=cidr)
    vpc_id = vpc['Vpc']['VpcId']
    print(f"[{region}] VPC '{nombre}' creada: {vpc_id}")

    ec2.modify_vpc_attribute(VpcId=vpc_id, EnableDnsSupport={'Value': True})
    ec2.modify_vpc_attribute(VpcId=vpc_id, EnableDnsHostnames={'Value': True})
    ec2.create_tags(Resources=[vpc_id], Tags=[{'Key': 'Name', 'Value': nombre}])
    return vpc_id

def crear_igw_y_asociar(vpc_id, region, nombre):
    ec2 = boto3.client('ec2', region_name=region)
    igw = ec2.create_internet_gateway(
        TagSpecifications=[{'ResourceType': 'internet-gateway', 'Tags':[{'Key':'Name','Value':nombre}]}]
    )['InternetGateway']['InternetGatewayId']
    ec2.attach_internet_gateway(InternetGatewayId=igw, VpcId=vpc_id)
    print(f"[{region}] IGW '{nombre}' creado y asociado a VPC {vpc_id}")
    return igw

def crear_subred_publica(vpc_id, region, cidr, nombre):
    ec2 = boto3.client('ec2', region_name=region)
    sub = ec2.create_subnet(
        VpcId=vpc_id,
        CidrBlock=cidr,
        TagSpecifications=[{'ResourceType':'subnet','Tags':[{'Key':'Name','Value':nombre}]}]
    )['Subnet']['SubnetId']
    ec2.modify_subnet_attribute(SubnetId=sub, MapPublicIpOnLaunch={'Value': True})
    print(f"[{region}] Subred pública '{nombre}' creada: {sub}")
    return sub

def crear_subred_privada(vpc_id, region, cidr, nombre):
    ec2 = boto3.client('ec2', region_name=region)
    sub = ec2.create_subnet(
        VpcId=vpc_id,
        CidrBlock=cidr,
        TagSpecifications=[{
            'ResourceType': 'subnet',
            'Tags': [{'Key': 'Name', 'Value': nombre}]
        }]
    )['Subnet']['SubnetId']

    print(f"[{region}] Subred privada '{nombre}' creada: {sub}")
    return sub
def crear_nat_gateway(subnet_publica_id, region, nombre):
    ec2 = boto3.client('ec2', region_name=region)

    eip = ec2.allocate_address(Domain='vpc')
    nat = ec2.create_nat_gateway(
        SubnetId=subnet_publica_id,
        AllocationId=eip['AllocationId'],
        TagSpecifications=[{
            'ResourceType': 'natgateway',
            'Tags': [{'Key': 'Name', 'Value': nombre}]
        }]
    )['NatGateway']['NatGatewayId']

    print(f"[{region}] NAT Gateway '{nombre}' creado: {nat}")

    while True:
        time.sleep(1)
        state = ec2.describe_nat_gateways(
            NatGatewayIds=[nat]
        )['NatGateways'][0]['State']
        if state == 'available':
            break

    print(f"[{region}] NAT Gateway '{nombre}' disponible")
    return nat

def crear_route_table_privada(vpc_id, region, nat_id, sub_privada_id, nombre):
    ec2 = boto3.client('ec2', region_name=region)

    rtb = ec2.create_route_table(
        VpcId=vpc_id,
        TagSpecifications=[{
            'ResourceType': 'route-table',
            'Tags': [{'Key': 'Name', 'Value': nombre}]
        }]
    )['RouteTable']['RouteTableId']

    ec2.create_route(
        RouteTableId=rtb,
        DestinationCidrBlock='0.0.0.0/0',
        NatGatewayId=nat_id
    )

    ec2.associate_route_table(
        RouteTableId=rtb,
        SubnetId=sub_privada_id
    )

    print(f"[{region}] Tabla privada '{nombre}' creada y asociada a {sub_privada_id}")
    return rtb

def crear_route_table_publica(vpc_id, region, igw_id, sub_id, nombre):
    ec2 = boto3.client('ec2', region_name=region)
    rtb = ec2.create_route_table(
        VpcId=vpc_id,
        TagSpecifications=[{'ResourceType':'route-table','Tags':[{'Key':'Name','Value':nombre}]}]
    )['RouteTable']['RouteTableId']
    ec2.create_route(RouteTableId=rtb, DestinationCidrBlock='0.0.0.0/0', GatewayId=igw_id)
    ec2.associate_route_table(RouteTableId=rtb, SubnetId=sub_id)
    print(f"[{region}] Tabla de rutas pública '{nombre}' creada y asociada a {sub_id}")
    return rtb

def crear_security_group(vpc_id, region, nombre):
    ec2 = boto3.client('ec2', region_name=region)
    sg = ec2.create_security_group(GroupName=nombre, Description='SG para SSH e ICMP', VpcId=vpc_id)['GroupId']
    ec2.authorize_security_group_ingress(GroupId=sg, IpPermissions=[
        {'IpProtocol':'tcp','FromPort':22,'ToPort':22,'IpRanges':[{'CidrIp':'0.0.0.0/0','Description':'SSH'}]},
        {'IpProtocol':'icmp','FromPort':-1,'ToPort':-1,'IpRanges':[{'CidrIp':'0.0.0.0/0','Description':'ICMP'}]}
    ])
    print(f"[{region}] SG '{nombre}' creado: {sg}")
    return sg

def lanzar_ec2vir(sub_id, sg_id, region, nombre, ami_id="ami-0360c520857e3138f"):
    ec2 = boto3.client('ec2', region_name=region)
    inst = ec2.run_instances(
        ImageId=ami_id,
        InstanceType="t2.micro",
        KeyName="vockey",
        MinCount=1,
        MaxCount=1,
        NetworkInterfaces=[{'DeviceIndex':0,'SubnetId':sub_id,'Groups':[sg_id],'AssociatePublicIpAddress':True}],
        TagSpecifications=[{'ResourceType':'instance','Tags':[{'Key':'Name','Value':nombre}]}]
    )['Instances'][0]['InstanceId']
    print(f"[{region}] EC2 '{nombre}' lanzada: {inst}")
    waiter = ec2.get_waiter('instance_running')
    waiter.wait(InstanceIds=[inst])
    return inst

def lanzar_ec2ore(sub_id, sg_id, region, nombre, ami_id="ami-00f46ccd1cbfb363e"):
    ec2 = boto3.client('ec2', region_name=region)
    inst = ec2.run_instances(
        ImageId=ami_id,
        InstanceType="t2.micro",
        MinCount=1,
        MaxCount=1,
        NetworkInterfaces=[{'DeviceIndex':0,'SubnetId':sub_id,'Groups':[sg_id],'AssociatePublicIpAddress':True}],
        TagSpecifications=[{'ResourceType':'instance','Tags':[{'Key':'Name','Value':nombre}]}]
    )['Instances'][0]['InstanceId']
    print(f"[{region}] EC2 '{nombre}' lanzada: {inst}")
    waiter = ec2.get_waiter('instance_running')
    waiter.wait(InstanceIds=[inst])
    return inst

def lanzar_ec2_priv_vir(sub_id, sg_id, region, nombre, ami_id="ami-0360c520857e3138f"):
    ec2 = boto3.client('ec2', region_name=region)
    inst = ec2.run_instances(
        ImageId=ami_id,
        InstanceType="t3.micro",
        KeyName="vockey",
        MinCount=1,
        MaxCount=1,
        NetworkInterfaces=[{'DeviceIndex':0,'SubnetId':sub_id,'Groups':[sg_id],'AssociatePublicIpAddress':False}],
        TagSpecifications=[{'ResourceType':'instance','Tags':[{'Key':'Name','Value':nombre}]}]
    )['Instances'][0]['InstanceId']
    print(f"[{region}] EC2 '{nombre}' lanzada: {inst}")
    waiter = ec2.get_waiter('instance_running')
    waiter.wait(InstanceIds=[inst])
    return inst

def lanzar_ec2_priv_ore(sub_id, sg_id, region, nombre, ami_id="ami-00f46ccd1cbfb363e"):
    ec2 = boto3.client('ec2', region_name=region)
    inst = ec2.run_instances(
        ImageId=ami_id,
        InstanceType="t3.micro",
        MinCount=1,
        MaxCount=1,
        NetworkInterfaces=[{'DeviceIndex':0,'SubnetId':sub_id,'Groups':[sg_id],'AssociatePublicIpAddress':False}],
        TagSpecifications=[{'ResourceType':'instance','Tags':[{'Key':'Name','Value':nombre}]}]
    )['Instances'][0]['InstanceId']
    print(f"[{region}] EC2 '{nombre}' lanzada: {inst}")
    waiter = ec2.get_waiter('instance_running')
    waiter.wait(InstanceIds=[inst])
    return inst

def crear_transit_gateway(region, nombre):
    ec2 = boto3.client('ec2', region_name=region)
    tgw_id = ec2.create_transit_gateway(
        Description=nombre,
        Options={
            'AmazonSideAsn':64516,
            'AutoAcceptSharedAttachments':'enable',
            'DefaultRouteTableAssociation':'enable',
            'DefaultRouteTablePropagation':'enable',
            'VpnEcmpSupport':'enable',
            'DnsSupport':'enable'
        }
    )['TransitGateway']['TransitGatewayId']
    print(f"[{region}] TGW '{nombre}' creado: {tgw_id}")
    # Esperar a que esté disponible
    state = ""
    while state != "available":
        time.sleep(1)
        state = ec2.describe_transit_gateways(TransitGatewayIds=[tgw_id])['TransitGateways'][0]['State']
    print(f"[{region}] TGW '{nombre}' disponible")
    return tgw_id

def crear_vpc_attachment(tgw_id, vpc_id, sub_id, region):
    ec2 = boto3.client('ec2', region_name=region)
    att_id = ec2.create_transit_gateway_vpc_attachment(
        TransitGatewayId=tgw_id,
        VpcId=vpc_id,
        SubnetIds=[sub_id]
    )['TransitGatewayVpcAttachment']['TransitGatewayAttachmentId']
    # Esperar disponibilidad
    state = ""
    while state != "available":
        time.sleep(1)
        state = ec2.describe_transit_gateway_vpc_attachments(TransitGatewayAttachmentIds=[att_id])['TransitGatewayVpcAttachments'][0]['State']
    print(f"[{region}] VPC Attachment {att_id} disponible")
    return att_id

def crear_ruta_vpc_hacia_tgw(route_table_id, destination_cidr, tgw_id, region):
    ec2 = boto3.client('ec2', region_name=region)
    ec2.create_route(
        RouteTableId=route_table_id,
        DestinationCidrBlock=destination_cidr,
        TransitGatewayId=tgw_id
    )
    print(f"[{region}] Ruta {destination_cidr} -> TGW {tgw_id} añadida en {route_table_id}")


def crear_peering(tgw_id_east, tgw_id_west):
    ec2_east = boto3.client('ec2', region_name=REGION_EAST)
    ec2_west = boto3.client('ec2', region_name=REGION_WEST)

    response = ec2_east.create_transit_gateway_peering_attachment(
        TransitGatewayId=tgw_id_east,
        PeerTransitGatewayId=tgw_id_west,
        PeerRegion=REGION_WEST,
        PeerAccountId="433934801640"
    )

    peer_id = response['TransitGatewayPeeringAttachment']['TransitGatewayAttachmentId']
    print(f"Peering Attachment creado: {peer_id}")

    # Esperar pendingAcceptance EN EAST
    while True:
        time.sleep(1)
        state = ec2_east.describe_transit_gateway_peering_attachments(
            TransitGatewayAttachmentIds=[peer_id]
        )['TransitGatewayPeeringAttachments'][0]['State']

        print(f"EAST → {state}")
        if state == "pendingAcceptance":
            break

    # Esperar a que el attachment exista EN WEST
    print("Esperando aparición del attachment en WEST...")
    while True:
        time.sleep(1)
        try:
            response = ec2_west.describe_transit_gateway_peering_attachments(
                TransitGatewayAttachmentIds=[peer_id]
            )
            state_west = response['TransitGatewayPeeringAttachments'][0]['State']
            print(f"WEST -> {state_west}")
            break
        except ClientError as e:
            if e.response['Error']['Code'] == "InvalidTransitGatewayAttachmentID.NotFound":
                print("WEST -> aún no visible")
                continue
            else:
                raise

    # Aceptar EN WEST
    ec2_west.accept_transit_gateway_peering_attachment(
        TransitGatewayAttachmentId=peer_id
    )
    print("Peering aceptado en WEST")

    # Esperar AVAILABLE EN EAST y WEST
    def esperar_available(ec2, region):
        while True:
            time.sleep(1)
            state = ec2.describe_transit_gateway_peering_attachments(
                TransitGatewayAttachmentIds=[peer_id]
            )['TransitGatewayPeeringAttachments'][0]['State']
            print(f"{region} -> {state}")
            if state == "available":
                break

    esperar_available(ec2_east, "EAST")
    esperar_available(ec2_west, "WEST")

    print(f"Peering Attachment {peer_id} disponible en ambas regiones")
    return peer_id



def obtener_tgw_route_table(tgw_id, region):
    ec2 = boto3.client('ec2', region_name=region)
    rtb_id = ec2.describe_transit_gateway_route_tables(
        Filters=[{'Name':'transit-gateway-id','Values':[tgw_id]}]
    )['TransitGatewayRouteTables'][0]['TransitGatewayRouteTableId']
    print(f"[{region}] TGW Route Table: {rtb_id}")
    return rtb_id

def crear_ruta_tgw(rtb_id, destination_cidr, attachment_id, region):
    ec2 = boto3.client('ec2', region_name=region)
    ec2.create_transit_gateway_route(
        TransitGatewayRouteTableId=rtb_id,
        DestinationCidrBlock=destination_cidr,
        TransitGatewayAttachmentId=attachment_id
    )
    print(f"[{region}] Ruta {destination_cidr} añadida a {rtb_id}")


if __name__ == "__main__":
    # --- Crear VPCs ---
    vpc1_east = crear_vpc(REGION_EAST, '10.1.0.0/16', 'NUBEALEXvir1')
    vpc2_east = crear_vpc(REGION_EAST, '10.2.0.0/16', 'NUBEALEXvir2')
    vpc1_west = crear_vpc(REGION_WEST, '192.168.0.0/16', 'NUBEALEXore1')
    vpc2_west = crear_vpc(REGION_WEST, '192.224.0.0/16', 'NUBEALEXore2')

    # --- IGWs ---
    igw1_east = crear_igw_y_asociar(vpc1_east, REGION_EAST, 'vir-alex1')
    igw2_east = crear_igw_y_asociar(vpc2_east, REGION_EAST, 'vir-alex2')
    igw1_west = crear_igw_y_asociar(vpc1_west, REGION_WEST, 'ore-alex1')
    igw2_west = crear_igw_y_asociar(vpc2_west, REGION_WEST, 'ore-alex2')

    # --- Subredes públicas y privadas ---
    sub1_east = crear_subred_publica(vpc1_east, REGION_EAST, '10.1.0.0/24','sub1_vir')
    sub2_east = crear_subred_publica(vpc2_east, REGION_EAST, '10.2.0.0/24','sub2_vir')
    sub1_west = crear_subred_publica(vpc1_west, REGION_WEST, '192.168.0.0/24','sub1_ore')
    sub2_west = crear_subred_publica(vpc2_west, REGION_WEST, '192.224.0.0/24','sub2_ore')
    sub1_priv_east = crear_subred_privada(vpc1_east, REGION_EAST, '10.1.1.0/24', 'sub1_vir_priv')
    sub2_priv_east = crear_subred_privada(vpc2_east, REGION_EAST, '10.2.1.0/24', 'sub2_vir_priv')
    sub1_priv_west = crear_subred_privada(vpc1_west, REGION_WEST, '192.168.1.0/24', 'sub1_ore_priv')
    sub2_priv_west = crear_subred_privada(vpc2_west, REGION_WEST, '192.224.1.0/24', 'sub2_ore_priv')
   

    # --- Tablas de rutas públicas ---
    rtb1_east = crear_route_table_publica(vpc1_east, REGION_EAST, igw1_east, sub1_east,'rtb_pub1')
    rtb2_east = crear_route_table_publica(vpc2_east, REGION_EAST, igw2_east, sub2_east,'rtb_pub2')
    rtb1_west = crear_route_table_publica(vpc1_west, REGION_WEST, igw1_west, sub1_west,'rtb_pub1')
    rtb2_west = crear_route_table_publica(vpc2_west, REGION_WEST, igw2_west, sub2_west,'rtb_pub2')

    # --- Security Groups ---
    sg1_east = crear_security_group(vpc1_east, REGION_EAST, 'sg_vir1')
    sg2_east = crear_security_group(vpc2_east, REGION_EAST, 'sg_vir2')
    sg1_west = crear_security_group(vpc1_west, REGION_WEST, 'sg_ore1')
    sg2_west = crear_security_group(vpc2_west, REGION_WEST, 'sg_ore2')
    sg1_eastpriv = crear_security_group(vpc1_east, REGION_EAST, 'sg_vir1priv')
    sg2_eastpriv = crear_security_group(vpc2_east, REGION_EAST, 'sg_vir2priv')
    sg1_westpriv = crear_security_group(vpc1_west, REGION_WEST, 'sg_ore1priv')
    sg2_westpriv = crear_security_group(vpc2_west, REGION_WEST, 'sg_ore2priv')

    # --- Instancias EC2 ---
    lanzar_ec2vir(sub1_east, sg1_east, REGION_EAST,'EC2_vir1')
    lanzar_ec2vir(sub2_east, sg2_east, REGION_EAST,'EC2_vir2')
    lanzar_ec2ore(sub1_west, sg1_west, REGION_WEST,'EC2_ore1')
    lanzar_ec2ore(sub2_west, sg2_west, REGION_WEST,'EC2_ore2')
    lanzar_ec2_priv_vir(sub1_priv_east, sg1_eastpriv, REGION_EAST,'EC2_vir1priv')
    lanzar_ec2_priv_vir(sub2_priv_east, sg2_eastpriv, REGION_EAST,'EC2_vir2priv')
    lanzar_ec2_priv_ore(sub1_priv_west, sg1_westpriv, REGION_WEST,'EC2_ore1priv')
    lanzar_ec2_priv_ores(sub2_priv_west, sg2_westpriv, REGION_WEST,'EC2_ore2priv')

    # --- Transit Gateways ---
    tgw_east = crear_transit_gateway(REGION_EAST, 'TGW_East')
    tgw_west = crear_transit_gateway(REGION_WEST, 'TGW_West')

    # --- VPC Attachments ---
    crear_vpc_attachment(tgw_east, vpc1_east, sub1_east, REGION_EAST)
    crear_vpc_attachment(tgw_east, vpc2_east, sub2_east, REGION_EAST)
    crear_vpc_attachment(tgw_west, vpc1_west, sub1_west, REGION_WEST)
    crear_vpc_attachment(tgw_west, vpc2_west, sub2_west, REGION_WEST)


    # --- Rutas misma regiones
    crear_ruta_vpc_hacia_tgw(rtb1_east, '10.2.0.0/16', tgw_east, REGION_EAST)
    crear_ruta_vpc_hacia_tgw(rtb2_east, '10.1.0.0/16', tgw_east, REGION_EAST)
    crear_ruta_vpc_hacia_tgw(rtb1_west, '192.224.0.0/16', tgw_west, REGION_WEST)
    crear_ruta_vpc_hacia_tgw(rtb2_west, '192.168.0.0/16', tgw_west, REGION_WEST)

    # --- Peer TGW ---
    peer_id = crear_peering(tgw_east, tgw_west)

    # --- Obtener TGW Route Table ---

    tgw_rtb_east = obtener_tgw_route_table(tgw_east, REGION_EAST)
    tgw_rtb_west = obtener_tgw_route_table(tgw_west, REGION_WEST)

    # --- Rutas TGW EAST -> WEST ---
    crear_ruta_tgw(tgw_rtb_east, '192.168.0.0/16', peer_id, REGION_EAST)
    crear_ruta_tgw(tgw_rtb_east, '192.224.0.0/16', peer_id, REGION_EAST)
    crear_ruta_vpc_hacia_tgw(rtb1_east, '192.168.0.0/16', tgw_east, REGION_EAST)
    crear_ruta_vpc_hacia_tgw(rtb1_east, '192.224.0.0/16', tgw_east, REGION_EAST)
    crear_ruta_vpc_hacia_tgw(rtb2_east, '192.168.0.0/16', tgw_east, REGION_EAST)
    crear_ruta_vpc_hacia_tgw(rtb2_east, '192.224.0.0/16', tgw_east, REGION_EAST)


    # --- Rutas TGW WEST -> EAST ---
    crear_ruta_tgw(tgw_rtb_west, '10.1.0.0/16', peer_id, REGION_WEST)
    crear_ruta_tgw(tgw_rtb_west, '10.2.0.0/16', peer_id, REGION_WEST)
    crear_ruta_vpc_hacia_tgw(rtb1_west, '10.1.0.0/16', tgw_west, REGION_WEST)
    crear_ruta_vpc_hacia_tgw(rtb1_west, '10.2.0.0/16', tgw_west, REGION_WEST)
    crear_ruta_vpc_hacia_tgw(rtb2_west, '10.1.0.0/16', tgw_west, REGION_WEST)
    crear_ruta_vpc_hacia_tgw(rtb2_west, '10.2.0.0/16', tgw_west, REGION_WEST)

    # --- Nat Gateways ---
    nat1_east = crear_nat_gateway(sub1_east, REGION_EAST, 'nat_vir1')
    nat2_east = crear_nat_gateway(sub2_east, REGION_EAST, 'nat_vir2')
    nat1_west = crear_nat_gateway(sub1_west, REGION_WEST, 'nat_ore1')
    nat2_west = crear_nat_gateway(sub2_west, REGION_WEST, 'nat_ore2')

    # --- Tablas de rutas Privadas ---

    rtb_priv1_east = crear_route_table_privada(vpc1_east, REGION_EAST, nat1_east, sub1_priv_east, 'rtb_priv_vir1')

    rtb_priv2_east = crear_route_table_privada(vpc2_east, REGION_EAST, nat2_east, sub2_priv_east, 'rtb_priv_vir2')

    rtb_priv1_west = crear_route_table_privada(vpc1_west, REGION_WEST, nat1_west, sub1_priv_west, 'rtb_priv_ore1')

    rtb_priv2_west = crear_route_table_privada(vpc2_west, REGION_WEST, nat2_west, sub2_priv_west, 'rtb_priv_ore2')
