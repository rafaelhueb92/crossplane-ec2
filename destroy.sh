SRV="kind-ec2"

aws ec2 terminate-instances --instance-ids \
    $(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$SRV" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text)