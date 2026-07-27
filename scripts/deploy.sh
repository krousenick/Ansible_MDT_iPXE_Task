#!/bin/ash
set -e

DEPLOY_PATH="${DEPLOY_PATH:-F:/wwwroot}"

echo "Deploying iPXE scripts..."
scp -o StrictHostKeyChecking=no -r *.ipxe "$SSH_USER@$SSH_HOST:$DEPLOY_PATH/"

echo "Processing passwords..."
python3 /scripts/hash_passwords.py

source /tmp/admin_pass.env 2>/dev/null || true
source /tmp/grub_pass.env 2>/dev/null || true
export ADMIN_PASSWORD_HASHED
export GRUB_PASSWORD_HASHED

echo "Substituting kickstart variables..."
mkdir -p kickstart-processed
for ks_file in kickstart/*.ks; do
    if [ -f "$ks_file" ]; then
        basename=$(basename "$ks_file")
        envsubst < "$ks_file" > "kickstart-processed/$basename"
    fi
done

echo "Deploying kickstart files..."
scp -o StrictHostKeyChecking=no -r kickstart-processed/ "$SSH_USER@$SSH_HOST:$DEPLOY_PATH/kickstart/"

rm -rf kickstart-processed /tmp/*.env
echo "=== Deployment complete ==="