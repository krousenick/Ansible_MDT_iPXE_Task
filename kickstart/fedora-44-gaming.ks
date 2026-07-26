# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Fedora 44 Gaming Edition (Bazzite-style)

### Installs from the network over http
url --url=https://download.fedoraproject.org/pub/fedora/linux/releases/44/Workstation/x86_64/os

### DNF Configuration (Bazzite-style)
dnf --config=/tmp/dnf.conf config

### Add COPR repos for Bazzite gaming packages (Bazzite repos have Fedora 44)
repo --name=copr:copr.fedorainfracloud.org:ublue-os:staging --baseurl=https://download.copr.fedorainfracloud.org/results/ublue-os/staging/fedora-44-x86_64/
repo --name=copr:copr.fedorainfracloud.org:ublue-os:bazzite --baseurl=https://download.copr.fedorainfracloud.org/results/ublue-os/bazzite/fedora-44-x86_64/
### Note: audinux only has F41/42 - using standard Fedora repos for audio

### Additional repos for NVIDIA drivers
repo --name=cuda --baseurl=https://developer.download.nvidia.com/compute/cuda/repos/fedora/44/x86_64/

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

### Sets the state of SELinux on the installed system.
selinux --permissive

### Sets the system time zone.
timezone America/New_York --utc

### Sets how the boot loader should be installed.
### Gaming kernel parameters: low latency, no watchdog
bootloader --location=efi --append="split_lock_mitigate=0 nmi_watchdog=0 quiet"

### Initialize any invalid partition tables found on disks.
zerombr

### Removes partitions from the system, prior to creation of new partitions. 
### By default, no partitions are removed.
### --linux	erases all Linux partitions.
### --initlabel Initializes a disk (or disks) by creating a default disk label for all disks in their respective architecture.
clearpart --all --initlabel

### Partitioning (Bazzite-style - using XFS instead of BTRFS for simplicity)
part /boot                   --fstype=xfs     --size=1024       --label=BOOTFS
part /boot/efi               --fstype=efi     --size=512        --label=EFIFS
part pv.01                                           --size=100         --grow

### Create a logical volume management (LVM) group.
volgroup sysvg --pesize=4096 pv.01

### Logical volumes with --grow for flexible disk sizes
logvol swap                  --fstype=swap    --name=lv_swap     --vgname=sysvg --size=8192         --label=SWAPFS
logvol /var/log/audit        --fstype=xfs     --name=lv_audit    --vgname=sysvg --size=4096         --label=AUDITFS --fsoptions="nodev,noexec,nosuid"
logvol /var/log              --fstype=xfs     --name=lv_log      --vgname=sysvg --size=4096         --label=LOGFS --fsoptions="nodev,noexec,nosuid"
logvol /var/tmp              --fstype=xfs     --name=lv_vartmp   --vgname=sysvg --size=4096         --label=VARFS --fsoptions="nodev"
logvol /var                  --fstype=xfs     --name=lv_var      --vgname=sysvg --size=4096         --label=VTMPFS --fsoptions="nodev"
logvol /tmp                  --fstype=xfs     --name=lv_tmp      --vgname=sysvg --size=4096         --label=TMPFS --fsoptions="nodev,noexec,nosuid"
logvol /home                 --fstype=xfs     --name=lv_home     --vgname=sysvg --size=8192         --label=HOMEFS --fsoptions="nodev,nosuid"
logvol /                     --fstype=xfs     --name=lv_root     --vgname=sysvg --size=20480 --grow  --label=ROOTFS

### Packages selection (Bazzite-style gaming packages)
%packages --excludedocs --inst-langs=en --exclude-weakdeps
@Core
@graphical-server-environment
@GNOME
@multimedia
@hardware-support
chrony
logrotate
rsyslog
rsyslog-gnutls
rng-tools
tmux
cloud-utils-growpart
net-tools
iputils
scap-security-guide
selinux-policy
selinux-policy-targeted

