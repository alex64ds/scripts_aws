import boto3
import time

ec2 = boto3.client('ec2')
# Creamos VPC
def crear_vpc():
    vpc = ec2.create_vpc(CidrBlock='10.10.0.0/16')
    vpc_id = vpc['Vpc']['VpcId']
    ec2.create_tags(Resources=[vpc_id], Tags=[{'Key': 'Name', 'Value': 'NUBEALEX-EXAMEN'}])
    ec2.modify_vpc_attribute(VpcId=vpc_id, EnableDnsHostnames={'Value': True})
    print(f"VPC creada | ID -> {vpc_id}")
    return vpc_id
# Creamos internet gateway y lo asociamos a la VPC
def crear_igw_y_asociar(vpc_id):
    igw = ec2.create_internet_gateway(Tags=[{'Key': 'Name', 'Value': 'EXAM-alex'}])
    igw_id = igw['InternetGateway']['InternetGatewayId']
    ec2.attach_internet_gateway(InternetGatewayId=igw_id, VpcId=vpc_id)
    print(f"IGW creado y asociado | ID -> {igw_id}")
    return igw_id
# Creamos 2 subredes publicas y 2 privadas
def crear_subredes(vpc_id):
    sub_pub1 = ec2.create_subnet(VpcId=vpc_id, CidrBlock='10.10.1.0/24', TagSpecifications=[{'ResourceType':'subnet','Tags':[{'Key':'Name','Value':'EXAM_subredpub1_alex'}]}])
    sub_pub2 = ec2.create_subnet(VpcId=vpc_id, CidrBlock='10.10.3.0/24', TagSpecifications=[{'ResourceType':'subnet','Tags':[{'Key':'Name','Value':'EXAM_subredpub2_alex'}]}])
    sub_priv1 = ec2.create_subnet(VpcId=vpc_id, CidrBlock='10.10.2.0/24', TagSpecifications=[{'ResourceType':'subnet','Tags':[{'Key':'Name','Value':'EXAM_subredpriv1_alex'}]}])
    sub_priv2 = ec2.create_subnet(VpcId=vpc_id, CidrBlock='10.10.4.0/24', TagSpecifications=[{'ResourceType':'subnet','Tags':[{'Key':'Name','Value':'EXAM_subredpriv2_alex'}]}])
    
    for sub in [sub_pub1, sub_pub2]:
        ec2.modify_subnet_attribute(SubnetId=sub['Subnet']['SubnetId'], MapPublicIpOnLaunch={'Value': True})
    
    print("Subredes creadas")
    return (sub_pub1['Subnet']['SubnetId'], sub_pub2['Subnet']['SubnetId'],
            sub_priv1['Subnet']['SubnetId'], sub_priv2['Subnet']['SubnetId'])
# Creamos la tabla re rutas publica
def crear_rtb_publica(vpc_id, igw_id, sub_pub_ids):
    rtb_ids = []
    for i, sub_id in enumerate(sub_pub_ids, 1):
        rtb = ec2.create_route_table(VpcId=vpc_id, TagSpecifications=[{'ResourceType':'route-table','Tags':[{'Key':'Name','Value':f'rtb-alex-pub{i}'}]}])
        rtb_id = rtb['RouteTable']['RouteTableId']
        ec2.create_route(RouteTableId=rtb_id, DestinationCidrBlock='0.0.0.0/0', GatewayId=igw_id)
        ec2.associate_route_table(RouteTableId=rtb_id, SubnetId=sub_id)
        rtb_ids.append(rtb_id)
        print(f"RTB pública creada y asociada | ID -> {rtb_id}")
    return rtb_ids
# Creamos los grupos de seguridad
def crear_security_groups(vpc_id):
    sg_pub = ec2.create_security_group(GroupName='gspub-ntgw', Description='SG publico', VpcId=vpc_id)['GroupId']
    ec2.authorize_security_group_ingress(GroupId=sg_pub, IpPermissions=[{'IpProtocol':'tcp','FromPort':22,'ToPort':22,'IpRanges':[{'CidrIp':'0.0.0.0/0'}]}])
    ec2.authorize_security_group_ingress(GroupId=sg_pub, IpPermissions=[{'IpProtocol':'icmp','FromPort':-1,'ToPort':-1,'IpRanges':[{'CidrIp':'0.0.0.0/0'}]}])
    
    sg_priv = ec2.create_security_group(GroupName='gspriv-ntgw', Description='SG privado', VpcId=vpc_id)['GroupId']
    ec2.authorize_security_group_ingress(GroupId=sg_priv, IpPermissions=[{'IpProtocol':'tcp','FromPort':22,'ToPort':22,'UserIdGroupPairs':[{'GroupId':sg_pub}]}])
    ec2.authorize_security_group_ingress(GroupId=sg_priv, IpPermissions=[{'IpProtocol':'icmp','FromPort':-1,'ToPort':-1,'IpRanges':[{'CidrIp':'0.0.0.0/0'}]}])
    
    print(f"SG público | ID -> {sg_pub}, SG privado | ID -> {sg_priv}")
    return sg_pub, sg_priv
