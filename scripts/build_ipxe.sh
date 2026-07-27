#!/bin/bash
set -euo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-F:/wwwroot}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared functions
if [ -f "$SCRIPT_DIR/remote_helpers.sh" ]; then
    source "$SCRIPT_DIR/remote_helpers.sh"
fi

echo "=== Building iPXE with HTTPS + EFI support ==="

git clone --depth 1 https://github.com/ipxe/ipxe.git /tmp/ipxe
cd /tmp/ipxe/src

cat > config/local.h << 'EOF'
/* Network protocols */
#define DOWNLOAD_PROTO_HTTPS
#define DOWNLOAD_PROTO_TFTP
#define DOWNLOAD_PROTO_HTTP

/* Image formats */
#define IMAGE_ELF
#define IMAGE_PNG
#define IMAGE_ZLIB

/* Console - enable graphical framebuffer for menus */
#define CONSOLE_FRAMEBUFFER

/* Menu support */
#define AUTOBOOT_MENU
#define MENU_CMD

/* Additional features */
#define REBOOT_CMD
#define POWEROFF_CMD
EOF

echo "Building EFI binary..."
make -j1 bin-x86_64-efi/ipxe.efi || {
    echo "ERROR: EFI build failed"
    exit 1
}

echo "Building BIOS binary..."
make -j1 bin/ipxe.pxe || {
    echo "ERROR: BIOS build failed"
    exit 1
}

echo "Build complete, copying output..."
mkdir -p /tmp/ipxe-output

cp bin-x86_64-efi/ipxe.efi /tmp/ipxe-output/
echo "  EFI binary copied"

cp bin/ipxe.pxe /tmp/ipxe-output/
echo "  BIOS binary copied"

if [ -f bin/undionly.kpxe ]; then
    cp bin/undionly.kpxe /tmp/ipxe-output/
    echo "  UNDI binary copied"
fi

echo "Deploying to IIS..."

# Create directory using detected shell
if type remote_mkdir &>/dev/null; then
    remote_mkdir "$DEPLOY_PATH/ipxe"
else
    if ssh deploy "Get-Command powershell" 2>/dev/null; then
        ssh deploy "powershell.exe -NoProfile -Command \"New-Item -ItemType Directory -Force -Path '$DEPLOY_PATH/ipxe' | Out-Null\"" || true
    else
        ssh deploy "mkdir -p '$DEPLOY_PATH/ipxe'" || true
    fi
fi

scp /tmp/ipxe-output/* deploy:"$DEPLOY_PATH/ipxe/" || {
    echo "ERROR: Failed to upload files"
    exit 1
}

rm -rf /tmp/ipxe /tmp/ipxe-output 2>/dev/null || true

echo "=== iPXE build complete ==="