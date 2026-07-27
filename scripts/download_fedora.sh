#!/bin/bash
set -euo pipefail

FEDORA_VERSION="${FEDORA_VERSION:-44}"
DEPLOY_PATH="${DEPLOY_PATH:-F:/wwwroot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared functions
if [ -f "$SCRIPT_DIR/remote_helpers.sh" ]; then
    source "$SCRIPT_DIR/remote_helpers.sh"
fi

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

# Create directory using detected shell
if type remote_mkdir &>/dev/null; then
    remote_mkdir "$DEPLOY_PATH/fedora/${FEDORA_VERSION}/x86_64/iso"
else
    # Fallback - try PowerShell first, then bash
    if ssh deploy "Get-Command powershell" 2>/dev/null; then
        ssh deploy "powershell.exe -NoProfile -Command \"New-Item -ItemType Directory -Force -Path '$DEPLOY_PATH/fedora/${FEDORA_VERSION}/x86_64/iso' | Out-Null\"" || true
    else
        ssh deploy "mkdir -p '$DEPLOY_PATH/fedora/${FEDORA_VERSION}/x86_64/iso'" || true
    fi
fi

scp -r /tmp/fedora_extract/* deploy:"$DEPLOY_PATH/fedora/${FEDORA_VERSION}/x86_64/iso/" || {
    echo "ERROR: Failed to upload files"
    exit 1
}

# Create symlink
if type remote_cmd &>/dev/null; then
    remote_cmd "New-Item -ItemType SymbolicLink -Path '$DEPLOY_PATH/fedora/latest' -Target '${FEDORA_VERSION}' -Force" || true
else
    ssh deploy "ln -sfn ${FEDORA_VERSION} '$DEPLOY_PATH/fedora/latest'" || true
fi

rm -rf fedora.iso /tmp/fedora_extract 2>/dev/null || true

echo "=== Fedora ISO deployed successfully ==="