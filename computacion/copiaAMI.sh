#!/usr/bin/env bash
set -euo pipefail

# copia_instancia.sh
# Uso: copia_instancia.sh <region_origen> <id_instancia_origen> <region_destino>

if [ "$#" -ne 3 ]; then
  echo "Uso: $0 <region_origen> <id_instancia_origen> <region_destino>"
  exit 2
fi

REGION_SRC="$1"
INSTANCE_ID="$2"
REGION_DST="$3"

TIMESTAMP="$(date +%Y%m%d%H%M%S)"
AMI_NAME_SRC="ami-from-${INSTANCE_ID}-${TIMESTAMP}"
AMI_NAME_DST="copy-${AMI_NAME_SRC}"
KEY_NAME="key-${INSTANCE_ID}-${TIMESTAMP}"
KEY_FILE="${KEY_NAME}.pem"

# === Función auxiliar para limpiar AMIs y snapshots ===
cleanup_image_and_snapshots() {
  local region="$1"
  local image_id="$2"

  if [ -z "$image_id" ] || [ "$image_id" = "None" ]; then
    echo "No hay image_id para limpiar en ${region}"
    return
  fi

  echo "Obteniendo snapshots de la AMI ${image_id} en ${region}..."
  SNAP_IDS=$(aws ec2 describe-images --image-ids "${image_id}" --region "${region}" \
    --query 'Images[0].BlockDeviceMappings[*].Ebs.SnapshotId' --output text || true)

  echo "Dando de baja la AMI ${image_id} en ${region}..."
  aws ec2 deregister-image --image-id "${image_id}" --region "${region}" || true

  if [ -n "${SNAP_IDS}" ] && [ "${SNAP_IDS}" != "None" ]; then
    for s in ${SNAP_IDS}; do
      if [ -n "${s}" ] && [ "${s}" != "None" ]; then
        echo "Eliminando snapshot ${s} en ${region}..."
        aws ec2 delete-snapshot --snapshot-id "${s}" --region "${region}" || true
      fi
    done
  fi
}

# === Comprobaciones iniciales ===
echo "Comprobando que la instancia ${INSTANCE_ID} existe en ${REGION_SRC}..."
set +e
DESCRIBE_OUT=$(aws ec2 describe-instances --instance-ids "${INSTANCE_ID}" --region "${REGION_SRC}" 2>&1)
RC=$?
set -e
if [ $RC -ne 0 ]; then
  echo "Error: no se encontró la instancia ${INSTANCE_ID} en ${REGION_SRC} o ocurrió un error."
  echo "${DESCRIBE_OUT}"
  exit 3
fi

echo "Obteniendo tipo de instancia..."
INSTANCE_TYPE=$(aws ec2 describe-instances --instance-ids "${INSTANCE_ID}" --region "${REGION_SRC}" \
  --query 'Reservations[0].Instances[0].InstanceType' --output text)
if [ -z "${INSTANCE_TYPE}" ] || [ "${INSTANCE_TYPE}" = "None" ]; then
  echo "No se pudo obtener el tipo de instancia."
  exit 4
fi
echo "Tipo de instancia original: ${INSTANCE_TYPE}"

# === Crear AMI sin detener instancia ===
echo "Creando AMI desde la instancia ${INSTANCE_ID} en ${REGION_SRC} (sin detenerla)..."
AMI_SRC_ID=$(aws ec2 create-image --instance-id "${INSTANCE_ID}" --name "${AMI_NAME_SRC}" --no-reboot --region "${REGION_SRC}" --query 'ImageId' --output text)
echo "AMI creada: ${AMI_SRC_ID}"

echo "Esperando a que la AMI origen esté disponible..."
aws ec2 wait image-available --image-ids "${AMI_SRC_ID}" --region "${REGION_SRC}"

# === Copiar AMI a la región destino ===
echo "Copiando AMI a la región destino ${REGION_DST}..."
AMI_DST_ID=$(aws ec2 copy-image --source-image-id "${AMI_SRC_ID}" --source-region "${REGION_SRC}" \
  --name "${AMI_NAME_DST}" --region "${REGION_DST}" --query 'ImageId' --output text)
echo "AMI destino: ${AMI_DST_ID}"

echo "Esperando a que la AMI destino esté disponible..."
aws ec2 wait image-available --image-ids "${AMI_DST_ID}" --region "${REGION_DST}"

# === Crear par de claves ===
echo "Creando par de claves '${KEY_NAME}' en ${REGION_DST}..."
aws ec2 create-key-pair --key-name "${KEY_NAME}" --region "${REGION_DST}" --query 'KeyMaterial' --output text > "${KEY_FILE}"
chmod 600 "${KEY_FILE}"
echo "Clave privada guardada en ${KEY_FILE}"

# === Determinar VPC/Subnet/SG ===
echo "Obteniendo VPC, Subnet y Security Group por defecto en ${REGION_DST}..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --region "${REGION_DST}" --query 'Vpcs[0].VpcId' --output text)
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --region "${REGION_DST}" --query 'Subnets[0].SubnetId' --output text)
SG_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=${VPC_ID}" "Name=group-name,Values=default" --region "${REGION_DST}" --query 'SecurityGroups[0].GroupId' --output text)

# === Abrir SSH (puerto 22) en el SG destino ===
echo "Configurando el grupo de seguridad ${SG_ID} para aceptar SSH desde cualquier lugar..."
SSH_RULE_EXISTS=$(aws ec2 describe-security-groups --group-ids "${SG_ID}" --region "${REGION_DST}" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\` && IpProtocol==\`tcp\`].IpRanges[?CidrIp=='0.0.0.0/0']" --output text)

if [ -z "${SSH_RULE_EXISTS}" ]; then
  aws ec2 authorize-security-group-ingress \
    --group-id "${SG_ID}" \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region "${REGION_DST}"
  echo "✅ SSH (22/tcp) permitido desde cualquier IP en ${SG_ID}"
else
  echo "La regla SSH ya existe. No se modifica."
fi

# === Lanzar la nueva instancia ===
echo "Lanzando nueva instancia en ${REGION_DST}..."
NEW_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "${AMI_DST_ID}" \
  --count 1 \
  --instance-type "${INSTANCE_TYPE}" \
  --key-name "${KEY_NAME}" \
  --subnet-id "${SUBNET_ID}" \
  --security-group-ids "${SG_ID}" \
  --region "${REGION_DST}" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Nueva instancia creada: ${NEW_INSTANCE_ID}"
aws ec2 wait instance-running --instance-ids "${NEW_INSTANCE_ID}" --region "${REGION_DST}"
echo "Instancia ${NEW_INSTANCE_ID} en ejecución."

# Mostrar información
aws ec2 describe-instances --instance-ids "${NEW_INSTANCE_ID}" --region "${REGION_DST}" \
  --query 'Reservations[0].Instances[0].[InstanceId,InstanceType,State.Name,PublicIpAddress,SubnetId,VpcId]' --output table

# === Limpieza ===
echo "Eliminando AMIs creadas y sus snapshots..."
cleanup_image_and_snapshots "${REGION_SRC}" "${AMI_SRC_ID}"
cleanup_image_and_snapshots "${REGION_DST}" "${AMI_DST_ID}"

echo "Proceso completado correctamente."
echo "Instancia destino: ${NEW_INSTANCE_ID} (${REGION_DST})"
echo "Clave privada: ${KEY_FILE}"
