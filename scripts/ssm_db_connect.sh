#!/bin/bash

# Check if the argument for Environment name is provided
if [ $# -eq 0 ]; then
    echo "Error: ENVIRONMENT_NAME argument is required."
    exit 1
fi

ENVIRONMENT_NAME=$1

# Get the Bastion ID
BASTION_ID=$(aws ec2 describe-instances --output text --filters "Name=tag:Name,Values=${ENVIRONMENT_NAME}-bastion-1" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[].InstanceId | [0]")

# Get the DB URL from SSM
DB_URL=$(aws ssm get-parameter --output text --name "${ENVIRONMENT_NAME}-prsdb-database-url" --query "Parameter.Value")

# Extract the DB endpoint from the DB URL
DB_ENDPOINT=${DB_URL%%:*}

# Start the port forwarding session
aws ssm start-session --region eu-west-2 --target $BASTION_ID --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters host=$DB_ENDPOINT,portNumber="5432",localPortNumber="5432"