# Gaming packages (Bazzite-style)
steam
lutris
gamescope
mangohud
vkBasalt
libFAudio
openxr
umu-launcher
umu-wrapper
gamemode
libgamemode
libgamemode-auto
pipewire
wireplumber
pipewire-pulseaudio

# Additional utilities
fastfetch
btop
git

# GPU overclocking and monitoring tools
green-with-envy
nvtop
corectrl
amdctl
ryzenadj

# NVIDIA drivers and graphics support (from NVIDIA CUDA repo)
# Meta-package that pulls in the latest NVIDIA driver
cuda-drivers

# Mesa drivers for hybrid graphics / fallback
mesa-dri-drivers
mesa-libEGL
mesa-libGL
mesa-vulkan-drivers
vulkan-tools

# Wayland EGL support for NVIDIA
egl-wayland
egl-wayland2

# Gaming: Wine/Proton/Steam (from EPEL)
@multimedia
%end

### Enable SCAP Security Guide (STIG) for Fedora
%addon --name=scSecurityGuide
    type = scap-workbench
    profile = xccdf_org.ssgproject.content_profile_stig
%end

### Post-installation commands.
%post --log=/root/ks-post.log

# Disable root password expiry
chage -I -1 -m 0 -M 99999 -E -1 root
chage -I -1 -m 0 -M 99999 -E -1 kladmin

# SSH configuration (STIG)
sed -i 's,^#*ClientAliveInterval.*,ClientAliveInterval 600,g' /etc/ssh/sshd_config
sed -i 's,^#*PasswordAuthentication.*,PasswordAuthentication yes,g' /etc/ssh/sshd_config
sed -i 's,^#*PubkeyAuthentication.*,PubkeyAuthentication yes,g' /etc/ssh/sshd_config

# Audit configuration (STIG)
sed -i 's,-b.*,-b 32000,g' /etc/audit/rules.d/audit.rules 2>/dev/null || true
sed -i 's,-f [1-2],-f 1,g' /etc/audit/rules.d/immutable.rules 2>/dev/null || true

# Setup log Rotation
sed -i 's,weekly,daily,g' /etc/logrotate.conf
sed -i 's,rotate [0-9],rotate 2,g' /etc/logrotate.conf
sed -i 's,^#*compress,compress,g' /etc/logrotate.conf

# Setup Chrony configs
sed -i 's,pool.*,,g' /etc/chrony.conf
echo 'server 10.3.0.5 burst prefer' >> /etc/chrony.conf
echo 'server 10.3.0.6 burst prefer' >> /etc/chrony.conf


dnf makecache
#dnf install -y ipa-client

echo "kladmin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/kladmin
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

# ==============================================================================
# 1. Create and trust Packer & Ansible tmp folders
# ==============================================================================
mkdir -p /opt/.{packer,ansible}/tmp

# Add paths to the fapolicyd trust database
fapolicyd-cli --file add /opt/.packer/tmp --trust-file packer
fapolicyd-cli --file add /opt/.ansible/tmp --trust-file ansible

# Set permissions for the build environment
chown 1001:1001 -R /opt/.{packer,ansible}

# ==============================================================================
# 2. Configure fapolicyd Rules (Notice the syntax correction with the ':')
# ==============================================================================
# Rule for Packer (UID 1001)
cat << 'EOF' > /etc/fapolicyd/rules.d/10-packer.rules
allow perm=any uid=1001 : dir=/opt/.packer/tmp
EOF

# Rule for Ansible (Assuming same UID or update accordingly)
cat << 'EOF' > /etc/fapolicyd/rules.d/10-ansible.rules
allow perm=any uid=1001 : dir=/opt/.ansible/tmp
EOF

# Standardize permissions on the custom rule files
chmod 644 /etc/fapolicyd/rules.d/10-*.rules
chown root:fapolicyd /etc/fapolicyd/rules.d/10-*.rules

