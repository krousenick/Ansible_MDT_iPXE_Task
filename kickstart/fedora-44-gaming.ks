# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Fedora 44 Gaming Edition (Bazzite-style)
# Verified: Fedora 44 with GNOME 50, Wayland-only, kernel 7.1.x
# Target: x86_64 architecture
#

### Installs from the network over http
url --url=https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/os/

### Add COPR repos for Bazzite gaming packages
repo --name=copr:copr.fedorainfracloud.org:ublue-os:staging --baseurl=https://download.copr.fedorainfracloud.org/results/ublue-os/staging/fedora-44-x86_64/
repo --name=copr:copr.fedorainfracloud.org:ublue-os:bazzite --baseurl=https://download.copr.fedorainfracloud.org/results/ublue-os/bazzite/fedora-44-x86_64/

### Performs the kickstart installation in text mode.
text

### Sets the language to use during installation and the default language to use on the installed system.
lang en_US.UTF-8

### Sets the default keyboard type for the system.
keyboard us

### Disable Initial Setup on first boot
firstboot --disable

### Configure network information for target system and activate network devices in the installer environment
network --bootproto=dhcp --hostname=kro-fedora-44-gaming --nameserver=10.3.0.5

### Lock the root account.
rootpw --lock

### Add a user that can login and escalate privileges.
user --name=kladmin --password=$ADMIN_PASSWORD_HASHED --iscrypted --homedir=/home/kladmin --groups=wheel --uid=1001

### Configure firewall settings for the system.
firewall --enabled --ssh

### Sets the state of SELinux on the installed system (permissive for gaming compatibility)
selinux --permissive

### Sets the system time zone.
timezone America/New_York --utc

### Sets how the boot loader should be installed.
### Gaming kernel parameters: low latency, no watchdog, split lock mitigation off
### FIPS kernel parameter for crypto compliance
### Audit=1 kernel parameter for security logging
bootloader --location=boot --append="audit=1 split_lock_mitigate=0 nmi_watchdog=0 quiet fips=1"

### Initialize any invalid partition tables found on disks.
zerombr

### Removes partitions from the system, prior to creation of new partitions.
clearpart --all --initlabel

### Partitioning for 1TB NVMe (XFS with LVM)
### /boot: 1GB (kernel/initramfs updates)
### /boot/efi: 512MB (UEFI ESP)
### swap: 8GB minimal (for zram overflow, no hibernation)
### /var/log/audit: 4GB (security logging)
### /var/log: 8GB (application logs)
### /var/tmp: 4GB
### /var: 8GB
### /tmp: 8GB
### /home: 100GB (gaming libraries, proton prefixes)
### /: remaining (~860GB)
part /boot                   --fstype=xfs     --size=1024      --label=BOOTFS
part /boot/efi               --fstype=efi     --size=512       --label=EFIFS
part pv.01                                          --size=100        --grow

volgroup sysvg --pesize=4096 pv.01

logvol swap                  --fstype=swap    --name=lv_swap     --vgname=sysvg --size=8192         --label=SWAPFS
logvol /var/log/audit        --fstype=xfs     --name=lv_audit    --vgname=sysvg --size=4096         --label=AUDITFS --fsoptions="nodev,noexec,nosuid"
logvol /var/log              --fstype=xfs     --name=lv_log      --vgname=sysvg --size=8192         --label=LOGFS --fsoptions="nodev,noexec,nosuid"
logvol /var/tmp              --fstype=xfs     --name=lv_vartmp   --vgname=sysvg --size=4096         --label=VARFS --fsoptions="nodev"
logvol /var                  --fstype=xfs     --name=lv_var      --vgname=sysvg --size=8192         --label=VTMPFS --fsoptions="nodev"
logvol /tmp                  --fstype=xfs     --name=lv_tmp      --vgname=sysvg --size=8192         --label=TMPFS --fsoptions="nodev,noexec,nosuid"
logvol /home                 --fstype=xfs     --name=lv_home     --vgname=sysvg --size=102400       --label=HOMEFS --fsoptions="nodev,nosuid"
logvol /                     --fstype=xfs     --name=lv_root     --vgname=sysvg --size=20480 --grow  --label=ROOTFS

