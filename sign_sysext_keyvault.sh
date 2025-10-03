#!/bin/bash

set -x

SYSEXT_NAME="$1"
KEYVAULT_CERT_NAME="$2"

echo "Obtaining OIDC token..."
token=$(curl -sSL \
  -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" \
  | jq -r '.value')
echo "$token" > "$AZURE_FEDERATED_TOKEN_FILE"
echo "$token" | wc -c

PKCS11_ENV=(
  AZURE_KEYVAULT_URL="$AZURE_KEYVAULT_URL"
  AZURE_KEYVAULT_PKCS11_DEBUG=1
  PKCS11_MODULE_PATH="${PKCS11_MODULE_PATH:-/usr/lib64/pkcs11/azure-keyvault-pkcs11.so}"

  AZURE_FEDERATED_TOKEN_FILE="$AZURE_FEDERATED_TOKEN_FILE"
  AZURE_CLIENT_ID="$AZURE_CLIENT_ID"
  AZURE_TENANT_ID="$AZURE_TENANT_ID"
  AZURE_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
)

sudo env "${PKCS11_ENV[@]}" ./sign_sysext.sh "$SYSEXT_NAME" pkcs11:token="$KEYVAULT_CERT_NAME"
