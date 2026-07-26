# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# RHEL Linux 9

### Installs from the first attached CD-ROM/DVD on the system.
url --url=http://netboot.krouse.io/rhel/9/x86_64/rhel-9-for-x86_64-baseos-rpms
repo --name=AppStream --baseurl=http://netboot.krouse.io/rhel/${releasever}/${arch}/rhel-9-for-x86_64-appstream-rpms
repo --name=Code-Ready-Builder --baseurl=http://netboot.krouse.io/rhel/${releasever}/${arch}/codeready-builder-for-rhel-9-x86_64-rpms
repo --name=EPEL --baseurl=http://netboot.krouse.io/rhel/${releasever}/${arch}/epel/

### Performs the kickstart installation in text mode. 
### By default, kickstart installations are performed in graphical mode.
text

### Accepts the End User License Agreement.
eula --agreed

### Sets the language to use during installation and the default language to use on the installed system.
lang en_US.UTF-8

### Sets the default keyboard type for the system.
keyboard us

### Disable Initial Setup on first boot
firstboot --disable

### Configure network information for target system and activate network devices in the installer environment (optional)
### --onboot	  enable device at a boot time
### --device	  device to be activated and / or configured with the network command
### --bootproto	  method to obtain networking configuration for device (default dhcp)
### --noipv6	  disable IPv6 on this device
###
### network  --bootproto=static --ip= --netmask=255.255.255.0 --gateway= --nameserver=
network --bootproto=dhcp --hostname=kro-rhel-9-tpl --nameserver=10.3.0.5

### Lock the root account.
rootpw --lock

### The selected profile will restrict root login.
### Add a user that can login and escalate privileges.
user --name=kladmin --password=$ADMIN_PASSWORD_HASHED --iscrypted --homedir=/home/kladmin --groups=wheel --uid=1001

### Configure firewall settings for the system.
### --enabled	reject incoming connections that are not in response to outbound requests
### --ssh		allow sshd service through the firewall
firewall --enabled --ssh

### Sets up the authentication options for the system.
### The SSDD profile sets sha512 to hash passwords. Passwords are shadowed by default
### See the manual page for authselect-profile for a complete list of possible options.
authselect select sssd

### Sets the state of SELinux on the installed system.
### Defaults to enforcing.
selinux --permissive

### Sets the system time zone.
timezone America/New_York

### Sets how the boot loader should be installed.
bootloader --location=mbr --append="audit=1 fips=1" --iscrypted --password=$GRUB_PASSWORD_HASHED

### Initialize any invalid partition tables found on disks.
zerombr

### Removes partitions from the system, prior to creation of new partitions. 
### By default, no partitions are removed.
### --linux	erases all Linux partitions.
### --initlabel Initializes a disk (or disks) by creating a default disk label for all disks in their respective architecture.
clearpart --all --initlabel

### Modify partition sizes for the virtual machine hardware.
### Create primary system partitions.
part /boot               --fstype=xfs                                       --size=512    --label=BOOTFS
part /boot/efi           --fstype=efi                                       --size=50     --label=EFIFS
part pv.01                                                                  --size=100                     --grow

### Create a logical volume management (LVM) group.
volgroup sysvg --pesize=4096 pv.01

### Modify logical volume sizes for the virtual machine hardware.
### Create logical volumes.
logvol swap              --fstype=swap    --name=lv_swap     --vgname=sysvg --size=8192    --label=SWAPFS
logvol /                 --fstype=xfs     --name=lv_root     --vgname=sysvg --size=12288   --label=ROOTFS --grow
logvol /home             --fstype=xfs     --name=lv_home     --vgname=sysvg --size=4096    --label=HOMEFS --fsoptions="nodev,nosuid"
logvol /tmp              --fstype=xfs     --name=lv_tmp      --vgname=sysvg --size=4096    --label=TMPFS --fsoptions="nodev,noexec,nosuid"
logvol /var              --fstype=xfs     --name=lv_var      --vgname=sysvg --size=10240   --label=VTMPFS --fsoptions="nodev"
logvol /var/tmp          --fstype=xfs     --name=lv_vartmp   --vgname=sysvg --size=10240   --label=VARFS --fsoptions="nodev"
logvol /var/log          --fstype=xfs     --name=lv_log      --vgname=sysvg --size=4096    --label=LOGFS --fsoptions="nodev,noexec,nosuid"
logvol /var/log/audit    --fstype=xfs     --name=lv_audit    --vgname=sysvg --size=4096    --label=AUDITFS --fsoptions="nodev,noexec,nosuid"

### Modifies the default set of services that will run under the default runlevel.
services --enabled=NetworkManager,sshd,chronyd,rsyslog,auditd --disabled=kdump

### Do not configure X on the installed system.
skipx

### Packages selection.
%packages --excludedocs --inst-langs=en --exclude-weakdeps #--nocore
@Core
chrony
logrotate
rsyslog
rsyslog-gnutls
rng-tools
tmux
cloud-utils-growpart
net-tools
iputils
selinux-policy
selinux-policy-targeted
%end

### Disable Kdump on the system
%addon com_redhat_kdump --disable
%end

### Enable DISA SRG Profile
%addon com_redhat_oscap
       content-type = scap-security-guide
	   datastream-id = scap_org.open-scap_datastream_from_xccdf_ssg-rhel9-xccdf.xml
	   xccdf-id = scap_org.open-scap_cref_ssg-rhel9-xccdf.xml
       profile = xccdf_org.ssgproject.content_profile_stig
%end

### Post-installation commands.
%post --log=/root/ks-post.log

# Disable root password expiry
chage -I -1 -m 0 -M 99999 -E -1 root
chage -I -1 -m 0 -M 99999 -E -1 kladmin

# STIG; set SSH values
sed -i 's,^#*ClientAliveInterval.*,ClientAliveInterval 600,g' /etc/ssh/sshd_config
sed -i 's,^#*PublickeyAuthentication.*,PublickeyAuthentication yes,g' /etc/ssh/sshd_config
sed -i 's,^#*PasswordAuthentication \(yes\|no\),PasswordAuthentication yes,g' /etc/ssh/sshd_config
sed -i 's,^#*GSSAPIAuthentication \(yes\|no\),GSSAPIAuthentication yes,g' /etc/ssh/sshd_config.d/01-*

# Change the Auditd Buffer LIMITED
sed -i 's,-b.*,-b 32000,g' /etc/audit/rules.d/audit.rules
sed -i 's,-f [1-2],-f 1,g' /etc/audit/rules.d/immutable.rules

# Disable RHEL subscription manager
sed -i 's,enabled=1,enabled=0,g' /etc/dnf/plugins/product-id.conf
sed -i 's,enabled=1,enabled=0,g' /etc/dnf/plugins/subscription-manager.conf

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
%end

### Reboot after the installation is complete.
reboot