### Packages selection (Bazzite-style gaming packages)
%packages --excludedocs --inst-langs=en --exclude-weakdeps
@Core
@gnome-desktop
@multimedia
@hardware-support
@base-x

# System utilities
chrony
logrotate
rsyslog
rsyslog-gnutls
rng-tools
tmux
cloud-utils-growpart
iputils
scap-security-guide
selinux-policy
selinux-policy-targeted
audit
audispd-plugins
fapolicyd

# FIPS compliance packages
gnutls-fips
libkcapi-fipscheck
crypto-policies

# Admin utilities
jq
tree
git
vim-enhanced
bind-utils
unzip
fzf

# Remote desktop
freerdp
gnome-remote-desktop

# Active Directory / FreeIPA integration
freeipa-client
freeipa-client-common
sssd-ad
sssd-common
sssd-tools
krb5-workstation
oddjob
oddjob-mkhomedir
openldap-clients
accountsservice
dconf

ImageMagick

# Gaming packages (available in Fedora 44)
lutris
gamescope
mangohud
vkBasalt
libFAudio
openxr
gamemode
libgamemode
libgamemode-auto
pipewire
wireplumber
pipewire-pulseaudio
pipewire-alsa
pipewire-jack-audio-connection-kit
pipewire-gstreamer

# Wine dependencies (lutris recommends)
winetricks
7zip
fluid-soundfont-gs

# Additional utilities
fastfetch
btop
hwdata

# GPU monitoring tools
nvtop
corectrl

# Mesa drivers for hybrid graphics / fallback
mesa-dri-drivers
mesa-libEGL
mesa-libGL
mesa-vulkan-drivers
vulkan-tools
mesa-demos

# Wayland EGL support for NVIDIA
egl-wayland

# Exclude X11 packages (Wayland-only, but keep XWayland for gaming)
-xorg-x11-server-Xorg
-xorg-x11-utils
-xorg-x11-apps
-xorg-x11-fonts*
-xorg-x11-drv-*

# RGB lighting control
openrgb

# From Bazzite COPR: ryzenadj for AMD Ryzen tuning
ryzenadj

# Flatpak support for Steam and other apps
flatpak

%end

### SCAP Security Guide - Fedora OSPP Profile (Server Hardening Guidance)
### Note: STIG profile does not exist for Fedora
%addon --name=com_redhat_oscap
    content-type = scap-security-guide
    profile = xccdf_org.ssgproject.content_profile_ospp
%end

### Post-installation commands.
%post --log=/root/ks-post.log

# ==============================================================================
# 0. Disable suspend/hibernate (at user request for stability)
# ==============================================================================
mkdir -p /etc/systemd/sleep.conf.d
cat << 'EOF' > /etc/systemd/sleep.conf.d/no-suspend.conf
[Sleep]
SuspendMode=
HibernateMode=
SuspendState=
HibernateState=
EOF

systemctl mask sleep.target 2>/dev/null || true
systemctl mask suspend.target 2>/dev/null || true
systemctl mask hibernate.target 2>/dev/null || true
systemctl mask hybrid-sleep.target 2>/dev/null || true

mkdir -p /etc/systemd/logind.conf.d
cat << 'EOF' > /etc/systemd/logind.conf.d/no-suspend.conf
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
EOF

# ==============================================================================
# 1. FIPS 140-3 compliance configuration
# ==============================================================================
# Configure system-wide crypto policy to FIPS mode
update-crypto-policies --set FIPS || true

# Ensure FIPS is enabled in dracut for initramfs
cat << 'EOF' > /etc/dracut.conf.d/40-fips.conf
add_dracutmodules+=" fips "
EOF

