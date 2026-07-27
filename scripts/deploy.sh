#!/bin/bash
set -euo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-F:/wwwroot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Deploying to $DEPLOY_PATH ==="

# Check if remote is Windows with PowerShell
REMOTE_SHELL="bash"
if ssh deploy "Get-Command powershell" 2>/dev/null; then
    echo "Remote shell: PowerShell (Windows)"
    REMOTE_SHELL="powershell"
    
    echo "Configuring remote directories..."
    ssh deploy "powershell.exe -NoProfile -Command \"New-Item -ItemType Directory -Force -Path '$DEPLOY_PATH' | Out-Null\"" || true
    ssh deploy "powershell.exe -NoProfile -Command \"New-Item -ItemType Directory -Force -Path '$DEPLOY_PATH/kickstart' | Out-Null\"" || true
else
    echo "Remote shell: Linux/Unix"
    ssh deploy "mkdir -p '$DEPLOY_PATH/kickstart'" || true
fi

echo "Deploying iPXE scripts..."
if [ "$REMOTE_SHELL" = "powershell" ]; then
    scp -r *.ipxe deploy:"$DEPLOY_PATH/"
else
    scp -r *.ipxe deploy:"$DEPLOY_PATH/"
fi

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
        # Preserve line endings - use sed instead of envsubst
        if [ -n "${ADMIN_PASSWORD_HASHED:-}" ]; then
            sed "s/\$ADMIN_PASSWORD_HASHED/${ADMIN_PASSWORD_HASHED}/g" "$ks_file" > "kickstart-processed/$basename"
        else
            cp "$ks_file" "kickstart-processed/$basename"
        fi
        
        if [ -n "${GRUB_PASSWORD_HASHED:-}" ]; then
            sed -i "s/\$GRUB_PASSWORD_HASHED/${GRUB_PASSWORD_HASHED}/g" "kickstart-processed/$basename"
        fi
        
        echo "  Processed: $basename"
    fi
done

echo "Deploying kickstart files..."
scp -r kickstart-processed/* deploy:"$DEPLOY_PATH/kickstart/" || {
    echo "ERROR: Failed to deploy kickstart files"
    exit 1
}

rm -rf kickstart-processed /tmp/*.env 2>/dev/null || true
echo "=== Deployment complete ==="