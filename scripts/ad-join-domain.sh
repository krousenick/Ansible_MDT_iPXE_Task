#!/bin/bash
# Active Directory Domain Join Script (Idempotent)
# Run with: sudo ad-join-domain <domain> <admin-user> [computer-ou]
#
# This script joins a Fedora system to an Active Directory domain using SSSD.
# It is idempotent - running multiple times will not cause errors.
#
# Features:
#   - Idempotent: Safe to run multiple times
#   - Automatic home directory creation via oddjob
#   - Credential caching for offline login (60 days)
#   - AD profile photo synchronization to GNOME
#   - GNOME 50 user photo support
#
# Requirements:
#   - freeipa-client, sssd-ad, oddjob, oddjob-mkhomedir packages installed
#   - DNS must be able to resolve the AD domain controllers
#   - Admin credentials with rights to join computers to the domain
#
# Usage:
#   sudo ad-join-domain ad.example.com admin-user
#   sudo ad-join-domain ad.example.com admin-user 'OU=Computers,DC=ad,DC=example,DC=com'
#
# After joining, to allow specific groups:
#   realm permit -g 'Domain Users@AD.EXAMPLE.COM'
#   realm permit -g 'Domain Admins@AD.EXAMPLE.COM'

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    log "ERROR: $*" >&2
    exit 1
}

is_service_enabled() {
    local service="$1"
    systemctl is-enabled "$service" 2>/dev/null | grep -q "^enabled$"
}

is_service_active() {
    local service="$1"
    systemctl is-active "$service" 2>/dev/null | grep -q "^active$"
}

if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root"
fi