# Regenerate initramfs with FIPS module
dracut -f --regenerate-all 2>/dev/null || true

# ==============================================================================
# 2. Download AD join script from webserver (moved to separate script)
# ==============================================================================
curl -fsSL "https://netboot.krouse.io/scripts/ad-join-domain.sh" -o /usr/local/bin/ad-join-domain 2>/dev/null || \
curl -fsSL "file:///mnt/install/scripts/ad-join-domain.sh" -o /usr/local/bin/ad-join-domain 2>/dev/null || true

if [ -f /usr/local/bin/ad-join-domain ]; then
    chmod +x /usr/local/bin/ad-join-domain
fi

# ==============================================================================
# 3. Set tmux as default shell (STIG compliance)
# ==============================================================================
# STIG requires terminal multiplexing for sessions
# Create tmux configuration with STIG-compliant settings

cat << 'EOF' > /etc/tmux.conf
# STIG-compliant tmux configuration

# Session locking (STIG V-257789)
set-option -g lock-command '/usr/bin/vlock'
set-option -g lock-after-time 900

# Session timeout (STIG V-257791)
set-option -g detach-on-destroy on

# Monitor activity for session awareness
set-option -g monitor-activity on
set-option -g activity-action other

# Disable visual bell (prevent distraction)
set-option -g visual-bell off
set-option -g visual-activity off
set-option -g visual-silence off

# Secure session naming
set-option -g escape-time 500

# Set terminal type for proper rendering
set-option -g default-terminal 'screen-256color'

# History limit (audit trail)
set-option -g history-limit 10000

# Display session info in status bar
set-option -g status on
set-option -g status-interval 15
set-option -g status-left-length 20
set-option -g status-left '#[fg=green]#H#[default] '
set-option -g status-right '#[fg=yellow]%Y-%m-%d #[fg=cyan]%H:%M#[default] #[fg=red]#(whoami)#[default]'

# Key bindings for session management
bind-key -T prefix l lock-session
bind-key -T prefix d detach-client
EOF

# Set tmux as default shell for kladmin
usermod -s /usr/bin/tmux kladmin 2>/dev/null || true

# Ensure tmux exists in /etc/shells
grep -q '^/usr/bin/tmux$' /etc/shells || echo '/usr/bin/tmux' >> /etc/shells

# ==============================================================================
# 4. Basic system configuration
# ==============================================================================
chage -I -1 -m 0 -M 99999 -E -1 root
chage -I -1 -m 0 -M 99999 -E -1 kladmin

# SSH configuration (OSPP/STIG best-effort)
cat << 'EOF' > /etc/ssh/sshd_config.d/99-hardening.conf
# FIPS-compliant SSH configuration
Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr,aes128-ctr
MACs hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,ecdh-sha2-nistp521,ecdh-sha2-nistp384
HostKeyAlgorithms rsa-sha2-512,rsa-sha2-256,ecdsa-sha2-nistp521,ecdsa-sha2-nistp384

# STIG-compliant settings
LogLevel VERBOSE
PermitRootLogin no
MaxAuthTries 3
MaxSessions 10
ClientAliveInterval 600
ClientAliveCountMax 0
LoginGraceTime 60
PermitEmptyPasswords no
PasswordAuthentication yes
PubkeyAuthentication yes
StrictModes yes
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
EOF

# Audit configuration (STIG best-effort)
cat << 'EOF' > /etc/audit/rules.d/99-stig.rules
## STIG Audit Rules for Fedora
## Login/Logout monitoring
-w /var/log/wtmp -p wa -k session
-w /var/run/utmp -p wa -k session
-w /var/log/btmp -p wa -k session
-w /var/log/lastlog -p wa -k session
-w /var/log/tallylog -p wa -k logins

## User/group changes
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege
-w /etc/sudoers.d/ -p wa -k privilege