# ==============================================================================
# 3. Compile and load the new rules into the daemon
# ==============================================================================
fagenrules --load

# ==============================================================================
# 3a. Gaming: Install Wine and Gamemode from EPEL
# ==============================================================================
dnf install -y wine gamemode libgamemode libgamemode-auto 2>/dev/null || true

mkdir -p /home/kladmin/.local/share /home/kladmin/.steam/steam /home/kladmin/.wine

# Add game directories to fapolicyd trust
fapolicyd-cli --file add /home/kladmin/.local/share --trust-file games
fapolicyd-cli --file add /home/kladmin/.steam --trust-file steam
fapolicyd-cli --file add /home/kladmin/.wine --trust-file wine

# Fapolicyd rules for Wine/Proton execution
cat << 'EOF' > /etc/fapolicyd/rules.d/20-gaming.rules
# Allow wine execution for Windows games
allow perm=any uid=1001 : exe=/usr/bin/wine
allow perm=any uid=1001 : exe=/usr/bin/wine64
allow perm=any uid=1001 : exe=/usr/bin/proton
allow perm=any uid=1001 : exe=/usr/bin/steam
allow perm=any uid=1001 : dir=/home/kladmin/.wine
allow perm=any uid=1001 : dir=/home/kladmin/.steam/steam
allow perm=any uid=1001 : dir=/home/kladmin/.local/share/Steam
EOF

chmod 644 /etc/fapolicyd/rules.d/20-gaming.rules
chown root:fapolicyd /etc/fapolicyd/rules.d/20-gaming.rules
fagenrules --load

# ==============================================================================
# 3b. Gaming: Configure SELinux for Wine/Steam
# ==============================================================================
# Enable SELinux booleans for gaming compatibility
setsebool -P domain_can_exec_manage 1
setsebool -P wine_mmap_zero_ignore 1

# Allow NVIDIA driver access
setsebool -P nis_enabled 1

# ==============================================================================
# 3c. Gaming: Install Steam Flatpak and configure Wine/Proton
# ==============================================================================
# Install flathub and Steam
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
flatpak install -y flathub com.valvesoftware.Steam || true

# Configure Steam to use Proton
mkdir -p /home/kladmin/.local/share/Steam
mkdir -p /home/kladmin/.local/share/Steam/config

cat << 'EOF' > /home/kladmin/.local/share/Steam/config/steamapps/sample manifest_nopayload.txt
{
  "UserPreferences" : {
    "CompatToolMapping" : [
      {
        "appid" : 0,
        "type" : 2,
        "name" : "proton_enable",
        "config" : {}
      }
    ],
    "CompatToolPrefix" : {
      "ForceRegistryValue" : "ENABLED"
    }
  }
}
EOF

# Enable Steam Play for all titles
mkdir -p /home/kladmin/.local/share/Steam/config/steamplay
cat << 'EOF' > /home/kladmin/.local/share/Steam/config/steamplay/steamapps.vdf
"steamplay"
{
    "EnableAppList"       "1"
    "MinServerGameClientVersion"       "0"
    "MinClientVersion"       "0"
    "MaxCacheSize"       "52428800"
    "MaxCacheAge"       "2592000"
    "PerAppShaderCache"       "1"
    "BaselineCache"       "1"
}
EOF

# Configure Wine for gaming
mkdir -p /home/kladmin/.wine

# Create Wine prefix with UTF-8 support
cat << 'EOF' > /home/kladmin/.wine/user.reg
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine]
"Version"="win64"

[HKEY_CURRENT_USER\Software\Wine\Fonts]
"Default"="Tahoma"
"DefaultBold"="Tahoma Bold"
"Fixed"="Consolas"

[HKEY_CURRENT_USER\Wine\Direct3D]
"DirectDrawRenderer"="opengl"
"VideoMemorySize"="8192"
EOF

# Configure gamemd for GameMode
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

