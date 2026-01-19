import boto3
import time

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

def lanzar_ec2(sub_id, sg_id, region, nombre, ami_id="ami-0360c520857e3138f"):
    ec2 = boto3.client('ec2', region_name=region)
    inst = ec2.run_instances(
        ImageId=ami_id,
        InstanceType="t3.micro",
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
        time.sleep(5)
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
        time.sleep(5)
        state = ec2.describe_transit_gateway_vpc_attachments(TransitGatewayAttachmentIds=[att_id])['TransitGatewayVpcAttachments'][0]['State']
    print(f"[{region}] VPC Attachment {att_id} disponible")
    return att_id

def crear_peering(tgw_id_east, tgw_id_west):
    ec2 = boto3.client('ec2', region_name=REGION_EAST)
    peer_id = ec2.create_transit_gateway_peering_attachment(
        TransitGatewayId=tgw_id_east,
        PeerTransitGatewayId=tgw_id_west,
        PeerRegion=REGION_WEST,
        PeerAccountId="<TU_ACCOUNT_ID>"
    )['TransitGatewayPeeringAttachment']['TransitGatewayAttachmentId']
    print(f"Peering Attachment creado: {peer_id}")

    # Aceptar en la región oeste
    ec2_west = boto3.client('ec2', region_name=REGION_WEST)
    ec2_west.accept_transit_gateway_peering_attachment(TransitGatewayAttachmentId=peer_id)

    # Esperar hasta 'available'
    state = ""
    while state != "available":
        time.sleep(5)
        state = ec2_west.describe_transit_gateway_peering_attachments(TransitGatewayAttachmentIds=[peer_id])['TransitGatewayPeeringAttachments'][0]['State']
    print(f"Peering Attachment {peer_id} disponible")
    return peer_id

def obtener_tgw_route_table(tgw_id, region):
    ec2 = boto3.client('ec2', region_name=region)
    rtb_id = ec2.describe_transit_gateway_route_tables(
        Filters=[{'Name':'transit-gateway-id','Values':[tgw_id]}]
    )['TransitGatewayRouteTables'][0]['TransitGatewayRouteTableId']
    print(f"[{region}] TGW Route Table: {rtb_id}")
    return rtb_id

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

    # --- Subredes públicas ---
    sub1_east = crear_subred_publica(vpc1_east, REGION_EAST, '10.1.0.0/24','sub1_vir')
    sub2_east = crear_subred_publica(vpc2_east, REGION_EAST, '10.2.0.0/24','sub2_vir')
    sub1_west = crear_subred_publica(vpc1_west, REGION_WEST, '192.168.0.0/24','sub1_ore')
    sub2_west = crear_subred_publica(vpc2_west, REGION_WEST, '192.224.0.0/24','sub2_ore')

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

    # --- Instancias EC2 ---
    lanzar_ec2(sub1_east, sg1_east, REGION_EAST,'EC2_vir1')
    lanzar_ec2(sub2_east, sg2_east, REGION_EAST,'EC2_vir2')
    lanzar_ec2(sub1_west, sg1_west, REGION_WEST,'EC2_ore1')
    lanzar_ec2(sub2_west, sg2_west, REGION_WEST,'EC2_ore2')

    # --- Transit Gateways ---
    tgw_east = crear_transit_gateway(REGION_EAST, 'TGW_East')
    tgw_west = crear_transit_gateway(REGION_WEST, 'TGW_West')

    # --- VPC Attachments ---
    crear_vpc_attachment(tgw_east, vpc1_east, sub1_east, REGION_EAST)
    crear_vpc_attachment(tgw_east, vpc2_east, sub2_east, REGION_EAST)
    crear_vpc_attachment(tgw_west, vpc1_west, sub1_west, REGION_WEST)
    crear_vpc_attachment(tgw_west, vpc2_west, sub2_west, REGION_WEST)

    # --- Peer TGW ---
    crear_peering(tgw_east, tgw_west)

    # --- Obtener TGW Route Table ---
    obtener_tgw_route_table(tgw_east, REGION_EAST)
