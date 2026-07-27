#!/bin/bash
set -euo pipefail

SSH_HOST="${1:-${SSH_HOST:-}}"
SSH_USER="${2:-${SSH_USER:-}}"
SSH_KEY="${3:-${SSH_KEY:-}}"

if [ -z "$SSH_HOST" ] || [ -z "$SSH_USER" ]; then
    echo "ERROR: SSH_HOST and SSH_USER must be provided"
    exit 1
fi

if [ -z "$SSH_KEY" ]; then
    echo "ERROR: SSH_KEY must be provided"
    exit 1
fi

mkdir -p ~/.ssh
echo "$SSH_KEY" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519

cat > ~/.ssh/config << EOF
Host deploy
    HostName $SSH_HOST
    User $SSH_USER
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

chmod 600 ~/.ssh/config

echo "Testing SSH connection..."
if ! ssh deploy "echo test" 2>/dev/null; then
    echo "ERROR: SSH connection test failed"
    exit 1
fi

echo "Detecting remote shell..."
if ssh deploy "Get-Command powershell" 2>/dev/null; then
    echo "  Remote shell supports PowerShell"
    cat >> ~/.ssh/config << 'EOF'

Host deploy-powershell
    HostName $SSH_HOST
    User $SSH_USER
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    RequestTTY yes
    RemoteCommand powershell.exe -NoLogo
EOF
    chmod 600 ~/.ssh/config
fi

echo "SSH configured for $SSH_USER@$SSH_HOST"