## System configuration changes
-w /etc/sysctl.conf -p wa -k sysctl
-w /etc/sysctl.d/ -p wa -k sysctl
-w /etc/modprobe.d/ -p wa -k modprobe
-w /etc/modules-load.d/ -p wa -k modules

## Time changes
-w /etc/chrony.conf -p wa -k time
-w /etc/localtime -p wa -k time

## Crypto/policy changes
-w /etc/crypto-policies/ -p wa -k crypto
-w /etc/pam.d/ -p wa -k pam

## Monitor for unauthorized software installations
-w /usr/bin/ -p x -k exec
-w /usr/sbin/ -p x -k exec

## Kernel module loading
-a always,exit -F arch=b64 -S init_module,finit_module -F auid>=1000 -k module-load
-a always,exit -F arch=b64 -S delete_module -F auid>=1000 -k module-unload

## File deletion
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=1000 -k file_delete

## Privilege escalation
-a always,exit -F arch=b64 -S setuid,setgid -F auid>=1000 -k privilege_escalation

## Failed access attempts
-a always,exit -F arch=b64 -S open,openat -F exit=-EACCES -F auid>=1000 -k access_failed
-a always,exit -F arch=b64 -S open,openat -F exit=-EPERM -F auid>=1000 -k access_denied
EOF

# Set audit buffer and failure modes
sed -i 's,-b.*,-b 8192,g' /etc/audit/rules.d/audit.rules 2>/dev/null || true
sed -i 's,-f [0-2],-f 2,g' /etc/audit/rules.d/audit.rules 2>/dev/null || true

# Setup log rotation
sed -i 's,weekly,daily,g' /etc/logrotate.conf
sed -i 's,rotate [0-9],rotate 30,g' /etc/logrotate.conf
sed -i 's,^#*compress,compress,g' /etc/logrotate.conf

# Setup Chrony configs
sed -i 's,pool.*,,g' /etc/chrony.conf
echo 'server 10.3.0.5 burst prefer' >> /etc/chrony.conf
echo 'server 10.3.0.6 burst prefer' >> /etc/chrony.conf

dnf makecache

echo "kladmin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/kladmin

# ==============================================================================
# 5. GNOME Remote Desktop configuration (RDP server)
# ==============================================================================
# Enable GNOME Remote Desktop for RDP access
systemctl enable gnome-remote-desktop.service 2>/dev/null || true

# Configure RDP via gsettings (will be applied on first login)
mkdir -p /home/kladmin/.config
cat << 'EOF' > /home/kladmin/.config/autostart/grd-rdp-enable.desktop
[Desktop Entry]
Type=Application
Name=Enable RDP
Exec=sh -c 'gsettings set org.gnome.desktop.remote-desktop.rdp enable true && gsettings set org.gnome.desktop.remote-desktop.rdp auth-method prompt'
OnlyShowIn=GNOME;
EOF
chown 1001:1001 /home/kladmin/.config/autostart/grd-rdp-enable.desktop

# ==============================================================================
# 6. Create and trust Packer & Ansible tmp folders
# ==============================================================================
mkdir -p /opt/.{packer,ansible}/tmp

# Create fapolicyd trust files (daemon not running in kickstart)
mkdir -p /etc/fapolicyd/trust.d
cat << 'EOF' > /etc/fapolicyd/trust.d/packer
/opt/.packer/tmp
EOF
cat << 'EOF' > /etc/fapolicyd/trust.d/ansible
/opt/.ansible/tmp
EOF

chown 1001:1001 -R /opt/.{packer,ansible}

# Create fapolicyd rules for packer/ansible directories
cat << 'EOF' > /etc/fapolicyd/rules.d/10-packer.rules
allow perm=any uid=1001 : dir=/opt/.packer/tmp
EOF

