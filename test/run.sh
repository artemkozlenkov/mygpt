#!/bin/bash

# Ensure the script exits immediately if a command exits with a non-zero status
set -e

echo "Loading environment variables from .env file..."
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo ".env file not found!"
    exit 1
fi

# Check if necessary environment variables are set
if [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_SECRET" ] || [ -z "$AZURE_TENANT_ID" ] || [ -z "$AZURE_SUBSCRIPTION_ID" ] || [ -z "$RESOURCE_GROUP" ] || [ -z "$VM_NAME" ]; then
  echo "One or more required environment variables are not set."
  exit 1
fi

echo "Running Azure CLI commands inside Docker container..."

docker run --rm -e AZURE_CLIENT_ID="$AZURE_CLIENT_ID" \
                -e AZURE_SECRET="$AZURE_SECRET" \
                -e AZURE_TENANT_ID="$AZURE_TENANT_ID" \
                -e AZURE_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID" \
                -e RESOURCE_GROUP="$RESOURCE_GROUP" \
                -e VM_NAME="$VM_NAME" \
                mcr.microsoft.com/azure-cli \
                sh -c "
                  set -e
                  echo 'Logging in to Azure...'
                  az login --service-principal -u '$AZURE_CLIENT_ID' -p '$AZURE_SECRET' --tenant '$AZURE_TENANT_ID'
                  
                  echo 'Setting subscription...'
                  az account set --subscription '$AZURE_SUBSCRIPTION_ID'
                  
                  echo 'Starting the VM...'
                  az vm start --resource-group '$RESOURCE_GROUP' --name '$VM_NAME'
                  
                  echo 'VM start command executed successfully.'
                "