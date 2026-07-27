#!/bin/bash
set -euo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-F:/wwwroot}"
DEPLOY_URI="${DEPLOY_URI:-$DEPLOY_PATH}"

# Detect remote shell type
detect_remote_shell() {
    if ssh deploy "Get-Command powershell" 2>/dev/null; then
        echo "powershell"
    else
        echo "bash"
    fi
}

# Run command on remote, auto-detecting shell
remote_cmd() {
    local cmd="$1"
    local shell_type
    shell_type=$(detect_remote_shell)
    
    if [ "$shell_type" = "powershell" ]; then
        ssh deploy "powershell.exe -NoProfile -Command \"$cmd\"" || return $?
    else
        ssh deploy "$cmd" || return $?
    fi
}

# Create directory on remote, auto-detecting shell
remote_mkdir() {
    local path="$1"
    local shell_type
    shell_type=$(detect_remote_shell)
    
    if [ "$shell_type" = "powershell" ]; then
        ssh deploy "powershell.exe -NoProfile -Command \"New-Item -ItemType Directory -Force -Path '$path' | Out-Null\"" || {
            echo "ERROR: Failed to create directory: $path"
            return 1
        }
    else
        ssh deploy "mkdir -p '$path'" || {
            echo "ERROR: Failed to create directory: $path"
            return 1
        }
    fi
}

echo "Detecting remote environment..."
SHELL_TYPE=$(detect_remote_shell)
echo "Remote shell: $SHELL_TYPE"

echo "Creating directory structure..."
remote_mkdir "$DEPLOY_PATH"
remote_mkdir "$DEPLOY_PATH/kickstart"
remote_mkdir "$DEPLOY_PATH/ipxe"
remote_mkdir "$DEPLOY_PATH/fedora"

echo "Remote directories ready"