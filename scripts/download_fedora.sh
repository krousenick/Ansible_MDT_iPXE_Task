#!/bin/bash
set -euo pipefail

FEDORA_VERSION="${FEDORA_VERSION:-44}"
DEPLOY_PATH="${DEPLOY_PATH:-F:/wwwroot}"

echo "=== Downloading Fedora $FEDORA_VERSION ISO ==="

ISO_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VERSION}/Workstation/x86_64/iso/"

echo "Finding latest ISO..."
if ! ISO_NAME=$(curl -sL "$ISO_URL" | grep -o 'Fedora-Workstation-Live[^"]*\.iso' | head -1 | tr -d ' '); then
    echo "ERROR: Failed to fetch ISO list"
    exit 1
fi

if [ -z "$ISO_NAME" ]; then
    echo "ERROR: Could not find ISO in directory listing"
    exit 1
fi

echo "Found: $ISO_NAME"
FULL_URL="${ISO_URL}${ISO_NAME}"

echo "Downloading..."
curl -sS -L -o "fedora.iso" "$FULL_URL" || {
    echo "ERROR: Download failed"
    exit 1
}

if [ ! -f "fedora.iso" ]; then
    echo "ERROR: File not found after download"
    exit 1
fi

echo "Extracting ISO..."
mkdir -p /tmp/fedora_extract
7z x fedora.iso -o/tmp/fedora_extract -y > /dev/null || {
    echo "ERROR: ISO extraction failed"
    exit 1
}

echo "Deploying to IIS..."
ssh -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" "mkdir -p $DEPLOY_PATH/fedora/${FEDORA_VERSION}/x86_64/iso" || {
    echo "ERROR: Failed to create remote directory"
    exit 1
}

scp -o StrictHostKeyChecking=no -r /tmp/fedora_extract/* "$SSH_USER@$SSH_HOST:$DEPLOY_PATH/fedora/${FEDORA_VERSION}/x86_64/iso/" || {
    echo "ERROR: Failed to upload files"
    exit 1
}

ssh -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" "ln -sfn ${FEDORA_VERSION} $DEPLOY_PATH/fedora/latest" || true

rm -rf fedora.iso /tmp/fedora_extract 2>/dev/null || true

echo "=== Fedora ISO deployed successfully ==="