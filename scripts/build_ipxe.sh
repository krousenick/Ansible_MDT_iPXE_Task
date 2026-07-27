#!/bin/bash
set -e

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
make -j$(nproc) bin-x86_64-efi/ipxe.efi

echo "Building BIOS binary..."
make -j$(nproc) bin/ipxe.pxe

mkdir -p /tmp/ipxe-output
cp bin-x86_64-efi/ipxe.efi /tmp/ipxe-output/
cp bin/ipxe.pxe /tmp/ipxe-output/

echo "Deploying to IIS..."
ssh -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" "mkdir -p $DEPLOY_PATH/ipxe"
scp -o StrictHostKeyChecking=no /tmp/ipxe-output/* "$SSH_USER@$SSH_HOST:$DEPLOY_PATH/ipxe/"

rm -rf /tmp/ipxe /tmp/ipxe-output

echo "=== iPXE build complete ==="