aws ec2 create-internet-gateway \
     --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-alex}]' \
      --query InternetGateway.InternetGatewayId \
      --output text