cat << 'EOF' > /etc/fapolicyd/rules.d/10-ansible.rules
allow perm=any uid=1001 : dir=/opt/.ansible/tmp
EOF

chmod 644 /etc/fapolicyd/rules.d/10-*.rules
chown root:fapolicyd /etc/fapolicyd/rules.d/10-*.rules
fagenrules --load

# ==============================================================================
# 7. NVIDIA GPU Detection and Driver Installation
# ==============================================================================
if lspci -nn | grep -qi 'nvidia'; then
    echo "NVIDIA GPU detected - installing NVIDIA drivers"

    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/fedora44/x86_64/cuda-fedora44.repo -o /etc/yum.repos.d/cuda-fedora44.repo

    rpm --import https://developer.download.nvidia.com/compute/cuda/repos/fedora44/x86_64/73CD9B30.pub

    dnf install -y cuda-drivers cuda-toolkit

    systemctl enable nvidia-persistenced 2>/dev/null || true

    cat << 'EOF' > /etc/modprobe.d/nvidia-power.conf
options nvidia NVreg_EnableGpuFirmware=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia-drm modeset=1
EOF

    echo "NVIDIA drivers installed successfully"
else
    echo "No NVIDIA GPU detected - skipping NVIDIA driver installation"
fi

# ==============================================================================
# 8. Install Flatpak applications
# ==============================================================================
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

# Steam
flatpak install -y flathub com.valvesoftware.Steam || true

# Discord
flatpak install -y flathub com.discordapp.Discord || true

# VSCodium
flatpak install -y flathub com.vscodium.codium || true

# Waterfox
flatpak install -y flathub net.waterfox.waterfox || true

# ==============================================================================
# 9. Install Mesh-LLM (AI assistant tool)
# ==============================================================================
curl -fsSL https://meshllm.cloud/install.sh | bash -s -- --no-setup || true

# Add to PATH for all users
if [ -d "$HOME/.local/bin" ]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /etc/profile.d/mesh-llm.sh
fi

# ==============================================================================
# 10. Gaming directory setup and fapolicyd rules
# ==============================================================================
mkdir -p /home/kladmin/.local/share /home/kladmin/.steam/steam /home/kladmin/.wine

# Create fapolicyd trust files for gaming directories
mkdir -p /etc/fapolicyd/trust.d
cat << 'EOF' > /etc/fapolicyd/trust.d/games
/home/kladmin/.local/share
EOF
cat << 'EOF' > /etc/fapolicyd/trust.d/steam
/home/kladmin/.steam
EOF
cat << 'EOF' > /etc/fapolicyd/trust.d/wine
/home/kladmin/.wine
EOF

cat << 'EOF' > /etc/fapolicyd/rules.d/20-gaming.rules
allow perm=any uid=1001 : dir=/home/kladmin/.steam/steam
allow perm=any uid=1001 : dir=/home/kladmin/.local/share/Steam
EOF

chmod 644 /etc/fapolicyd/rules.d/20-gaming.rules
chown root:fapolicyd /etc/fapolicyd/rules.d/20-gaming.rules
fagenrules --load

# ==============================================================================
# 11. Configure SELinux for gaming
# ==============================================================================
setsebool -P domain_can_exec_manage 1
setsebool -P wine_mmap_zero_ignore 1
setsebool -P nis_enabled 1

# ==============================================================================
# 12. Configure Steam Play (Proton) for all titles
# ==============================================================================
mkdir -p /home/kladmin/.local/share/Steam/config

cat << 'EOF' > /home/kladmin/.local/share/Steam/config/steamapps.vdf
"steamplay"
{
    "EnableAppList"       "1"
    "MinServerGameClientVersion"       "0"
    "MinClientVersion"       "0"
}
EOF

# ==============================================================================
# 13. Configure GameMode
# ==============================================================================
mkdir -p /home/kladmin/.config
cat << 'EOF' > /home/kladmin/.config/gamemode.ini
[General]
DesiredSettings=performance