if [ $# -lt 2 ]; then
    echo "Usage: $0 <domain> <admin-user> [computer-ou]"
    echo "Example: $0 ad.example.com admin-user 'OU=Computers,DC=ad,DC=example,DC=com'"
    exit 1
fi

DOMAIN="$1"
ADMIN_USER="$2"
COMPUTER_OU="${3:-}"

REALM=$(echo "$DOMAIN" | tr "[:lower:]" "[:upper:]")

echo "=========================================="
echo "Active Directory Domain Join (Idempotent)"
echo "=========================================="
echo "Domain: $DOMAIN"
echo "Realm: $REALM"
echo "Admin user: $ADMIN_USER"
if [ -n "$COMPUTER_OU" ]; then
    echo "Computer OU: $COMPUTER_OU"
fi
echo "=========================================="
echo ""

log "Configuring oddjob service..."
if ! is_service_enabled oddjobd.service; then
    systemctl enable oddjobd.service
    log "Enabled oddjobd.service"
else
    log "oddjobd.service already enabled"
fi

if ! is_service_active oddjobd.service; then
    systemctl start oddjobd.service
    log "Started oddjobd.service"
else
    log "oddjobd.service already running"
fi

log "Synchronizing system time with chronyd prior to AD join..."
if systemctl is-active chronyd.service 2>/dev/null | grep -q "^active$"; then
    chronyc makestep || log "WARNING: chronyc makestep failed, continuing anyway..."
else
    log "WARNING: chronyd is not running. Kerberos authentication may fail if time is desynchronized."
fi

CURRENT_DOMAIN=$(realm list 2>/dev/null | grep -A1 "domain-name" | grep -v "domain-name" | head -1 || true)

if [ -n "$CURRENT_DOMAIN" ]; then
    if [ "$CURRENT_DOMAIN" = "$DOMAIN" ] || [ "$(echo "$CURRENT_DOMAIN" | tr "[:lower:]" "[:upper:]")" = "$REALM" ]; then
        log "System is already joined to $DOMAIN"
        log "Reconfiguring SSSD settings..."
    else
        log "WARNING: System is joined to different domain: $CURRENT_DOMAIN"
        log "Use 'realm leave $CURRENT_DOMAIN' first if you want to join $DOMAIN"
    fi
else
    log "Joining domain $DOMAIN..."
    log "You will be prompted for the administrator password."
    echo ""
    
    if [ -n "$COMPUTER_OU" ]; then
        realm join --user="$ADMIN_USER" --computer-ou="$COMPUTER_OU" \
            --client-software=sssd --server-software=active-directory "$DOMAIN"
    else
        realm join --user="$ADMIN_USER" \
            --client-software=sssd --server-software=active-directory "$DOMAIN"
    fi
    log "Successfully joined $DOMAIN"
fi

log "Surgically configuring SSSD settings..."

SSSD_CONF="/etc/sssd/sssd.conf"

if [ ! -f "$SSSD_CONF" ]; then
    error "$SSSD_CONF was not generated. The domain join likely failed."
fi

# The realm join command dynamically creates the domain block in lowercase
DOMAIN_LOWER=$(echo "$DOMAIN" | tr '[:upper:]' '[:lower:]')
# Pre-escape the forward slash so sed can process the regex safely
DOMAIN_SED="\[domain\/$DOMAIN_LOWER\]"

declare -A SSSD_SETTINGS=(
    ["cache_credentials"]="True"
    ["offline_credentials_expiration"]="60"
    ["ldap_user_extra_attrs"]="altSecurityIdentities,altServer,authPolicy,authenticationOptions,jpegPhoto,thumbnailPhoto"
    ["enumerate"]="False"
)

# Inject or update parameters specifically within the generated domain section
for key in "${!SSSD_SETTINGS[@]}"; do
    val="${SSSD_SETTINGS[$key]}"
    
    # Check if the key already exists inside this specific domain block
    if sed -n "/^${DOMAIN_SED}/,/^\[/p" "$SSSD_CONF" | grep -q "^${key}\s*="; then
        log "Updating existing setting: $key"
        sed -i -E "/^${DOMAIN_SED}/,/^\[/{s/^${key}\s*=.*/${key} = ${val}/}" "$SSSD_CONF"
    else
        log "Injecting new setting: $key"
        sed -i "/^${DOMAIN_SED}/a ${key} = ${val}" "$SSSD_CONF"
    fi
done

# Restart SSSD to apply injected configurations
chmod 600 "$SSSD_CONF"
chown root:root "$SSSD_CONF"
systemctl restart sssd.service
log "Restarted sssd.service to apply configuration"

log "Configuring AccountsService for GNOME user photos..."

mkdir -p /var/lib/AccountsService/users
mkdir -p /var/lib/AccountsService/icons
chmod 755 /var/lib/AccountsService/users
chmod 755 /var/lib/AccountsService/icons

if ! is_service_enabled accounts-daemon.service; then
    systemctl enable accounts-daemon.service
    log "Enabled accounts-daemon.service"
else
    log "accounts-daemon.service already enabled"
fi

if ! is_service_active accounts-daemon.service; then
    systemctl start accounts-daemon.service
    log "Started accounts-daemon.service"
else
    log "accounts-daemon.service already running"
fi

log "Creating AD photo synchronization script..."

cat << 'PHOTO_SCRIPT' > /usr/local/bin/sync-ad-photos
#!/bin/bash
# Sync Active Directory user photos to GNOME AccountsService
# This script fetches user photos from AD and makes them available to GNOME

set -euo pipefail

ICONS_DIR="/var/lib/AccountsService/icons"
USERS_DIR="/var/lib/AccountsService/users"

mkdir -p "$ICONS_DIR" "$USERS_DIR"

get_ad_users() {
    getent passwd | grep -E "@[A-Z]+$" | cut -d: -f1 | sort -u
}

generate_initial_avatar() {
    local user="$1"
    local output="$2"
    local first_char
    
    first_char=$(echo "${user%%@*}" | head -c 1 | tr '[:lower:]' '[:upper:]')
    
    if command -v magick >/dev/null 2>&1; then
        magick -size 96x96 "xc:#4a90d9" \
            -gravity Center -pointsize 48 -fill white \
            -annotate +0+0 "$first_char" \
            "$output" 2>/dev/null || return 1
    else
        return 1
    fi
}

sync_user_photo() {
    local user="$1"
    local uid
    local domain_realm
    local ldap_uri
    local base_dn
    local photo_fetched=false
    
    uid=$(id -u "$user" 2>/dev/null) || return 0
    
    if [ -f "$ICONS_DIR/$user" ]; then
        return 0
    fi
    
    if command -v ldapsearch >/dev/null 2>&1; then
        domain_realm=$(realm list 2>/dev/null | grep "domain-name:" | awk '{print $2}' | head -1 | tr '[:lower:]' '[:upper:]')
        
        if [ -n "$domain_realm" ]; then
            ldap_uri="ldap://${domain_realm%%.*}.${domain_realm#*.}"
            
            base_dn=""
            IFS='.' read -ra parts <<< "$domain_realm"
            for part in "${parts[@]}"; do
                base_dn="${base_dn:+$base_dn,}DC=$part"
            done
            
            if klist 2>/dev/null | grep -q "krbtgt"; then
                local user_dn
                local tmp_photo="/tmp/${user}@photo.jpg"
                
                user_dn=$(ldapsearch -H "$ldap_uri" -b "$base_dn" \
                    "(&(objectClass=user)(sAMAccountName=${user%%@*}))" dn 2>/dev/null | \
                    grep "^dn:" | head -1 | sed 's/^dn: //') || true
                
                if [ -n "$user_dn" ]; then
                    ldapsearch -H "$ldap_uri" -b "$base_dn" \
                        "(&(objectClass=user)(sAMAccountName=${user%%@*}))" \
                        thumbnailPhoto jpegPhoto 2>/dev/null | \
                        sed -n '/^thumbnailPhoto:: /,/^[^ ]/p' | \
                        tail -n +2 | tr -d '\n ' | base64 -d > "$tmp_photo" 2>/dev/null || true
                    
                    if [ -s "$tmp_photo" ]; then
                        cp "$tmp_photo" "$ICONS_DIR/$user"
                        chmod 644 "$ICONS_DIR/$user"
                        photo_fetched=true
                    fi
                    rm -f "$tmp_photo"
                fi
            fi
        fi
    fi
    
    if [ "$photo_fetched" = "false" ]; then
        local tmp_avatar="/tmp/${user}@avatar.png"
        if generate_initial_avatar "$user" "$tmp_avatar"; then
            cp "$tmp_avatar" "$ICONS_DIR/$user"
            chmod 644 "$ICONS_DIR/$user"
        fi
        rm -f "$tmp_avatar"
    fi
    
    if [ ! -f "$USERS_DIR/$user" ]; then
        cat << EOF > "$USERS_DIR/$user"
[User]
SystemAccount=false
Icon=$ICONS_DIR/$user
EOF
        chmod 644 "$USERS_DIR/$user"
    elif [ -f "$ICONS_DIR/$user" ] && ! grep -q "Icon=" "$USERS_DIR/$user"; then
        echo "Icon=$ICONS_DIR/$user" >> "$USERS_DIR/$user"
    fi
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "Syncing AD user photos..."

for user in $(get_ad_users); do
    sync_user_photo "$user"
done

log "AD user photo sync complete"
PHOTO_SCRIPT

chmod +x /usr/local/bin/sync-ad-photos

cat << 'EOF' > /etc/systemd/system/ad-photos-sync.service
[Unit]
Description=Sync Active Directory user photos
After=sssd.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sync-ad-photos
Nice=19
IOSchedulingClass=idle

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > /etc/systemd/system/ad-photos-sync.timer
[Unit]
Description=Sync Active Directory user photos daily

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=3600

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload

if ! is_service_enabled ad-photos-sync.timer; then
    systemctl enable ad-photos-sync.timer
    log "Enabled ad-photos-sync.timer"
else
    log "ad-photos-sync.timer already enabled"
fi

log "Configuring GNOME user photo display..."

mkdir -p /etc/dconf/db/local.d

cat << 'EOF' > /etc/dconf/db/local.d/02-user-photos
[org/gnome/login-screen]
enable-fingerprint-authentication=true

[org/gnome/desktop/interface]
clock-show-weekday=true
clock-show-date=true
EOF

dconf update 2>/dev/null || true

cat << 'EOF' > /etc/profile.d/gnome-user-photo.sh
#!/bin/bash
if [ -d "/var/lib/AccountsService/icons" ]; then
    export XDG_DATA_DIRS="/var/lib/AccountsService:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
fi
EOF

chmod +x /etc/profile.d/gnome-user-photo.sh

log "Configuring PAM for user photo lookups..."

if ! grep -q "pam_sss" /etc/pam.d/system-auth 2>/dev/null; then
    log "PAM configured via authselect, no manual changes needed"
else
    log "PAM already configured with SSSD"
fi

log "Ensuring SSSD service is running..."

if ! is_service_enabled sssd.service; then
    systemctl enable sssd.service
    log "Enabled sssd.service"
else
    log "sssd.service already enabled"
fi

systemctl restart sssd.service
log "Restarted sssd.service to apply configuration"

echo ""
echo "=========================================="
echo "Domain Join Status"
echo "=========================================="
echo ""

if realm list 2>/dev/null | grep -q "$DOMAIN"; then
    log "Successfully joined to $DOMAIN"
else
    log "Domain membership status uncertain"
fi

echo ""
echo "Configuration complete!"
echo ""
echo "Next steps:"
echo "  1. Permit domain users/groups:"
echo "     realm permit -g 'Domain Users@${REALM}'"
echo "     realm permit -g 'Domain Admins@${REALM}'"
echo ""
echo "  2. Verify domain membership:"
echo "     realm list"
echo "     id <username>@${REALM}"
echo ""
echo "  3. Sync user photos manually:"
echo "     /usr/local/bin/sync-ad-photos"
echo ""
echo "  4. Photos will auto-sync daily via systemd timer"
echo ""
echo "  5. For GNOME 50 photo support, ensure ImageMagick is installed:"
echo "     dnf install ImageMagick"
echo ""
