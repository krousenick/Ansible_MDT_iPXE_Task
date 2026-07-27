#!/bin/ash
set -e

SSH_HOST="${1:-$PROD_SSH_HOST}"
SSH_USER="${2:-$PROD_SSH_USER}"
SSH_KEY="${3:-$PROD_SSH_KEY}"

if [ -z "$SSH_HOST" ] || [ -z "$SSH_USER" ]; then
    echo "ERROR: SSH credentials not configured"
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

echo "SSH configured for $SSH_USER@$SSH_HOST"