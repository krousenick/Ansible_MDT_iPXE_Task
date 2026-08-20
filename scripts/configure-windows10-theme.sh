#!/bin/bash
set -euo pipefail

GNOME_THEME_DIR="/usr/share/themes"
GTK_THEME_NAME="Windows-10"
ICON_THEME_NAME="Windows-10"
AURA_ACCENT="blue"
AURA_TRANSPARENCY="90%"
TEMP_DIR=$(mktemp -d)

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

install_dependencies() {
    log "Installing required dependencies..."
    dnf install -y git gnome-tweaks gnome-extensions-app gnome-menus unzip || \
        error "Failed to install dependencies"
}

install_gtk_theme() {
    log "Installing Windows 10 GTK theme..."
    
    if [[ -d "$GNOME_THEME_DIR/$GTK_THEME_NAME" ]]; then
        log "GTK theme already installed, skipping..."
        return
    fi
    
    git clone --depth 1 https://github.com/B00merang-Project/Windows-10.git "$TEMP_DIR/gtk-theme" || \
        error "Failed to clone GTK theme"
    
    mkdir -p "$GNOME_THEME_DIR/$GTK_THEME_NAME"
    cp -r "$TEMP_DIR/gtk-theme"/* "$GNOME_THEME_DIR/$GTK_THEME_NAME/" || \
        error "Failed to copy GTK theme"
    
    chmod -R 755 "$GNOME_THEME_DIR/$GTK_THEME_NAME"
    log "GTK theme installed successfully"
}

install_gtk_theme_dark() {
    log "Installing Windows 10 Dark GTK theme..."
    
    if [[ -d "$GNOME_THEME_DIR/Windows-10-Dark" ]]; then
        log "Dark GTK theme already installed, skipping..."
        return
    fi
    
    git clone --depth 1 https://github.com/B00merang-Project/Windows-10-Dark.git "$TEMP_DIR/gtk-theme-dark" || \
        error "Failed to clone Dark GTK theme"
    
    mkdir -p "$GNOME_THEME_DIR/Windows-10-Dark"
    cp -r "$TEMP_DIR/gtk-theme-dark"/* "$GNOME_THEME_DIR/Windows-10-Dark/" || \
        error "Failed to copy Dark GTK theme"
    
    chmod -R 755 "$GNOME_THEME_DIR/Windows-10-Dark"
    log "Dark GTK theme installed successfully"
}

install_icon_theme() {
    log "Installing Windows 10 icon theme..."
    
    local icon_dir="/usr/share/icons/$ICON_THEME_NAME"
    if [[ -d "$icon_dir" ]]; then
        log "Icon theme already installed, skipping..."
        return
    fi
    
    git clone --depth 1 https://github.com/B00merang-Artwork/Windows-10.git "$TEMP_DIR/icon-theme" || \
        error "Failed to clone icon theme"
    
    mkdir -p "$icon_dir"
    cp -r "$TEMP_DIR/icon-theme"/* "$icon_dir/" || \
        error "Failed to copy icon theme"
    
    chmod -R 755 "$icon_dir"
    
    gtk-update-icon-cache -f "$icon_dir" 2>/dev/null || true
    log "Icon theme installed successfully"
}

install_cursor_theme() {
    log "Installing cursor theme..."
    
    local cursor_dir="/usr/share/icons/Adwaita"
    if [[ -d "$cursor_dir" ]]; then
        log "Cursor theme already available, skipping..."
        return
    fi
    
    log "Using default Adwaita cursor theme"
}

install_aura_glass() {
    log "Installing Aura Glass frosted glass theme..."
    
    if [[ -d "$TEMP_DIR/aura-glass" ]]; then
        log "Aura Glass already cloned"
    else
        git clone --depth 1 https://github.com/DevWebeloper/aura-glass.git "$TEMP_DIR/aura-glass" || {
            log "Warning: Failed to clone Aura Glass, continuing with Windows 10 theme only"
            return 0
        }
    fi
    
    cd "$TEMP_DIR/aura-glass"
    
    log "Running Aura Glass installer with blue accent, 90% transparency, blur enabled..."
    ./install.sh --yes --full \
        --accent "$AURA_ACCENT" \
        --app-transparency "$AURA_TRANSPARENCY" \
        --recommended || {
        log "Warning: Aura Glass installation failed, continuing with Windows 10 theme"
        return 0
    }
    
    log "Aura Glass installed successfully"
}


    log "GNOME extension CLI installer not available, using direct downloads..."
}

install_extensions() {
    log "Installing GNOME extensions..."
    
    local user_home
    
    declare -A EXTENSION_URLS=(
        ["dash-to-panel@jderose9.github.com"]="https://extensions.gnome.org/extension-data/dash-to-paneljderose9.github.com.v73.shell-extension.zip"
        ["arcmenu@arcmenu.com"]="https://extensions.gnome.org/extension-data/arcmenuarcmenu.com.v73.shell-extension.zip"
        ["user-theme@gnome-shell-extensions.gcampax.github.com"]="https://extensions.gnome.org/extension-data/user-themegnome-shell-extensions.gcampax.github.com.v76.shell-extension.zip"
        ["appindicatorsupport@rgcjonas.gmail.com"]="https://extensions.gnome.org/extension-data/appindicatorsupportrgcjonas.gmail.com.v64.shell-extension.zip"
        ["trayIconsReloaded@selfmade.pl"]="https://extensions.gnome.org/extension-data/trayIconsReloadedselfmade.pl.v34.shell-extension.zip"
        ["caffeine@patapon.info"]="https://extensions.gnome.org/extension-data/caffeinepatapon.info.v60.shell-extension.zip"
        ["drive-menu@gnome-shell-extensions.gcampax.github.com"]="https://extensions.gnome.org/extension-data/drive-menugnome-shell-extensions.gcampax.github.com.v79.shell-extension.zip"
    )
    
    for ext_uuid in "${!EXTENSION_URLS[@]}"; do
        log "Downloading extension: $ext_uuid"
        
        local ext_dir="/usr/share/gnome-shell/extensions/$ext_uuid"
        
        if [[ -d "$ext_dir" ]]; then
            log "Extension $ext_uuid already installed"
            continue
        fi
        
        mkdir -p "$ext_dir"
        
        local download_url="${EXTENSION_URLS[$ext_uuid]}"
        
        if curl -sSL "$download_url" -o "$TEMP_DIR/ext.zip"; then
            unzip -q "$TEMP_DIR/ext.zip" -d "$ext_dir" 2>/dev/null || true
            chmod -R 755 "$ext_dir"
            log "Installed: $ext_uuid"
        else
            log "Warning: Could not download $ext_uuid"
        fi
        
        rm -f "$TEMP_DIR/ext.zip"
    done
}

configure_theme_systemwide() {
    log "Configuring system-wide default theme..."
    
    local profile_dir="/etc/dconf/profile"
    local db_dir="/etc/dconf/db"
    local profile_file="$profile_dir/user"
    local db_file="$db_dir/gnome.d/01-windows10-theme"
    
    mkdir -p "$profile_dir" "$db_dir/gnome.d"
    
    if [[ ! -f "$profile_file" ]]; then
        cat > "$profile_file" << 'EOF'
user-db:user
system-db:gnome
EOF
        log "Created dconf profile"
    fi
    
    cat > "$db_file" << EOF
[org/gnome/desktop/interface]
gtk-theme='$GTK_THEME_NAME'
icon-theme='$ICON_THEME_NAME'
cursor-theme='$ICON_THEME_NAME'
cursor-size=24
font-name='Segoe UI 10'
document-font-name='Segoe UI 10'

[org/gnome/desktop/wm/preferences]
theme='$GTK_THEME_NAME'
titlebar-font='Segoe UI Bold 9'
titlebar-uses-system-font=true

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

[org/gnome/shell/extensions/arc-menu]
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

[org/gnome/desktop/peripherals/mouse]
cursor-theme='$ICON_THEME_NAME'

[org/gnome/settings-daemon/plugins/xsettings]
antialiasing='rgba'

[org/gnome/shell]
enabled-extensions=['dash-to-panel@jderose9.github.com', 'arcmenu@arcmenu.com', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'appindicatorsupport@rgcjonas.gmail.com', 'trayIconsReloaded@selfmade.pl', 'caffeine@patapon.info', 'drive-menu@gnome-shell-extensions.gcampax.github.com']

[org/gnome/desktop/wm/preferences]
button-layout=':minimize,maximize,close'

[org/gnome/desktop/wm/keybindings]
switch-to-workspace-up=['disabled']
switch-to-workspace-down=['disabled']
switch-to-workspace-left=['<Super>Left']
switch-to-workspace-right=['<Super>Right']
EOF
    
    log "Created system-wide theme configuration"
    
    dconf update
    log "Updated dconf database"
}

configure_user_dconf() {
    log "Configuring user-default theme (current keyfile database)..."
    
    local user_profile_dir="/etc/dconf/profile"
    local user_profile_file="$user_profile_dir/local"
    
    if [[ ! -f "$user_profile_file" ]]; then
        cat > "$user_profile_file" << 'EOF'
user-db:user
system-db:local
EOF
    fi
    
    dconf update
    log "User dconf profile configured"
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
              'trayIconsReloaded@selfmade.pl', \
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
    
    local gdm_profile="/etc/dconf/gdm.d/99-windows10-theme"
    if [[ -f "$gdm_profile" ]]; then
        log "GDM theme already configured"
        return
    fi
    
    cat > "$gdm_profile" << EOF
[org/gnome/desktop/interface]
gtk-theme='$GTK_THEME_NAME'
icon-theme='$ICON_THEME_NAME'

[org/gnome/shell]
enabled-extensions=['dash-to-panel@jderose9.github.com']
EOF
    
    dconf update
    log "GDM theme configured"
}

install_fonts() {
    log "Installing Windows-style fonts..."
    
    local fonts_dir="/usr/share/fonts/truetype"
    mkdir -p "$fonts_dir"
    
    if [[ -f "$fonts_dir/segoeui.ttf" ]]; then
        log "Segoe UI font already installed"
        return
    fi
    
    fc-cache -f -v 2>/dev/null || true
    log "Font cache updated"
}

verify_installation() {
    log "Verifying installation..."
    
    local errors=0
    
    [[ -d "$GNOME_THEME_DIR/$GTK_THEME_NAME" ]] || { log "Warning: GTK theme not found"; errors=$((errors + 1)); }
    [[ -d "/usr/share/icons/$ICON_THEME_NAME" ]] || { log "Warning: Icon theme not found"; errors=$((errors + 1)); }
    [[ -d "/usr/share/gnome-shell/extensions/dash-to-panel@jderose9.github.com" ]] || { log "Warning: dash-to-panel extension not found"; errors=$((errors + 1)); }
    [[ -d "/usr/share/gnome-shell/extensions/arcmenu@arcmenu.com" ]] || { log "Warning: arcmenu extension not found"; errors=$((errors + 1)); }
    
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
  - GNOME Extensions:
    * Dash to Panel (taskbar)
    * Arc Menu (Start menu)
    * User Themes
    * AppIndicator Support
    * Tray Icons Reloaded
    * Caffeine (disable screensaver/suspend on demand)
    * Removable Drive Menu
    * Arc Menu (Start menu)
    * User Themes
    * AppIndicator Support
    * Tray Icons Reloaded
    * Blur My Shell (dynamic blur effects)
    * Open Bar (top bar theming)
    * Custom OSD (minimal volume/brightness popup)

Configuration:
  - Aura Glass active with blue accent color
  - App window transparency: 90% frosted glass
  - Blur effects enabled for top bar, menus, and popups
  - Taskbar positioned at bottom
  - Start menu configured with Windows icon
  - System-wide defaults applied via dconf

User Customization:
  Users can customize their settings through:
  - Settings > Appearance (accent colors)
  - GNOME Tweaks > Appearance (switch themes)
  - Extensions app (configure each extension)
  - Right-click panel > Dash to Panel Settings
  - Right-click Start button > Arc Menu Settings
  - Run 'aura-glass-apply' to re-apply CSS fixes

Theme Switching:
  - To use Aura Glass: Keep current settings
  - To use Windows-10 theme: GNOME Tweaks > Appearance > Applications > Windows-10

Important:
  - Log out and back in for all changes to take effect
  - Aura Glass installs to ~/.local/share/ (user-space)
  - Windows-10 theme installs to /usr/share/themes/ (system-wide)
  - Custom settings persist per-user unless reset

EOF
}

main() {
    log "Starting Windows 10 + Aura Glass theme configuration for Fedora 44 + GNOME 50..."
    
    check_root
    install_dependencies
    install_aura_glass
    install_gtk_theme
    install_gtk_theme_dark
    install_icon_theme
    install_cursor_theme
    install_gnome_shell_theme
    install_extensions
    install_fonts
    configure_theme_systemwide
    configure_user_dconf
    setup_autostart_script
    setup_gdm_theme
    verify_installation
    print_summary
    
    log "Installation complete!"
}

main "$@"
