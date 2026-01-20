import boto3
import time

REGION = "us-east-1"
AMI_ID = "ami-0360c520857e3138f"
KEY_NAME = "vockey"

ec2 = boto3.client("ec2", region_name=REGION)

# ---------------- VPC ----------------
def crear_vpc(cidr, nombre):
    vpc = ec2.create_vpc(CidrBlock=cidr)
    vpc_id = vpc["Vpc"]["VpcId"]

    ec2.modify_vpc_attribute(VpcId=vpc_id, EnableDnsSupport={"Value": True})
    ec2.modify_vpc_attribute(VpcId=vpc_id, EnableDnsHostnames={"Value": True})
    ec2.create_tags(Resources=[vpc_id], Tags=[{"Key": "Name", "Value": nombre}])

    print(f"VPC creada: {vpc_id}")
    return vpc_id

# ---------------- IGW ----------------
def crear_igw(vpc_id, nombre):
    igw = ec2.create_internet_gateway(
        TagSpecifications=[{
            "ResourceType": "internet-gateway",
            "Tags": [{"Key": "Name", "Value": nombre}]
        }]
    )["InternetGateway"]["InternetGatewayId"]

    ec2.attach_internet_gateway(InternetGatewayId=igw, VpcId=vpc_id)
    print(f"IGW creado y asociado: {igw}")
    return igw

# ---------------- SUBNET ----------------
def crear_subred(vpc_id, cidr, nombre, publica=False):
    sub = ec2.create_subnet(
        VpcId=vpc_id,
        CidrBlock=cidr,
        TagSpecifications=[{
            "ResourceType": "subnet",
            "Tags": [{"Key": "Name", "Value": nombre}]
        }]
    )["Subnet"]["SubnetId"]

    if publica:
        ec2.modify_subnet_attribute(
            SubnetId=sub,
            MapPublicIpOnLaunch={"Value": True}
        )

    print(f"Subred creada: {sub}")
    return sub

# ---------------- ROUTE TABLE ----------------
def crear_rt_publica(vpc_id, sub_id, igw_id, nombre):
    rtb = ec2.create_route_table(
        VpcId=vpc_id,
        TagSpecifications=[{
            "ResourceType": "route-table",
            "Tags": [{"Key": "Name", "Value": nombre}]
        }]
    )["RouteTable"]["RouteTableId"]

    ec2.create_route(
        RouteTableId=rtb,
        DestinationCidrBlock="0.0.0.0/0",
        GatewayId=igw_id
    )

    ec2.associate_route_table(RouteTableId=rtb, SubnetId=sub_id)
    print(f"RT pública creada: {rtb}")
    return rtb

def crear_rt_privada(vpc_id, sub_id, nat_id, nombre):
    rtb = ec2.create_route_table(
        VpcId=vpc_id,
        TagSpecifications=[{
            "ResourceType": "route-table",
            "Tags": [{"Key": "Name", "Value": nombre}]
        }]
    )["RouteTable"]["RouteTableId"]

    ec2.create_route(
        RouteTableId=rtb,
        DestinationCidrBlock="0.0.0.0/0",
        NatGatewayId=nat_id
    )

    ec2.associate_route_table(RouteTableId=rtb, SubnetId=sub_id)
    print(f"RT privada creada: {rtb}")
    return rtb

