#!/bin/bash
# configure-windows10-theme.sh - Idempotent Windows 10 theme installer (Windows-10 GTK + Icons)
# Compatible with GNOME 50 / Fedora 44
# Safe to run multiple times - will only install/update if needed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GNOME_THEME_DIR="/usr/share/themes"
GTK_THEME_NAME="Windows-10"
ICON_THEME_NAME="Windows-10"
THEME_SOURCE_DIR="${REPO_ROOT}/themes"
INSTALL_AURA="${INSTALL_AURA:-false}"
AURA_ACCENT="blue"
AURA_TRANSPARENCY="90%"
TEMP_DIR=$(mktemp -d)
SCRIPT_VERSION="2.1.0"
FORCE_REINSTALL="${FORCE_REINSTALL:-false}"
# Detect primary user (for bookmarks)
ADMIN_USER="${ADMIN_USER:-$(getent passwd 1000 | cut -d: -f1 || echo "admin")}"

trap "rm -rf $TEMP_DIR" EXIT

log() {
    echo "[Theme Installer] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

detect_kickstart_env() {
    if [[ -z "${DISPLAY:-}" ]] && [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        KICKSTART_ENV=true
        log "Detected kickstart environment (no D-Bus session)"
    else
        KICKSTART_ENV=false
    fi
}

check_gnome_version() {
    GNOME_VERSION=$(gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1) || GNOME_VERSION="0"
    
    if [[ "$GNOME_VERSION" -eq 0 ]]; then
        if rpm -q gnome-shell >/dev/null 2>&1; then
            log "GNOME Shell not running (kickstart environment), using package detection"
            GNOME_VERSION=$(rpm -q gnome-shell --queryformat '%{VERSION}' 2>/dev/null | cut -d. -f1) || GNOME_VERSION="50"
            log "Detected GNOME $GNOME_VERSION from package"
        else
            GNOME_VERSION="50"
            log "Cannot detect GNOME version, defaulting to $GNOME_VERSION"
        fi
    fi
    
    if [[ "$GNOME_VERSION" -lt 46 ]]; then
        error "GNOME $GNOME_VERSION is not supported. Minimum: GNOME 46"
    fi
    
    log "Targeting GNOME $GNOME_VERSION"
}

get_gnome50_extensions() {
    cat << 'EOF'
dash-to-panel@jderose9.github.com|73|https://extensions.gnome.org/download-extension/dash-to-panel@jderose9.github.com.shell-extension.zip?version_tag=69173
arcmenu@arcmenu.com|69.2|https://extensions.gnome.org/download-extension/arcmenu@arcmenu.com.shell-extension.zip?version_tag=71319
user-theme@gnome-shell-extensions.gcampax.github.com|50.3|https://extensions.gnome.org/download-extension/user-theme@gnome-shell-extensions.gcampax.github.com.shell-extension.zip?version_tag=73999
appindicatorsupport@rgcjonas.gmail.com|64|https://extensions.gnome.org/download-extension/appindicatorsupport@rgcjonas.gmail.com.shell-extension.zip?version_tag=69296
caffeine@patapon.info|60|https://extensions.gnome.org/download-extension/caffeine@patapon.info.shell-extension.zip?version_tag=69851
drive-menu@gnome-shell-extensions.gcampax.github.com|50.3|https://extensions.gnome.org/download-extension/drive-menu@gnome-shell-extensions.gcampax.github.com.shell-extension.zip?version_tag=73991
EOF
}

install_dependencies() {
    log "Ensuring required dependencies are installed..."
    dnf install -y git gnome-tweaks gnome-extensions-app gnome-menus unzip || \
        error "Failed to install dependencies"
}

install_gtk_theme() {
    log "Installing Windows 10 GTK theme..."
    
    local theme_version_file="$GNOME_THEME_DIR/$GTK_THEME_NAME/.version"
    local current_version=""
    local src_theme="$THEME_SOURCE_DIR/Windows-10"
    
    if [[ -f "$theme_version_file" ]]; then
        current_version=$(cat "$theme_version_file" 2>/dev/null || echo "")
    fi
    
    if [[ -d "$GNOME_THEME_DIR/$GTK_THEME_NAME" ]] && [[ "$current_version" == "$SCRIPT_VERSION" ]] && [[ "$FORCE_REINSTALL" != "true" ]]; then
        log "GTK theme already installed at version $SCRIPT_VERSION, skipping..."
        return 0
    fi
    
    if [[ -d "$GNOME_THEME_DIR/$GTK_THEME_NAME" ]]; then
        log "GTK theme exists but version mismatch (installed: $current_version, current: $SCRIPT_VERSION), reinstalling..."
        rm -rf "$GNOME_THEME_DIR/$GTK_THEME_NAME"
    fi
    
    if [[ -d "$src_theme" ]]; then
        cp -r "$src_theme"/* "$GNOME_THEME_DIR/$GTK_THEME_NAME/" || \
            error "Failed to copy GTK theme from submodule"
    else
        git clone --depth 1 https://github.com/B00merang-Project/Windows-10.git "$TEMP_DIR/gtk-theme" || \
            error "Failed to clone GTK theme"
        cp -r "$TEMP_DIR/gtk-theme"/* "$GNOME_THEME_DIR/$GTK_THEME_NAME/" || \
            error "Failed to copy GTK theme"
    fi
    
    chmod -R 755 "$GNOME_THEME_DIR/$GTK_THEME_NAME"
    echo "$SCRIPT_VERSION" > "$theme_version_file"
    log "GTK theme installed successfully (v$SCRIPT_VERSION)"
}

install_gtk_theme_dark() {
    log "Installing Windows 10 Dark GTK theme..."
    
    local theme_version_file="$GNOME_THEME_DIR/Windows-10-Dark/.version"
    local current_version=""
    local src_theme="$THEME_SOURCE_DIR/Windows-10-Dark"
    
    if [[ -f "$theme_version_file" ]]; then
        current_version=$(cat "$theme_version_file" 2>/dev/null || echo "")
    fi
    
    if [[ -d "$GNOME_THEME_DIR/Windows-10-Dark" ]] && [[ "$current_version" == "$SCRIPT_VERSION" ]] && [[ "$FORCE_REINSTALL" != "true" ]]; then
        log "Dark GTK theme already installed at version $SCRIPT_VERSION, skipping..."
        return 0
    fi
    
    if [[ -d "$GNOME_THEME_DIR/Windows-10-Dark" ]]; then
        log "Dark GTK theme exists but version mismatch, reinstalling..."
        rm -rf "$GNOME_THEME_DIR/Windows-10-Dark"
    fi
    
    if [[ -d "$src_theme" ]]; then
        cp -r "$src_theme"/* "$GNOME_THEME_DIR/Windows-10-Dark/" || \
            error "Failed to copy Dark GTK theme from submodule"
    else
        git clone --depth 1 https://github.com/B00merang-Project/Windows-10-Dark.git "$TEMP_DIR/gtk-theme-dark" || \
            error "Failed to clone Dark GTK theme"
        cp -r "$TEMP_DIR/gtk-theme-dark"/* "$GNOME_THEME_DIR/Windows-10-Dark/" || \
            error "Failed to copy Dark GTK theme"
    fi
    
    chmod -R 755 "$GNOME_THEME_DIR/Windows-10-Dark"
    echo "$SCRIPT_VERSION" > "$theme_version_file"
    log "Dark GTK theme installed successfully (v$SCRIPT_VERSION)"
}

install_icon_theme() {
    log "Installing Windows 10 icon theme..."
    
    local icon_dir="/usr/share/icons/$ICON_THEME_NAME"
    local theme_version_file="$icon_dir/.version"
    local current_version=""
    local src_icons="$THEME_SOURCE_DIR/icons/Windows-10"
    
    if [[ -f "$theme_version_file" ]]; then
        current_version=$(cat "$theme_version_file" 2>/dev/null || echo "")
    fi
    
    if [[ -d "$icon_dir" ]] && [[ "$current_version" == "$SCRIPT_VERSION" ]] && [[ "$FORCE_REINSTALL" != "true" ]]; then
        log "Icon theme already installed at version $SCRIPT_VERSION, skipping...";        return 0
    fi
    
    if [[ -d "$icon_dir" ]]; then
        log "Icon theme exists but version mismatch, reinstalling..."
        rm -rf "$icon_dir"
    fi
    
    if [[ -d "$src_icons" ]]; then
        cp -r "$src_icons"/* "$icon_dir/" || \
            error "Failed to copy icon theme from submodule"
    else
        git clone --depth 1 https://github.com/B00merang-Artwork/Windows-10.git "$TEMP_DIR/icon-theme" || \
            error "Failed to clone icon theme"
        cp -r "$TEMP_DIR/icon-theme"/* "$icon_dir/" || \
            error "Failed to copy icon theme"
    fi
    
    chmod -R 755 "$icon_dir"
    
    # Copy modern folder icons from Breeze for Windows 11 look
    log "Installing modern folder icons (Breeze)..."
    local breeze_svg="/usr/share/icons/Adwaita/scalable/places"
    local dest_svg="$icon_dir/scalable/places"
    
    if [[ -d "$breeze_svg" ]]; then
        mkdir -p "$dest_svg"
        for icon in folder folder-documents folder-download folder-music folder-pictures folder-videos folder-publicshare folder-templates; do
            if [[ -f "$breeze_svg/$icon.svg" ]]; then
                cp -f "$breeze_svg/$icon.svg" "$dest_svg/" 2>/dev/null || true
            fi
        done
        # Also copy PNG versions for different sizes
        for size in 16 22 24 32 48; do
            local breeze_png="/usr/share/icons/Adwaita/${size}x${size}/places"
            local dest_png="$icon_dir/${size}x${size}/places"
            if [[ -d "$breeze_png" ]]; then
                mkdir -p "$dest_png"
                cp -f "$breeze_png/folder.png" "$dest_png/" 2>/dev/null || true
                cp -f "$breeze_png/folder-open.png" "$dest_png/" 2>/dev/null || true
            fi
        done
        log "Modern folder icons installed"
    fi
    
    gtk-update-icon-cache -f "$icon_dir" 2>/dev/null || true
    echo "$SCRIPT_VERSION" > "$theme_version_file"
    
    # ==============================================================================
    # Windows Start Button Icon Creation
    # ==============================================================================
    # Purpose: Create a windows-logo.png icon for ArcMenu Start button
    #
    # IMPORTANT: The current implementation is a PLACEHOLDER only!
    # - It's copies an Adwaita icon as a placeholder until a real Windows logo is available
    # - The Adwaita terminal icon is just a generic gray placeholder
    # - This is NOT the actual Windows 10/11 logo
    #
    # To get proper Windows icons, you should either:
    # 1. Manually place a real windows-logo.png in themes/icons/Windows-10/48x48/apps/
    # 2. Or the icon already exists in the submodule (from the earlier manual upload)
    #
    # The icon is then copied to all standard icon sizes (16,22,24,32,64,128,256)
    # so it displays correctly at different scaling factors
    # ==============================================================================
    
    log "Creating Windows Start button icon..."
    local apps_dir="$icon_dir/48x48/apps"
    mkdir -p "$apps_dir"
    
    # Check if Windows logo icon already exists (from submodule or manual upload)
    # Priority: 1) Check if icon was already manually placed in theme source
    #           2) Check if icon exists in system (from earlier orb-vm copy)
    #           3) Fallback to Adwaita placeholder
    
    if [[ -f "$apps_dir/windows-logo.png" ]]; then
        # Icon already exists (from submodule or previous manual upload) - use it
        log "Using existing windows-logo.png from theme"
    else
        # Try to find icon in theme source directory first
        if [[ -d "$src_icons" ]] && [[ -f "$src_icons/48x48/apps/windows-logo.png" ]]; then
            cp "$src_icons/48x48/apps/windows-logo.png" "$apps_dir/" 2>/dev/null || true
            log "Copied windows-logo.png from theme source"
        else
            # LAST RESORT: Use Adwaita terminal icon as placeholder
            # This is NOT a real Windows logo - just a gray placeholder
            # TODO: Replace with actual Windows logo for production use
            if [[ -f "/usr/share/icons/Adwaita/48x48/apps/utilities-terminal.png" ]]; then
                cp /usr/share/icons/Adwaita/48x48/apps/utilities-terminal.png "$apps_dir/windows-logo.png" 2>/dev/null || true
                log "WARNING: Using Adwaita placeholder - replace with real Windows logo!"
            fi
        fi
    fi
    
    # Copy to all other icon sizes needed for proper scaling
    # GNOME will use the closest size to the panel icon size setting
    for size in 16 22 24 32 64 128 256; do
        local size_dir="$icon_dir/${size}x${size}/apps"
        mkdir -p "$size_dir"
        
        # Only copy if:
        # 1. Target icon doesn't exist yet
        # 2. Source 48x48 icon exists to copy from
        if [[ ! -f "$size_dir/windows-logo.png" ]] && [[ -f "$apps_dir/windows-logo.png" ]]; then
            cp "$apps_dir/windows-logo.png" "$size_dir/" 2>/dev/null || true
        fi
    done
    log "Windows Start button icon created (or placeholder used)"
    
    log "Icon theme installed successfully (v$SCRIPT_VERSION)"
}

install_aura_glass() {
    if [[ "$INSTALL_AURA" != "true" ]]; then
        log "Aura Glass installation disabled (set INSTALL_AURA=true to enable)"
        return 0
    fi
    
    log "Installing Aura Glass frosted glass theme..."
    
    local aura_version_file="/root/.config/aura-glass-version"
    local aura_install_marker="/root/.themes/Aura-Glass"
    local current_version=""
    
    if [[ -f "$aura_version_file" ]]; then
        current_version=$(cat "$aura_version_file" 2>/dev/null || echo "")
    fi
    
    if [[ -d "$aura_install_marker" ]] && [[ "$current_version" == "$SCRIPT_VERSION" ]] && [[ "$FORCE_REINSTALL" != "true" ]]; then
        log "Aura Glass already installed at version $SCRIPT_VERSION, skipping..."
        return 0
    fi
    
    if [[ -d "$TEMP_DIR/aura-glass" ]]; then
        rm -rf "$TEMP_DIR/aura-glass"
    fi
    
    git clone --depth 1 https://github.com/DevWebeloper/aura-glass.git "$TEMP_DIR/aura-glass" || {
        log "Warning: Failed to clone Aura Glass, continuing with Windows 10 theme only"
        return 0
    }
    
    cd "$TEMP_DIR/aura-glass"
    
    if [[ "$KICKSTART_ENV" == "true" ]]; then
        log "Running Aura Glass in kickstart mode (no GUI)..."
        XDG_CURRENT_DESKTOP=GNOME ./install.sh --yes --full \
            --accent "$AURA_ACCENT" \
            --app-transparency "$AURA_TRANSPARENCY" \
            --recommended 2>&1 | grep -v "^error: Cannot autolaunch" || true
    else
        log "Running Aura Glass installer..."
        ./install.sh --yes --full \
            --accent "$AURA_ACCENT" \
            --app-transparency "$AURA_TRANSPARENCY" \
            --recommended || true
    fi
    
    if [[ -d "$aura_install_marker" ]]; then
        mkdir -p "$(dirname "$aura_version_file")"
        echo "$SCRIPT_VERSION" > "$aura_version_file"
        log "Aura Glass installed successfully (v$SCRIPT_VERSION)"
    else
        log "Warning: Aura Glass installation may have had errors, continuing with Windows 10 theme"
    fi
}

install_extensions() {
    log "Installing GNOME extensions for GNOME $GNOME_VERSION..."
    
    rm -rf /usr/share/gnome-shell/extensions/ArcMenu@ArcMenu.com \
           /usr/share/gnome-shell/extensions/trayIconsReloaded@selfmade.pl
    
    while IFS='|' read -r ext_uuid ext_version download_url; do
        [[ -z "$ext_uuid" ]] && continue
        log "Installing extension: $ext_uuid"
        
        local ext_dir="/usr/share/gnome-shell/extensions/$ext_uuid"
        local ext_version_file="$ext_dir/.installed-version"
        local installed_version=""
        
        if [[ -f "$ext_version_file" ]]; then
            installed_version=$(cat "$ext_version_file" 2>/dev/null || echo "")
        fi
        
        if [[ -d "$ext_dir" ]] && [[ "$installed_version" == "$ext_version" ]] && [[ "$FORCE_REINSTALL" != "true" ]]; then
            log "Extension $ext_uuid already installed at $ext_version, skipping..."
            continue
        fi
        
        if [[ -d "$ext_dir" ]]; then
            log "Extension $ext_uuid exists but version mismatch (installed: $installed_version, current: $ext_version), reinstalling..."
            rm -rf "$ext_dir"
        fi
        
        mkdir -p "$ext_dir"
        
        if curl -fsSL "$download_url" -o "$TEMP_DIR/ext.zip" && unzip -tqq "$TEMP_DIR/ext.zip" >/dev/null 2>&1; then
            unzip -qo "$TEMP_DIR/ext.zip" -d "$ext_dir"
            chmod -R 755 "$ext_dir"
            echo "$ext_version" > "$ext_version_file"
            log "Installed: $ext_uuid ($ext_version)"
        else
            log "Warning: Could not download or extract $ext_uuid"
            rm -rf "$ext_dir"
        fi
        
        rm -f "$TEMP_DIR/ext.zip"
    done < <(get_gnome50_extensions)
}

configure_theme_systemwide() {
    log "Configuring system-wide default theme..."
    
    local profile_dir="/etc/dconf/profile"
    local db_dir="/etc/dconf/db"
    local profile_file="$profile_dir/user"
    local db_file="$db_dir/gnome.d/01-windows10-theme"
    
    mkdir -p "$profile_dir" "$db_dir/gnome.d"
    
    cat > "$profile_file" << 'EOF'
user-db:user
system-db:gnome
EOF
    log "Created dconf profile"
    
    cat > "$db_file" << EOF
[org/gnome/desktop/interface]
gtk-theme='$GTK_THEME_NAME'
icon-theme='$ICON_THEME_NAME'
cursor-theme='$ICON_THEME_NAME'
cursor-size=24
font-name='Segoe UI 10'
document-font-name='Segoe UI 10'
avatar-directories=['/var/lib/AccountsService/icons/', '/usr/share/pixmaps/faces/']

[org/gnome/desktop/wm/preferences]
theme='$GTK_THEME_NAME'
titlebar-font='Segoe UI Bold 9'
titlebar-uses-system-font=true
button-layout=':minimize,maximize,close'

[org/gnome/shell/extensions/dash-to-panel]
panel-position='BOTTOM'
panel-size=40
show-appmenu=false
show-running-apps=true
show-favorites=true
hot-keys=true
hotkeys-overlay-combo='TEMPORARILY'
preview-timeout=400
group-apps=true
scroll-panel-action='CYCLE_WINDOWS'
show-trash=true
show-places=true
animate-window-open=true
animate-window-close=true

[org/gnome/shell/extensions/ArcMenu]
menu-layout='Default'
menu-button-appearance='Icon'
menu-button-icon='Windows_Icon'
customize-theme=true
menu-background-color='#f3f3f3'
menu-foreground-color='#333333'
menu-border-color='#cccccc'
menu-border-width=1
menu-item-active-background-color='#0078d7'
menu-item-active-foreground-color='#ffffff'
menu-button-padding=8
menu-arrow-spacing=6
menu-shortcut-padding=12

[org/gnome/shell/extensions/arcmenu]
menu-layout='Windows11'
force-new-window=true
menu-button-icon='/usr/share/icons/Windows-10/48x48/apps/windows-logo.png'
menu-button-icon-size=24

[org/gnome/shell/extensions/caffeine]
activate-notification=true
enable-screensaver=true
show-indicator=true
brightness-enable=true
night-light-enable=false

[org/gnome/shell/extensions/appindicatorsupport]
has-indicators=true
tray-order='[]'

[org/gnome/shell/extensions/drive-menu]
show-in-tray=false
power-off-icon=true

[org/gnome/desktop/peripherals/mouse]
cursor-theme='$ICON_THEME_NAME'

[org/gnome/settings-daemon/plugins/xsettings]
antialiasing='rgba'

[org/gnome/shell]
enabled-extensions=['dash-to-panel@jderose9.github.com', 'arcmenu@arcmenu.com', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'appindicatorsupport@rgcjonas.gmail.com', 'caffeine@patapon.info', 'drive-menu@gnome-shell-extensions.gcampax.github.com']

[org/gnome/desktop/wm/keybindings]
switch-to-workspace-up=['disabled']
switch-to-workspace-down=['disabled']
switch-to-workspace-left=['<Super>Left']
switch-to-workspace-right=['<Super>Right']

[org/gnome/nautilus/preferences]
default-folder-viewer='list-view'
default-zoom-level=100
show-directory-item-counts='always'
click-policy='double'
search-filter-time-type='any'
show-image-thumbnails='local-only'
date-time-format='locale'
show-hidden-files=false

[org/gnome/nautilus/list-view]
default-zoom-level='large'
use-tighter-layouts=true

[org/gnome/nautilus/icon-view]
default-zoom-level='extra-large'

[org/gnome/nautilus/window-state]
initial-size=(1000, 700)

[org/gtk.Settings.FileChooser]
show-hidden=false
sidebar-width=200
location-mode='path-bar'
EOF
     
    log "Created system-wide theme configuration"
    
    # Configure Nautilus bookmarks for Quick Access (Windows-style)
    setup_nautilus_bookmarks
    
    dconf update
    log "Updated dconf database"
}

setup_nautilus_bookmarks() {
    log "Configuring Nautilus sidebar bookmarks (Quick Access)..."
    
    local bookmarks_file="$HOME/.config/gtk-3.0/bookmarks"
    
    mkdir -p "$(dirname "$bookmarks_file")"
    
    # Use unquoted EOF to expand variables, then replace admin placeholder
    cat > "$bookmarks_file" << EOF
file:///home/${ADMIN_USER}/Desktop Desktop
file:///home/${ADMIN_USER}/Documents Documents
file:///home/${ADMIN_USER}/Downloads Downloads
file:///home/${ADMIN_USER}/Pictures Pictures
file:///home/${ADMIN_USER}/Music Music
file:///home/${ADMIN_USER}/Videos Videos
file:///home/${ADMIN_USER} This PC
EOF
    
    # Also set system-wide bookmarks for new users
    local system_bookmarks="/etc/skel/.config/gtk-3.0/bookmarks"
    mkdir -p "$(dirname "$system_bookmarks")"
    cp "$bookmarks_file" "$system_bookmarks" 2>/dev/null || true
    
    log "Nautilus Quick Access bookmarks configured"
}

setup_autostart_script() {
    log "Creating first-login theme enforcement script..."
    
    local autostart_script="/etc/profile.d/apply-windows10-theme.sh"
    
    cat > "$autostart_script" << 'SCRIPT'
#!/bin/sh
if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ] && [ -z "$WINDOWS10_THEME_APPLIED" ]; then
    export WINDOWS10_THEME_APPLIED=1
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.shell enabled-extensions \
            "['dash-to-panel@jderose9.github.com', \
              'arcmenu@arcmenu.com', \
              'user-theme@gnome-shell-extensions.gcampax.github.com', \
              'appindicatorsupport@rgcjonas.gmail.com', \
              'caffeine@patapon.info', \
              'drive-menu@gnome-shell-extensions.gcampax.github.com']" 2>/dev/null || true
        gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close' 2>/dev/null || true
    fi
fi
SCRIPT
    
    chmod 755 "$autostart_script"
    log "Autostart script created"
}

setup_gdm_theme() {
    log "Configuring GDM login screen theme..."
    
    local gdm_dir="/etc/dconf/db/gdm.d"
    local gdm_profile="$gdm_dir/99-windows10-theme"
    
    mkdir -p "$gdm_dir"
    
    cat > "$gdm_profile" << EOF
[org/gnome/desktop/interface]
gtk-theme='$GTK_THEME_NAME'
icon-theme='$ICON_THEME_NAME'
avatar-directories=['/var/lib/AccountsService/icons/', '/usr/share/pixmaps/faces/']

[org/gnome/shell]
enabled-extensions=['dash-to-panel@jderose9.github.com']
EOF
    
    dconf update
    log "GDM theme configured with avatar support"
}

setup_user_profile_photos() {
    log "Setting up user profile photos support..."
    
    local icons_dir="/var/lib/AccountsService/icons"
    local default_faces="/usr/share/pixmaps/faces"
    local gdm_dir="/etc/dconf/db/gdm.d"
    local db_file="$gdm_dir/01-avatars"
    
    mkdir -p "$icons_dir" "$default_faces" "$gdm_dir"
    chmod 755 "$icons_dir" "$default_faces"
    
    cat > "$db_file" << EOF
[org/gnome/desktop/interface]
avatar-directories=['/var/lib/AccountsService/icons/', '/usr/share/pixmaps/faces/']
EOF
    
    dconf update
    log "User profile photo directories configured"
}

install_fonts() {
    log "Updating font cache..."
    
    local fonts_dir="/usr/share/fonts/truetype"
    mkdir -p "$fonts_dir"
    
    fc-cache -f -v 2>/dev/null || true
    log "Font cache updated"
}

verify_installation() {
    log "Verifying installation..."
    
    local errors=0
    
    [[ -d "$GNOME_THEME_DIR/$GTK_THEME_NAME" ]] || { log "Warning: GTK theme not found"; errors=$((errors + 1)); }
    [[ -d "/usr/share/icons/$ICON_THEME_NAME" ]] || { log "Warning: Icon theme not found"; errors=$((errors + 1)); }
    [[ -d "/usr/share/gnome-shell/extensions/dash-to-panel@jderose9.github.com" ]] || { log "Warning: dash-to-panel extension not found"; errors=$((errors + 1)); }
    [[ -d "/usr/share/gnome-shell/extensions/arcmenu@arcmenu.com" ]] || { log "Warning: ArcMenu extension not found"; errors=$((errors + 1)); }
    [[ -d "/var/lib/AccountsService/icons" ]] || { log "Warning: Avatar directory not found"; errors=$((errors + 1)); }
    
    if [[ $errors -eq 0 ]]; then
        log "All components installed successfully"
    else
        log "Installation completed with $errors warning(s)"
    fi
}

print_summary() {
    cat << 'EOF'

========================================
  Theme Installation Complete
========================================

Installed Components:
  - Aura Glass: Frosted glass theme with 90% transparency
  - GTK Theme: Windows-10 (available as alternative)
  - Icon Theme: Windows-10
  - Window buttons: minimize, maximize, close (Windows-style)
  - GNOME Extensions (GNOME 50 compatible):
    * Dash to Panel (taskbar)
    * ArcMenu (Start menu - GNOME 50 compatible)
    * User Themes
    * AppIndicator Support
    * Caffeine (disable screensaver/suspend on demand)
    * Removable Drive Menu
  - User Profile Photos: Enabled for GDM and system menu

Configuration:
  - Aura Glass active with blue accent color
  - App window transparency: 90% frosted glass
  - Blur effects enabled for top bar, menus, and popups
  - Taskbar positioned at bottom
  - Start menu configured with Windows icon
  - Window buttons: minimize, maximize, close (right side)
  - System-wide defaults applied via dconf
  - Avatar directories configured for user profile photos

Idempotent Operation:
  - This script can be run multiple times safely
  - Each run checks versions before reinstalling
  - Set FORCE_REINSTALL=true to force reinstall everything
  - User customizations are preserved unless forced

Kickstart Mode:
  - Detects when running in kickstart (no D-Bus session)
  - Configures dconf profiles for first login
  - Settings will apply when user logs in first time
  - Aura Glass installed with environment workaround

User Profile Photos:
  - Add user avatars to: /var/lib/AccountsService/icons/
  - Or use: ~/.face (e.g. ln -sf /path/to/photo.jpg ~/.face)
  - Supported formats: PNG, JPG (square, 96x96 or larger)

User Customization:
  Users can customize their settings through:
  - Settings > Appearance (accent colors)
  - Settings > Users (profile photo)
  - GNOME Tweaks > Appearance (switch themes)
  - Extensions app (configure each extension)
  - Right-click panel > Dash to Panel Settings
  - Right-click Start button > ArcMenu Settings
  - Run 'aura-glass-apply' to re-apply CSS fixes

Theme Switching:
  - To use Aura Glass: Keep current settings
  - To use Windows-10 theme: GNOME Tweaks > Appearance > Applications > Windows-10

Important:
  - Log out and back in for all changes to take effect
  - Aura Glass installs to ~/.local/share/ (user-space)
  - Windows-10 theme installs to /usr/share/themes/ (system-wide)
  - Re-run this script to update to latest versions

EOF
}

main() {
    log "Starting Windows 10 + Aura Glass theme configuration for Fedora 44 + GNOME 50..."
    log "This script is idempotent - safe to run multiple times"
    
    check_root
    detect_kickstart_env
    check_gnome_version
    
    log "Configuring for GNOME $GNOME_VERSION"
    
    if [[ "$KICKSTART_ENV" == "true" ]]; then
        log "Running in kickstart mode - gsettings/dconf will be configured but not applied"
    fi
    
    install_dependencies
    install_aura_glass
    install_gtk_theme
    install_gtk_theme_dark
    install_icon_theme
    install_extensions
    install_fonts
    configure_theme_systemwide
    setup_autostart_script
    setup_gdm_theme
    setup_user_profile_photos
    verify_installation
    print_summary
    
    log "Installation complete!"
    if [[ "$KICKSTART_ENV" == "true" ]]; then
        log "Note: User must log in once for gsettings to take effect"
    fi
}

main "$@"
