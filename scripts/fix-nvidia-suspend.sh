#!/bin/bash
# NVIDIA Suspend/Resume Fix for Fedora 44
# Fixes gray screen on resume after suspend
# Run with: sudo ./fix-nvidia-suspend.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (sudo)" >&2
    exit 1
fi

log() {
    echo "[NVIDIA Fix] $1"
}

log "=== NVIDIA Suspend/Resume Fix for Fedora 44 ==="

log "[1/7] Configuring NVIDIA kernel parameters..."
cat > /etc/modprobe.d/nvidia.conf << 'EOF'
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
options nvidia-drm modeset=1 fbdev=1
options nvidia-uvm enable_fb_console=1
EOF

log "[2/7] Creating systemd-suspend override..."
mkdir -p /etc/systemd/system/systemd-suspend.service.d
cat > /etc/systemd/system/systemd-suspend.service.d/nvidia.conf << 'EOF'
[Service]
ExecStartPre=/usr/bin/nvidia-sleep.sh suspend
ExecStopPost=/usr/bin/nvidia-sleep.sh resume
EOF

log "[3/7] Creating systemd-hibernate override..."
mkdir -p /etc/systemd/system/systemd-hibernate.service.d
cat > /etc/systemd/system/systemd-hibernate.service.d/nvidia.conf << 'EOF'
[Service]
ExecStartPre=/usr/bin/nvidia-sleep.sh hibernate
ExecStopPost=/usr/bin/nvidia-sleep.sh resume
EOF

log "[4/7] Setting permissions on nvidia-sleep.sh..."
chmod +x /usr/bin/nvidia-sleep.sh 2>/dev/null || true

log "[5/7] Creating backup sleep hook with VT switch..."
cat > /lib/systemd/system-sleep/10-nvidia-fix.sh << 'EOF'
#!/bin/bash
case "$1/$2" in
    pre/suspend|pre/hibernate)
        /usr/bin/nvidia-sleep.sh "$2" 2>/dev/null || true
        ;;
    post/*)
        /usr/bin/nvidia-sleep.sh resume 2>/dev/null || true
        chvt 1
        chvt 7
        ;;
esac
EOF
chmod +x /lib/systemd/system-sleep/10-nvidia-fix.sh

log "[6/7] Configuring GDM for NVIDIA resume..."
mkdir -p /etc/systemd/system/gdm.service.d
cat > /etc/systemd/system/gdm.service.d/nvidia-resume.conf << 'EOF'
[Service]
ExecStartPost=/bin/sh -c 'cursor=/sys/class/graphics/fb0/cursor; [ -f "$cursor" ] && echo 0 > "$cursor"'
ExecStartPost=/usr/bin/nvidia-sleep.sh resume 2>/dev/null || true
EOF

log "[7/7] Reloading systemd and rebuilding initramfs..."
systemctl daemon-reload
dracut --force

log ""
log "=== Fix Applied Successfully ==="
log ""
log "NEXT STEPS:"
log "  1. Reboot your system: sudo reboot"
log "  2. After reboot, test suspend: systemctl suspend"
log "  3. If still having issues, add kernel params:"
log "     Edit /etc/default/grub and append to GRUB_CMDLINE_LINUX:"
log "       nvidia-drm.modeset=1 vt.handoff=7"
log "     Then run: sudo grub2-mkconfig -o /boot/grub2/grub.cfg"
log ""
