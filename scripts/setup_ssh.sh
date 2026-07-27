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
    StrictHostKeyChecking accept-new
EOF

chmod 600 ~/.ssh/config

echo "SSH configured for $SSH_USER@$SSH_HOST"