# ---------------- SECURITY GROUP ----------------
def crear_sg_publico(vpc_id):
    sg = ec2.create_security_group(
        GroupName="gspub-ntgw",
        Description="Grupo de seguridad publico",
        VpcId=vpc_id
    )["GroupId"]

    ec2.authorize_security_group_ingress(
        GroupId=sg,
        IpPermissions=[
            {"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22,
             "IpRanges": [{"CidrIp": "0.0.0.0/0"}]},
            {"IpProtocol": "icmp", "FromPort": -1, "ToPort": -1,
             "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}
        ]
    )
    print(f"SG público creado: {sg}")
    return sg

def crear_sg_privado(vpc_id, sg_publico):
    sg = ec2.create_security_group(
        GroupName="gspriv-ntgw",
        Description="Grupo de seguridad privado",
        VpcId=vpc_id
    )["GroupId"]

    ec2.authorize_security_group_ingress(
        GroupId=sg,
        IpPermissions=[
            {
                "IpProtocol": "tcp",
                "FromPort": 22,
                "ToPort": 22,
                "UserIdGroupPairs": [{"GroupId": sg_publico}]
            },
            {"IpProtocol": "icmp", "FromPort": -1, "ToPort": -1,
             "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}
        ]
    )
    print(f"SG privado creado: {sg}")
    return sg

# ---------------- EC2 ----------------
def lanzar_ec2(sub_id, sg_id, nombre, publica=False):
    ni = {
        "DeviceIndex": 0,
        "SubnetId": sub_id,
        "Groups": [sg_id],
        "AssociatePublicIpAddress": publica
    }

    inst = ec2.run_instances(
        ImageId=AMI_ID,
        InstanceType="t3.micro",
        KeyName=KEY_NAME,
        MinCount=1,
        MaxCount=1,
        NetworkInterfaces=[ni],
        TagSpecifications=[{
            "ResourceType": "instance",
            "Tags": [{"Key": "Name", "Value": nombre}]
        }]
    )["Instances"][0]["InstanceId"]

    ec2.get_waiter("instance_running").wait(InstanceIds=[inst])
    print(f"EC2 lanzada: {inst}")
    return inst

# ---------------- NAT ----------------
def crear_nat(sub_id):
    eip = ec2.allocate_address(Domain="vpc")["AllocationId"]

    nat = ec2.create_nat_gateway(
        SubnetId=sub_id,
        AllocationId=eip
    )["NatGateway"]["NatGatewayId"]

    ec2.get_waiter("nat_gateway_available").wait(NatGatewayIds=[nat])
    print(f"NAT Gateway disponible: {nat}")
    return nat

# ---------------- NACL ----------------
def obtener_nacl(sub_id):
    nacl = ec2.describe_network_acls(
        Filters=[{"Name": "association.subnet-id", "Values": [sub_id]}]
    )["NetworkAcls"][0]["NetworkAclId"]
    return nacl

def crear_regla_nacl(nacl_id, num, proto, accion, ingress, cidr, puerto=None):
    params = {
        "NetworkAclId": nacl_id,
        "RuleNumber": num,
        "Protocol": proto,
        "RuleAction": accion,
        "Ingress": ingress,
        "CidrBlock": cidr
    }
    if puerto:
        params["PortRange"] = {"From": puerto, "To": puerto}

    ec2.create_network_acl_entry(**params)

# ======================= MAIN =======================
if __name__ == "__main__":
    vpc = crear_vpc("10.10.0.0/16", "NUBEALEX-EXAMEN")
    igw = crear_igw(vpc, "EXAM-alex")

    sub_pub1 = crear_subred(vpc, "10.10.1.0/24", "subpub1", True)
    sub_priv1 = crear_subred(vpc, "10.10.2.0/24", "subpriv1")
    sub_pub2 = crear_subred(vpc, "10.10.3.0/24", "subpub2", True)
    sub_priv2 = crear_subred(vpc, "10.10.4.0/24", "subpriv2")

    crear_rt_publica(vpc, sub_pub1, igw, "rtb-pub1")
    crear_rt_publica(vpc, sub_pub2, igw, "rtb-pub2")

    sg_pub = crear_sg_publico(vpc)
    sg_priv = crear_sg_privado(vpc, sg_pub)

    lanzar_ec2(sub_pub1, sg_pub, "EC2-publica1", True)
    lanzar_ec2(sub_priv1, sg_priv, "EC2-privada1")
    lanzar_ec2(sub_pub2, sg_pub, "EC2-publica2", True)
    lanzar_ec2(sub_priv2, sg_priv, "EC2-privada2")

    nat1 = crear_nat(sub_pub1)
    nat2 = crear_nat(sub_pub2)

    crear_rt_privada(vpc, sub_priv1, nat1, "rtb-priv1")
    crear_rt_privada(vpc, sub_priv2, nat2, "rtb-priv2")

    # NACLs
    nacl_pub1 = obtener_nacl(sub_pub1)
    nacl_pub2 = obtener_nacl(sub_pub2)
    nacl_priv1 = obtener_nacl(sub_priv1)
    nacl_priv2 = obtener_nacl(sub_priv2)

    for nacl in [nacl_pub1, nacl_pub2]:
        crear_regla_nacl(nacl, 105, "6", "allow", True, "0.0.0.0/0", 80)
        crear_regla_nacl(nacl, 110, "6", "allow", True, "0.0.0.0/0", 443)
        crear_regla_nacl(nacl, 120, "6", "allow", True, "0.0.0.0/0", 22)
        crear_regla_nacl(nacl, 200, "-1", "deny", True, "0.0.0.0/0")

    for nacl in [nacl_priv1, nacl_priv2]:
        crear_regla_nacl(nacl, 105, "-1", "deny", True, "0.0.0.0/0")

    print("Infraestructura desplegada correctamente")