# Lamzamos las instancias
def lanzar_instancias(sub_pub_ids, sub_priv_ids, sg_pub, sg_priv):
    waiter = ec2.get_waiter('instance_running')
    ec2_pub_ids, ec2_priv_ids = [], []

    # Instancias publicas
    for i, sub_id in enumerate(sub_pub_ids, 1):
        resp = ec2.run_instances(ImageId='ami-0360c520857e3138f', InstanceType='t3.micro',
                                 KeyName='vockey', SubnetId=sub_id, SecurityGroupIds=[sg_pub],
                                 TagSpecifications=[{'ResourceType':'instance','Tags':[{'Key':'Name','Value':f'MiEC2publico{i}'}]}],
                                 MinCount=1, MaxCount=1, NetworkInterfaces=[{'DeviceIndex':0,'SubnetId':sub_id,'Groups':[sg_pub],'AssociatePublicIpAddress':True}])
        inst_id = resp['Instances'][0]['InstanceId']
        waiter.wait(InstanceIds=[inst_id])
        ec2_pub_ids.append(inst_id)
        print(f"EC2 pública lanzada | ID -> {inst_id}")

    # Instancias privadas
    for i, sub_id in enumerate(sub_priv_ids, 1):
        resp = ec2.run_instances(ImageId='ami-0360c520857e3138f', InstanceType='t3.micro',
                                 KeyName='vockey', SubnetId=sub_id, SecurityGroupIds=[sg_priv],
                                 TagSpecifications=[{'ResourceType':'instance','Tags':[{'Key':'Name','Value':f'MiEC2privado{i}'}]}],
                                 MinCount=1, MaxCount=1)
        inst_id = resp['Instances'][0]['InstanceId']
        waiter.wait(InstanceIds=[inst_id])
        ec2_priv_ids.append(inst_id)
        print(f"EC2 privada lanzada | ID -> {inst_id}")

    return ec2_pub_ids, ec2_priv_ids
# Creamos los nat gateways
def crear_nat_gateways(sub_pub_ids):
    nat_ids = []
    for sub_id in sub_pub_ids:
        eip = ec2.allocate_address(Domain='vpc')
        nat = ec2.create_nat_gateway(SubnetId=sub_id, AllocationId=eip['AllocationId'])
        nat_id = nat['NatGateway']['NatGatewayId']
        waiter = ec2.get_waiter('nat_gateway_available')
        print(f"Esperando NAT Gateway {nat_id}...")
        waiter.wait(NatGatewayIds=[nat_id])
        nat_ids.append(nat_id)
        print(f"NAT Gateway disponible | ID -> {nat_id}")
    return nat_ids
# Creamos la tabla de rutas privada
def crear_rtb_privada(vpc_id, sub_priv_ids, nat_ids):
    rtb_priv_ids = []
    for i, (sub_id, nat_id) in enumerate(zip(sub_priv_ids, nat_ids), 1):
        rtb = ec2.create_route_table(VpcId=vpc_id, TagSpecifications=[{'ResourceType':'route-table','Tags':[{'Key':'Name','Value':'rtb-alex-priv'}]}])
        rtb_id = rtb['RouteTable']['RouteTableId']
        ec2.create_route(RouteTableId=rtb_id, DestinationCidrBlock='0.0.0.0/0', NatGatewayId=nat_id)
        ec2.associate_route_table(RouteTableId=rtb_id, SubnetId=sub_id)
        rtb_priv_ids.append(rtb_id)
        print(f"RTB privada creada y asociada | ID -> {rtb_id}")
    return rtb_priv_ids
# Configuramos las NACLs
def configurar_nacls(sub_pub_ids, sub_priv_ids):
    # Obtener NACLs
    pub_nacls = [ec2.describe_network_acls(Filters=[{'Name':'association.subnet-id','Values':[sub]}])['NetworkAcls'][0]['NetworkAclId'] for sub in sub_pub_ids]
    priv_nacls = [ec2.describe_network_acls(Filters=[{'Name':'association.subnet-id','Values':[sub]}])['NetworkAcls'][0]['NetworkAclId'] for sub in sub_priv_ids]

    # Reglas públicas
    for nacl in pub_nacls:
        for rule_number, port in [(105,80),(110,443),(120,22)]:
            ec2.create_network_acl_entry(NetworkAclId=nacl, RuleNumber=rule_number, Protocol='6', RuleAction='allow', Ingress=True, CidrBlock='0.0.0.0/0', PortRange={'From':port,'To':port})
        ec2.create_network_acl_entry(NetworkAclId=nacl, RuleNumber=200, Protocol='-1', RuleAction='deny', Ingress=True, CidrBlock='0.0.0.0/0')

    # Reglas privadas
    for nacl in priv_nacls:
        ec2.create_network_acl_entry(NetworkAclId=nacl, RuleNumber=100, Protocol='-1', RuleAction='deny', Ingress=True, CidrBlock='0.0.0.0/0')

    print("NACLs configuradas")
# Lanzamos todas las funciones
if __name__ == "__main__":
    vpc_id = crear_vpc()
    igw_id = crear_igw_y_asociar(vpc_id)
    sub_pub1, sub_pub2, sub_priv1, sub_priv2 = crear_subredes(vpc_id)
    crear_rtb_publica(vpc_id, igw_id, [sub_pub1, sub_pub2])
    sg_pub, sg_priv = crear_security_groups(vpc_id)
    lanzar_instancias([sub_pub1, sub_pub2], [sub_priv1, sub_priv2], sg_pub, sg_priv)
    nat_ids = crear_nat_gateways([sub_pub1, sub_pub2])
    crear_rtb_privada(vpc_id, [sub_priv1, sub_priv2], nat_ids)
    configurar_nacls([sub_pub1, sub_pub2], [sub_priv1, sub_priv2])
    print("Infraestructura COMPLETA.")
