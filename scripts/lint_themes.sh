#!/bin/bash
set -euo pipefail

THEME_DIR="${1:-.}"

echo "Linting GTK themes in $THEME_DIR..."

check_index_theme() {
    local theme_path="$1"
    if [ -f "$theme_path/index.theme" ]; then
        echo "  [OK] index.theme exists"
        if grep -q "^Name=" "$theme_path/index.theme"; then
            echo "  [OK] Name defined in index.theme"
        else
            echo "  [ERROR] Name missing in index.theme"
            return 1
        fi
    else
        echo "  [ERROR] index.theme missing"
        return 1
    fi
}

check_css_files() {
    local theme_path="$1"
    local found=0
    
    for css_dir in gtk-3.0 gtk-4.0 gtk-3.20; do
        if [ -d "$theme_path/$css_dir" ]; then
            found=1
            echo "  [OK] $css_dir directory exists"
            if [ -f "$theme_path/$css_dir/gtk.css" ]; then
                echo "    [OK] gtk.css exists"
            fi
        fi
    done
    
    if [ "$found" -eq 0 ]; then
        echo "  [ERROR] No GTK3/4 CSS directories found"
        return 1
    fi
}

check_gnome_shell() {
    local theme_path="$1"
    if [ -d "$theme_path/gnome-shell" ]; then
        echo "  [OK] gnome-shell directory exists"
        if [ -f "$theme_path/gnome-shell/gnome-shell.css" ]; then
            echo "    [OK] gnome-shell.css exists"
        fi
    fi
}

lint_theme() {
    local theme_path="$1"
    local theme_name
    theme_name=$(basename "$theme_path")
    
    echo ""
    echo "=== Linting: $theme_name ==="
    
    if [ ! -d "$theme_path" ]; then
        echo "[ERROR] Theme directory not found: $theme_path"
        return 1
    fi
    
    check_index_theme "$theme_path"
    check_css_files "$theme_path"
    check_gnome_shell "$theme_path"
    
    echo "[PASS] $theme_name validated successfully"
}

if [ -d "$THEME_DIR/themes" ]; then
    for theme in "$THEME_DIR/themes"/*; do
        if [ -d "$theme" ]; then
            lint_theme "$theme"
        fi
    done
else
    lint_theme "$THEME_DIR"
fi

echo ""
echo "=== All themes validated ==="