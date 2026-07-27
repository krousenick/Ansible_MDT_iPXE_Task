#!/bin/bash
set -euo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-F:/wwwroot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Deploying to $SSH_HOST ==="

if [ -z "${SSH_HOST:-}" ] || [ -z "${SSH_USER:-}" ]; then
    echo "ERROR: SSH_HOST and SSH_USER must be set"
    exit 1
fi

echo "Deploying iPXE scripts..."
scp -o StrictHostKeyChecking=no -r *.ipxe "$SSH_USER@$SSH_HOST:$DEPLOY_PATH/"

echo "Processing passwords..."
if [ -n "${ADMIN_PASSWORD_PLAINTEXT:-}" ] || [ -n "${GRUB_PASSWORD_PLAINTEXT:-}" ]; then
    python3 "$SCRIPT_DIR/hash_passwords.py" || {
        echo "ERROR: Password hashing failed"
        exit 1
    }
    
    if [ -f /tmp/admin_pass.env ]; then
        ADMIN_PASSWORD_HASHED=$(cat /tmp/admin_pass.env | cut -d= -f2)
        export ADMIN_PASSWORD_HASHED
    fi
    
    if [ -f /tmp/grub_pass.env ]; then
        GRUB_PASSWORD_HASHED=$(cat /tmp/grub_pass.env | cut -d= -f2)
        export GRUB_PASSWORD_HASHED
    fi
fi

echo "Substituting kickstart variables..."
mkdir -p kickstart-processed
for ks_file in kickstart/*.ks; do
    if [ -f "$ks_file" ]; then
        basename=$(basename "$ks_file")
        envsubst < "$ks_file" > "kickstart-processed/$basename" || {
            echo "ERROR: Failed to process $ks_file"
            exit 1
        }
    fi
done

echo "Deploying kickstart files..."
scp -o StrictHostKeyChecking=no -r kickstart-processed/ "$SSH_USER@$SSH_HOST:$DEPLOY_PATH/kickstart/"

rm -rf kickstart-processed /tmp/*.env 2>/dev/null || true
echo "=== Deployment complete ==="