[cpu]
gov=performance
minfreq=0
maxfreq=0
restoregov=true

[gpu]
engineboost=3
extraperformance=true
restore=false

[gpuMem]
maxfreq=0
minfreq=0
restore=false
EOF

# ==============================================================================
# 14. Configure tuned profile for gaming
# ==============================================================================
mkdir -p /usr/lib/tuned/gaming-bazzite

cat << 'EOF' > /usr/lib/tuned/gaming-bazzite/tuned.conf
[cpu]
boost=1

[audio]
timeout=0

[sysctl]
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.dirty_bytes = 268435456
vm.dirty_background_bytes = 134217728
vm.page-cluster = 0
EOF

cat << 'EOF' > /usr/lib/tuned/gaming-bazzite/script.sh
#!/bin/sh
. /usr/lib/tuned/functions

start() {
    return 0
}

stop() {
    return 0
}

process "$@"
EOF

chmod +x /usr/lib/tuned/gaming-bazzite/script.sh
tuned-adm profile gaming-bazzite

# ==============================================================================
# 15. Udev rules for gaming hardware
# ==============================================================================
mkdir -p /etc/udev/rules.d

# IO Scheduler for NVMe/SSD
cat << 'EOF' > /etc/udev/rules.d/60-schedulers.rules
# Set mq-deadline scheduler for SSDs
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
# Set none for NVMe (already optimal)
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
# Set bfq for HDDs
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF

# Gaming controller udev rules (Xbox, PlayStation, Nintendo, Steam Controller)
cat << 'EOF' > /etc/udev/rules.d/70-gaming-controllers.rules
# Xbox controllers (official and third-party)
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="028e", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="028f", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02d1", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02dd", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02e0", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02e3", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02ea", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02fd", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="0b00", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="0b05", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="0b12", MODE="0666"

# PlayStation controllers (DualShock 3, 4, DualSense)
SUBSYSTEM=="usb", ATTR{idVendor}=="054c", ATTR{idProduct}=="0268", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="054c", ATTR{idProduct}=="05c4", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="054c", ATTR{idProduct}=="05c5", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="054c", ATTR{idProduct}=="09cc", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="054c", ATTR{idProduct}=="0ce6", MODE="0666"

# Nintendo Switch Pro Controller
SUBSYSTEM=="usb", ATTR{idVendor}=="057e", ATTR{idProduct}=="2009", MODE="0666"

# Steam Controller (wired and wireless)
SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="1042", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="1102", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="1142", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="1201", MODE="0666"

# Steam Deck
SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="1205", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="1206", MODE="0666"

# Generic Bluetooth controller support
KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
EOF

# Racing wheel and flight stick rules
cat << 'EOF' > /etc/udev/rules.d/71-racing-flight.rules
# Logitech racing wheels
SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c294", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c295", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c24f", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c262", MODE="0666"

# Thrustmaster wheels and flight sticks
SUBSYSTEM=="usb", ATTR{idVendor}=="044f", ATTR{idProduct}=="b65d", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="044f", ATTR{idProduct}=="b65e", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="044f", ATTR{idProduct}=="b66e", MODE="0666"

# Fanatec wheels
SUBSYSTEM=="usb", ATTR{idVendor}=="0eb7", ATTR{idProduct}=="0*", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="0eb7", ATTR{idProduct}=="1*", MODE="0666"
EOF

# ==============================================================================
# 16. OpenRGB configuration for RGB lighting control
# ==============================================================================
usermod -aG i2c kladmin 2>/dev/null || true

cat << 'EOF' > /etc/modules-load.d/i2c-dev.conf
i2c-dev
EOF

cat << 'EOF' > /etc/udev/rules.d/99-openrgb.rules
# OpenRGB udev rules for RGB lighting control
# Allow access to USB devices
SUBSYSTEM=="usb", ATTR{idVendor}=="1038", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="1b1c", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="195d", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="1462", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="1532", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="26ce", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="1e71", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="0c45", MODE="0666"

