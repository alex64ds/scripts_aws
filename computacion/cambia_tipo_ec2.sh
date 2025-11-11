#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Uso: $0 <id_instancia> <tipo EC2>"
  exit 1
fi

COMP_EC2=$(aws ec2 describe-instances \
    --instance-ids $1 | wc -l)

STATE_EC2=$(aws ec2 describe-instances \
    --instance-ids $1 \
    --query "Reservations[].Instances[].State.Name" \
    --output text)
if [ $COMP_EC2 -eq 0 ]; then
    echo "La instancia no existe y por tanto no se podrá hacer nada"
else
    if [ $STATE_EC2 = "running" ]; then
        aws ec2 stop-instances \
            --instance-ids $1 > /dev/null
        echo "Deteniendo la instancia $1"
        aws ec2 wait instance-stopped \
            --instance-ids $1
        echo "La instancia $1 se ha detenido"
        
    fi

fi