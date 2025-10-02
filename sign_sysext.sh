#!/bin/bash


# set -ex
set -euo pipefail
shopt -s nullglob
set -x

function fail() {
  echo "$@"
  exit 1
}

function generate_repart_config() {
  FS_IMAGE="$1"

  # Create temporary working directory
  WORKDIR=$(mktemp -d)

  cat > "$WORKDIR/10-root.conf" <<EOF
[Partition]
Type=root
Verity=data
VerityMatchKey=root
CopyBlocks=$FS_IMAGE
EOF

  # Optionally add verity partition
  cat > "$WORKDIR/20-verity.conf" <<EOF
[Partition]
Type=root-verity
Verity=hash
VerityMatchKey=root
Minimize=best
EOF

  # Optionally add signature partition
  cat > "$WORKDIR/30-signature.conf" <<EOF
[Partition]
Type=root-verity-sig
Verity=signature
VerityMatchKey=root
EOF
  echo "$WORKDIR"
}

function usage() {
    echo "Usage: $0 <sysext_name> <private_key_spec> [<cert_path>]"
    exit 1
}

function sign_sysext() {
  FS_IMAGE="$1"
  OUTPUT_IMAGE="$2"
  KEY_SPEC="$3"
  CERT_SPEC="$4"

  REPART_CONFIG_PATH=$(generate_repart_config "$FS_IMAGE")
  trap 'rm -rf "$REPART_CONFIG_PATH"' EXIT
  echo "Generated config in $REPART_CONFIG_PATH"
  ls $REPART_CONFIG_PATH
  cat ${REPART_CONFIG_PATH}/10-root.conf

  env | grep AZURE
  CERT_CONTENT=$(p11-kit export-object "$CERT_SPEC")

  PKCS11_ENV=(
    AZURE_KEYVAULT_URL="$AZURE_KEYVAULT_URL"
    AZURE_KEYVAULT_PKCS11_DEBUG=1
    PKCS11_MODULE_PATH="${PKCS11_MODULE_PATH:-/usr/lib64/pkcs11/azure-keyvault-pkcs11.so}"

    AZURE_FEDERATED_TOKEN_FILE="$AZURE_FEDERATED_TOKEN_FILE"
    AZURE_CLIENT_ID="$AZURE_CLIENT_ID"
    AZURE_TENANT_ID="$AZURE_TENANT_ID"
    AZURE_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
  )

  env "${PKCS11_ENV[@]}" systemd-repart \
    --empty=create \
    --size=auto \
    --private-key-source=engine:pkcs11 \
    --private-key="$KEY_SPEC" \
    --certificate=<(echo "$CERT_CONTENT") \
    --definitions="$REPART_CONFIG_PATH" \
   "$OUTPUT_IMAGE"
}

echo "Token file:"
ls "$AZURE_FEDERATED_TOKEN_FILE"
wc -c < "$AZURE_FEDERATED_TOKEN_FILE"

if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
    usage
fi

# strip the version after colon
SYSEXT_NAME="${1%:*}"

KEY_SPEC="$2"
if [[ "$#" -eq 2 && ${KEY_SPEC} != pkcs11:* ]]; then
  fail "You have to specify cert_path when not using PKCS11 token."
fi
CERT_NAME="${3:-${KEY_SPEC};type=cert}"

for raw_image in "${SYSEXT_NAME}"*.raw; do
  echo "Should sign $raw_image with key $KEY_SPEC and cert $CERT_NAME"
  signed_image_path="${raw_image%.raw}-signed-ddi.raw"
  raw_image=$(readlink -f "$raw_image")
  sign_sysext "$raw_image" "$signed_image_path" "$KEY_SPEC" "$CERT_NAME"
done

for conf_file in "$SYSEXT_NAME"*.conf; do
  echo "Modifying sysupdate config $conf_file"
  sed -E 's/^(MatchPattern.*)\.raw/\1-signed-ddi.raw/g' > "${conf_file%.conf}-signed-ddi.conf" < "$conf_file"
done