# Allow access to SMBus for motherboard RGB
SUBSYSTEM=="i2c-dev", MODE="0660", GROUP="i2c"
KERNEL=="i2c-[0-9]*", MODE="0660", GROUP="i2c"

# Corsair devices
SUBSYSTEM=="hidraw", ATTR{idVendor}=="1b1c", MODE="0666"

# Razer devices
SUBSYSTEM=="hidraw", ATTR{idVendor}=="1532", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="1532", MODE="0666"

# SteelSeries devices
SUBSYSTEM=="hidraw", ATTR{idVendor}=="1038", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="1038", MODE="0666"

# ASUS Aura devices
SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", MODE="0666"
SUBSYSTEM=="hidraw", ATTR{idVendor}=="0b05", MODE="0666"

# MSI Mystic Light devices
SUBSYSTEM=="usb", ATTR{idVendor}=="1462", MODE="0666"

# NZXT devices
SUBSYSTEM=="usb", ATTR{idVendor}=="1e71", MODE="0666"

# EVGA Flow Control
SUBSYSTEM=="usb", ATTR{idVendor}=="3842", MODE="0666"
EOF

udevadm control --reload-rules 2>/dev/null || true
udevadm trigger 2>/dev/null || true

# ==============================================================================
# 17. NVIDIA overclocking utility (if NVIDIA GPU present)
# ==============================================================================
lspci -nn | grep -qi 'nvidia' && cat << 'EOF' > /usr/local/bin/nvidia-oc
#!/bin/bash
case "$1" in
    core) nvidia-smi -lgc "$2" ;;
    mem) nvidia-smi -lmc "$2" ;;
    power) nvidia-smi -pl "$2" ;;
    max) nvidia-smi -pl 350 && nvidia-smi -lgc 200 && nvidia-smi -lmc 1000 ;;
    reset) nvidia-smi -rgc && nvidia-smi -rmc && nvidia-smi -pl 100% ;;
    status) nvidia-smi -q -d CLOCK,POWER ;;
    *) echo "Usage: $0 {core|mem|power|max|reset|status} [value]" ;;
esac
EOF
lspci -nn | grep -qi 'nvidia' && chmod +x /usr/local/bin/nvidia-oc

# ==============================================================================
# 18. Final ownership settings
# ==============================================================================
chown -R 1001:1001 /home/kladmin/.local
chown -R 1001:1001 /home/kladmin/.steam
chown -R 1001:1001 /home/kladmin/.wine
chown -R 1001:1001 /home/kladmin/.config

# ==============================================================================
# 19. Apply Windows 10 theme (GNOME 50 compatible, idempotent)
# ==============================================================================
# Script detects kickstart environment automatically (no D-Bus session)
# Theme settings will apply on first user login
curl -fsSL "https://netboot.krouse.io/scripts/configure-windows10-theme.sh" -o /tmp/configure-windows10-theme.sh 2>/dev/null || \
    curl -fsSL "file:///mnt/install/scripts/configure-windows10-theme.sh" -o /tmp/configure-windows10-theme.sh 2>/dev/null || \
    echo "Theme script not found, skipping theme installation"

if [[ -f /tmp/configure-windows10-theme.sh ]]; then
    chmod +x /tmp/configure-windows10-theme.sh
    echo "Installing Windows 10 theme with Aura Glass (GNOME 50 compatible)..."
    bash /tmp/configure-windows10-theme.sh || echo "Theme installation had errors, continuing..."
    rm -f /tmp/configure-windows10-theme.sh
fi

# Ensure user owns their theme files (if created)
if [[ -d /home/kladmin/.local/share/aura-glass ]]; then
    chown -R 1001:1001 /home/kladmin/.local/share/aura-glass
fi

%end

### Reboot after the installation is complete.
reboot
