set -euo pipefail
SRV="kind-ec2"
PEM="$SRV.pem"

echo "🔐 Creating Security Group (if not exists)"
SG_ID=$(aws ec2 describe-security-groups \
  --group-names ec2-default-sg \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null || true)

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
  SG_ID=$(aws ec2 create-security-group \
    --group-name ec2-default-sg \
    --description "Security group for Datadog Agent" \
    --query 'GroupId' \
    --output text)
  echo "Created SG: $SG_ID"

  echo "📏 Creating Ingress Rules"
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0
else
  echo "Security group ec2-default-sg already exists: $SG_ID"
fi

echo "🔑 Creating Key Pair (if not exists)"
if ! aws ec2 describe-key-pairs --key-names devops-automation >/dev/null 2>&1; then
  aws ec2 create-key-pair \
    --key-name $SRV \
    --key-type rsa \
    --key-format pem \
    --query 'KeyMaterial' \
    --output text > "$PEM"
  chmod 400 "$PEM"
  echo "Saved key to $PEM"
else
  echo "Key pair devops-automation already exists, NOT overwriting local PEM."
  # Optional: exit if you expect a fresh key each time
  # exit 1
fi

echo "🖥️  Creating EC2"

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-0c101f26f147fa7fd \
  --instance-type t2.micro \
  --key-name $SRV \
  --security-group-ids "$SG_ID" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=datadog-ec2}]' \
  --count 1 \
  --query 'Instances[0].InstanceId' \
  --output text \
  --user-data file://user_data.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$SRV}]")

echo "Instance ID: $INSTANCE_ID"

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Public IP: $PUBLIC_IP"

if [ -f "$PEM" ]; then
  COMMAND="ssh -i \"$PEM\" ec2-user@$PUBLIC_IP"
  echo "🔑 To access your instance run:"
  echo $COMMAND
  echo $COMMAND > connect_ec2.sh
  cmod +x connect_ec2.sh
else
  echo "⚠️ PEM file was not created in this run (key pair pre-existed)."
  echo "Use your existing $PEM PEM to connect:"
  echo "ssh -i /path/to/$PEM.pem ec2-user@$PUBLIC_IP"
fi
