#!/bin/bash
set -e

FEDORA_VERSION="${FEDORA_VERSION:-44}"
DEPLOY_PATH="${DEPLOY_PATH:-F:/wwwroot}"

echo "=== Downloading Fedora $FEDORA_VERSION ISO ==="

ISO_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VERSION}/Workstation/x86_64/iso/"

echo "Finding latest ISO..."
ISO_NAME=$(curl -sL "$ISO_URL" | grep -o 'Fedora-Workstation-Live[^"]*\.iso' | head -1 | tr -d ' ')

if [ -z "$ISO_NAME" ]; then
    echo "ERROR: Could not find ISO"
    exit 1
fi

echo "Downloading: $ISO_NAME"
if command -v wget > /dev/null; then
    wget -q --show-progress -O "fedora.iso" "${ISO_URL}${ISO_NAME}"
else
    curl -L -o "fedora.iso" "${ISO_URL}${ISO_NAME}"
fi

echo "Extracting ISO..."
mkdir -p /tmp/fedora_extract
7z x fedora.iso -o/tmp/fedora_extract -y > /dev/null

echo "Deploying to IIS..."
ssh -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" "mkdir -p $DEPLOY_PATH/fedora/${FEDORA_VERSION}/x86_64/iso"
scp -o StrictHostKeyChecking=no -r /tmp/fedora_extract/* "$SSH_USER@$SSH_HOST:$DEPLOY_PATH/fedora/${FEDORA_VERSION}/x86_64/iso/"
ssh -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" "ln -sfn ${FEDORA_VERSION} $DEPLOY_PATH/fedora/latest"

rm -rf fedora.iso /tmp/fedora_extract

echo "=== Fedora ISO deployed successfully ==="
echo "URL: http://$SSH_HOST/fedora/${FEDORA_VERSION}/x86_64/iso/"