# Set ownership for gaming files
chown -R 1001:1001 /home/kladmin/.local
chown -R 1001:1001 /home/kladmin/.steam
chown -R 1001:1001 /home/kladmin/.wine
chown -R 1001:1001 /home/kladmin/.config

# ==============================================================================
# 4. Configure tuned profile for gaming (based on Bazzite)
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

[sysfs]
/sys/devices/system/cpu/amd_pstate/cpb_boost=enabled
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

# Enable the gaming tuned profile
tuned-adm profile gaming-bazzite

# ==============================================================================
# 5. Configure udev rules for gaming (Bazzite-style)
# ==============================================================================
# IO Scheduler for NVMe/SSD
mkdir -p /etc/udev/rules.d
cat << 'EOF' > /etc/udev/rules.d/60-schedulers.rules
# Set cfq scheduler for spinning disks
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}=="cfq"
# Set none for NVMe (already optimal)
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}=="none"
EOF

# GPU reset rules for Steam Deck
cat << 'EOF' > /etc/udev/rules.d/80-gpu-reset.rules
# GPU reset for specific hardware
EOF

# Steam Controller wakeup
cat << 'EOF' > /etc/udev/rules.d/99-steamcontroller-wakeup.rules
# Enable wakeup for Steam Controllers
EOF

# ==============================================================================
# 6. Enable Bazzite-style services
# ==============================================================================
systemctl enable input-remapper.service 2>/dev/null || true
systemctl enable dmemcg-booster-system.service 2>/dev/null || true

# ==============================================================================
# 7. Distrobox configuration for gaming containers
# ==============================================================================
mkdir -p /etc/distrobox
cat << 'EOF' > /etc/distrobox/docker.ini
[distrobox]
image=fedora:39
additional_flags=
pre_init_hooks=
post_init_hooks=
pre_stop_hooks=
post_stop_hooks=
EOF

cat << 'EOF' > /etc/distrobox/ubuntu.ini
[distrobox]
image=ubuntu:22.04
additional_flags=
pre_init_hooks=
post_init_hooks=
pre_stop_hooks=
post_stop_hooks=
EOF

# ==============================================================================
# 7. Configure NVIDIA overclocking (cool-bits)
# ==============================================================================
mkdir -p /etc/X11/xorg.conf.d

cat << 'EOF' > /etc/X11/xorg.conf.d/99-nvidia-overclock.conf
Section "Device"
    Identifier     "NVIDIA GPU"
    Driver         "nvidia"
    Option         "Coolbits" "28"
    Option         "RegistryDwords" "PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerLevel=0x3; PowerMizerDefault=3"
EndSection
EOF

cat << 'EOF' > /usr/local/bin/nvidia-oc
#!/bin/bash
case "$1" in
    core) nvidia-smi -lgc "$2" ;;
    mem) nvidia-smi -lmc "$2" ;;
    power) nvidia-smi -pl "$2" ;;
    max) nvidia-smi -pl 350 && nvidia-smi -lgc 200 && nvidia-smi -lmc 1000 ;;
    reset) nvidia-smi -rgc && nvidia-smi -rmc && nvidia-smi -pl 100% ;;
    *) echo "Usage: $0 {core|mem|power|max|reset} [value]" ;;
esac
EOF
chmod +x /usr/local/bin/nvidia-oc

cat << 'EOF' > /usr/local/bin/amd-oc
#!/bin/bash
case "$1" in
    performance) echo "performance" > /sys/class/drm/card0/device/power_dpm_state 2>/dev/null ;;
    reset) echo "auto" > /sys/class/drm/card0/device/power_dpm_state 2>/dev/null ;;
    *) echo "Usage: $0 {performance|reset}" ;;
esac
EOF
chmod +x /usr/local/bin/amd-oc

%end

### Reboot after the installation is complete.
### --eject attempt to eject the media before rebooting.
reboot --eject