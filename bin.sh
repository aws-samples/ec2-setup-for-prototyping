#!/bin/bash

if [ $# -lt 2 ]; then
  echo "Insufficient arguments. Argument 1: Ipv4, Argument 2: Stack name"
  exit 1
fi

Ipv4=$1
StackName=$2
InstanceType=$3
VolumeSize=$4
ImageId=$5

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)
echo "Default VPC ID is: $VPC_ID"

PUBLIC_SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=true" --query "Subnets[0].SubnetId" --output text)
echo "Public Subnet ID is: $PUBLIC_SUBNET_ID"


parameters="ParameterKey=Ipv4,ParameterValue=$Ipv4 ParameterKey=VpcId,ParameterValue=$VPC_ID ParameterKey=SubnetId,ParameterValue=$PUBLIC_SUBNET_ID"

if [[ -n "$InstanceType" ]]; then
  parameters+=" ParameterKey=InstanceType,ParameterValue=$InstanceType"
fi

if [[ -n "$VolumeSize" ]]; then
  parameters+=" ParameterKey=VolumeSize,ParameterValue=$VolumeSize"
fi

if [[ -n "$ImageId" ]]; then
  parameters+=" ParameterKey=ImageId,ParameterValue=$ImageId"
fi

stackId=$(aws cloudformation create-stack \
  --stack-name $StackName \
  --template-body file://template.json \
  --parameters $parameters \
  --capabilities CAPABILITY_IAM \
  --query 'StackId' --output text)

echo "Waiting for the stack creation to complete..."
spin='-\|/'
i=0
while true; do
    status=$(aws cloudformation describe-stacks --stack-name $StackName --query 'Stacks[0].StackStatus' --output text)
    if [[ "$status" == "CREATE_COMPLETE" || "$status" == "UPDATE_COMPLETE" || "$status" == "DELETE_COMPLETE" ]]; then
        break
    fi
    printf "\r${spin:i++%${#spin}:1}"
done
echo -e "\nDone!\n"

outputs=$(aws cloudformation describe-stacks --stack-name $StackName --query 'Stacks[0].Outputs')
echo "Copy ssh key from here: ==============================="
echo "$outputs" | jq -r '.[] | select(.OutputKey == "GetSSHKeyCommand") | .OutputValue' | xargs -I {} sh -c {}
echo -e "End of ssh key ===============================\n"

hostPublicIp=$(echo "$outputs" | jq -r '.[] | select(.OutputKey == "HostPublicIp") | .OutputValue')
echo "HostPublicIP: $hostPublicIp"