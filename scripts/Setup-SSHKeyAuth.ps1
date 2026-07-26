#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures OpenSSH Server on Windows for key-based authentication
    
.DESCRIPTION
    This script:
    - Installs OpenSSH Server (if not present)
    - Creates a deployment user (if specified)
    - Configures SSH key-based authentication
    - Starts the SSH service
    - Configures Windows Firewall

.PARAMETER DeployUser
    Username for deployment user (default: deploy)

.PARAMETER PublicKeyPath
    Path to public key file to authorize (default: none - user must provide)

.PARAMETER ListenAddress
    IP address to listen on (default: 0.0.0.0)

.EXAMPLE
    # Basic setup with existing user
    .\Setup-SSHKeyAuth.ps1

.EXAMPLE
    # Create new deploy user with key
    .\Setup-SSHKeyAuth.ps1 -DeployUser "deploy" -PublicKeyPath "C:\keys\deploy.pub"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$DeployUser = "deploy",
    
    [Parameter(Mandatory=$false)]
    [string]$PublicKeyPath = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ListenAddress = "0.0.0.0",
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateUser,
    
    [Parameter(Mandatory=$false)]
    [switch]$AllowPasswordAuth
)

$ErrorActionPreference = "Stop"

Write-Host "=== OpenSSH Server Configuration ===" -ForegroundColor Cyan
Write-Host "Deploy User: $DeployUser"
Write-Host ""

# ==============================================================================
# 1. Install OpenSSH Server
# ==============================================================================
Write-Host "[1/7] Installing OpenSSH Server..." -ForegroundColor Yellow

$sshFeature = Get-WindowsOptionalFeature -Online -FeatureName "OpenSSH.Server" -ErrorAction SilentlyContinue

if ($sshFeature -and $sshFeature.State -ne "Enabled") {
    Write-Host "  Enabling OpenSSH Server..."
    Enable-WindowsOptionalFeature -Online -FeatureName "OpenSSH.Server" -NoRestart -WarningAction SilentlyContinue
} elseif (-not $sshFeature) {
    # Try installing via features on demand
    Write-Host "  Installing OpenSSH Server via Capabilities..."
    
    $sshCapabilities = Get-WindowsCapability -Online | Where-Object { $_.Name -like "*OpenSSH*" }
    
    if ($sshCapabilities | Where-Object { $_.Name -like "*Server*") {
        $sshCapabilities | Where-Object { $_.Name -like "*Server*" } | 
            Add-WindowsCapability -Online -WarningAction SilentlyContinue
    } else {
        Write-Host "  OpenSSH not available via capabilities, checking services..." -ForegroundColor Yellow
        
        # Check if sshd is already installed
        $sshdPath = "$env:ProgramFiles\OpenSSH\sshd.exe"
        if (-not (Test-Path $sshdPath)) {
            Write-Host "  ERROR: OpenSSH not found. Install from:" -ForegroundColor Red
            Write-Host "    - GitHub: https://github.com/PowerShell/Win32-OpenSSH" -ForegroundColor Gray
            Write-Host "    - Or: Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0" -ForegroundColor Gray
            exit 1
        }
    }
}

Write-Host "  OpenSSH Server installed" -ForegroundColor Green

# ==============================================================================
# 2. Create Deployment User (Optional)
# ==============================================================================
if ($CreateUser) {
    Write-Host "[2/7] Creating deployment user..." -ForegroundColor Yellow
    
    $existingUser = Get-LocalUser -Name $DeployUser -ErrorAction SilentlyContinue
    
    if (-not $existingUser) {
        Write-Host "  Creating user: $DeployUser"
        $password = Read-Host -AsSecureString "Enter password for $DeployUser (or press Enter for key-only)"
        
        if ($password -and $password.Length -gt 0) {
            New-LocalUser -Name $DeployUser -Password $password -Description "Deployment user for CI/CD" | Out-Null
        } else {
            # Create user without password (requires key auth)
            New-LocalUser -Name $DeployUser -NoPassword -Description "Deployment user for CI/CD" | Out-Null
        }
        
        # Add to administrators group
        Add-LocalGroupMember -Group "Administrators" -Member $DeployUser -ErrorAction SilentlyContinue
        Write-Host "  User created and added to Administrators" -ForegroundColor Green
    } else {
        Write-Host "  User '$DeployUser' already exists" -ForegroundColor Gray
    }
} else {
    # Verify user exists
    Write-Host "[2/7] Verifying user exists..." -ForegroundColor Yellow
    $existingUser = Get-LocalUser -Name $DeployUser -ErrorAction SilentlyContinue
    
    if (-not $existingUser) {
        Write-Host "  WARNING: User '$DeployUser' does not exist. Use -CreateUser to create." -ForegroundColor Yellow
    } else {
        Write-Host "  User verified: $DeployUser" -ForegroundColor Green
    }
}

# ==============================================================================
# 3. Configure SSH Directory
# ==============================================================================
Write-Host "[3/7] Configuring SSH directories..." -ForegroundColor Yellow

$sshDir = "C:\ProgramData\ssh"
$authorizedKeysFile = "$sshDir\administrators_authorized_keys"
$userHomeDir = "$env:SystemDrive\Users\$DeployUser"
$userSshDir = "$userHomeDir\.ssh"

# Create SSH directory
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

# Set proper permissions on ssh directory
$sshAcl = Get-Acl $sshDir
$sshAcl.SetAccessRuleProtection($true, $false)
$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$sshAcl.SetAccessRule($adminRule)
$sshAcl.SetAccessRule($systemRule)
Set-Acl -Path $sshDir -AclObject $sshAcl

Write-Host "  SSH directories configured" -ForegroundColor Green

# ==============================================================================
# 4. Add Public Key
# ==============================================================================
Write-Host "[4/7] Configuring authorized keys..." -ForegroundColor Yellow

if ($PublicKeyPath -and (Test-Path $PublicKeyPath)) {
    Write-Host "  Using public key from: $PublicKeyPath"
    $publicKey = Get-Content -Path $PublicKeyPath -Raw
} else {
    # Prompt for public key
    Write-Host "  No public key file provided."
    Write-Host "  Enter the public key content (paste and press Enter, then Ctrl+D):" -ForegroundColor Yellow
    $publicKey = Read-Host -Prompt "Public Key"
    
    if (-not $publicKey) {
        Write-Host "  WARNING: No public key configured. Key auth will not work." -ForegroundColor Yellow
        $publicKey = $null
    }
}

if ($publicKey) {
    # Add to administrators_authorized_keys (for Administrator)
    $publicKey | Out-File -FilePath $authorizedKeysFile -Encoding utf8 -Force
    
    # Set proper permissions on authorized_keys
    $akAcl = Get-Acl $authorizedKeysFile
    $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "Administrators", "FullControl", "None", "None", "Allow"
    )
    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "SYSTEM", "FullControl", "None", "None", "Allow"
)
    # Remove existing rules except inheritance
    $akAcl.Access | ForEach-Object { $akAcl.RemoveAccessRule($_) } | Out-Null
    $akAcl.SetAccessRuleProtection($false, $false)
    $akAcl.AddAccessRule($adminRule)
    $akAcl.AddAccessRule($systemRule)
    Set-Acl -Path $authorizedKeysFile -AclObject $akAcl
    
    # Also add for the deploy user if exists
    if ($existingUser) {
        $userSshDir = "$userHomeDir\.ssh"
        if (-not (Test-Path $userSshDir)) {
            New-Item -ItemType Directory -Path $userSshDir -Force | Out-Null
        }
        $publicKey | Out-File -FilePath "$userSshDir\authorized_keys" -Encoding utf8 -Force
        
        # Set permissions for user
        $userAcl = Get-Acl $userSshDir
        $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "$DeployUser", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $userAcl.SetAccessRule($userRule)
        Set-Acl -Path $userSshDir -AclObject $userAcl
    }
    
    Write-Host "  Public key configured" -ForegroundColor Green
} else {
    Write-Host "  No public key added (run again with -PublicKeyPath)" -ForegroundColor Yellow
}

# ==============================================================================
# 5. Configure sshd_config
# ==============================================================================
Write-Host "[5/7] Configuring sshd_config..." -ForegroundColor Yellow

$sshdConfig = "$sshDir\sshd_config"

# Create config if not exists
if (-not (Test-Path $sshdConfig)) {
    Copy-Item -Path "$env:ProgramFiles\OpenSSH\sshd_config_default" -Destination $sshdConfig -Force
}

# Backup existing config
$backupConfig = "$sshdConfig.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
Copy-Item -Path $sshdConfig -Destination $backupConfig -Force

# Read and modify config
$config = Get-Content -Path $sshdConfig -Raw

# Ensure key settings
$config = $config -replace '^#?PermitRootLogin.*', 'PermitRootLogin yes'
$config = $config -replace '^#?PubkeyAuthentication.*', 'PubkeyAuthentication yes'
$config = $config -replace '^#?PasswordAuthentication.*', "PasswordAuthentication $(if ($AllowPasswordAuth) { 'yes' } else { 'no' })"
$config = $config -replace '^#?PermitEmptyPasswords.*', 'PermitEmptyPasswords no'
$config = $config -replace '^#?ChallengeResponseAuthentication.*', 'ChallengeResponseAuthentication no'
$config = $config -replace '^#?Subsystem\s+sftp.*', '# Subsystem sftp removed - use internal-sftp'
$config = $config -replace '^#?ListenAddress.*', "ListenAddress $ListenAddress"

# Add Windows-specific settings
$config += @"

# Windows-specific settings
AcceptEnv LANG LC_*

# Override default of no subsystems
Subsystem sftp sftp-server.exe

# Logging
SyslogFacility AUTH
LogLevel INFO
"@

$config | Out-File -FilePath $sshdConfig -Encoding utf8 -Force

Write-Host "  sshd_config updated (backup: $backupConfig)" -ForegroundColor Green

# ==============================================================================
# 6. Start SSH Service
# ==============================================================================
Write-Host "[6/7] Starting SSH service..." -ForegroundColor Yellow

$sshService = Get-Service -Name "sshd" -ErrorAction SilentlyContinue

if (-not $sshService) {
    Write-Host "  ERROR: SSH service not found" -ForegroundColor Red
    exit 1
}

if ($sshService.Status -ne "Running") {
    # Generate host keys if needed
    $hostKeys = @(
        "ssh_host_rsa_key",
        "ssh_host_ecdsa_key", 
        "ssh_host_ed25519_key"
    )
    
    $keygenPath = "$env:ProgramFiles\OpenSSH\ssh-keygen.exe"
    
    foreach ($key in $hostKeys) {
        if (-not (Test-Path "$sshDir\$key")) {
            Write-Host "  Generating $key..."
            & $keygenPath -t $key.Replace("ssh_host_", "").Replace("_key", "") -f "$sshDir\$key" -N '""' -WarningAction SilentlyContinue 2>$null
        }
    }
    
    # Fix permissions on host keys
    & $keygenPath -A -d $sshDir 2>$null | Out-Null
    
    Write-Host "  Starting sshd service..."
    Start-Service -Name "sshd"
}

Set-Service -Name "sshd" -StartupType Automatic

Write-Host "  SSH service running" -ForegroundColor Green

# ==============================================================================
# 7. Configure Firewall
# ==============================================================================
Write-Host "[7/7] Configuring firewall..." -ForegroundColor Yellow

$firewallRule = Get-NetFirewallRule -DisplayName "OpenSSH Server" -ErrorAction SilentlyContinue

if (-not $firewallRule) {
    New-NetFirewallRule -DisplayName "OpenSSH Server" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 22 `
        -Action Allow `
        -Profile Any | Out-Null
    
    Write-Host "  Firewall rule created" -ForegroundColor Green
} else {
    Write-Host "  Firewall rule exists" -ForegroundColor Gray
}

# ==============================================================================
# Test SSH Connection
# ==============================================================================
Write-Host ""
Write-Host "=== Configuration Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "SSH Server is now configured:" -ForegroundColor Cyan
Write-Host "  - Service: sshd (running)"
Write-Host "  - Listen: $ListenAddress:22"
Write-Host "  - User: $DeployUser"
Write-Host "  - Auth: Public Key$(if ($AllowPasswordAuth) { ' + Password' } else { ' only' })"
Write-Host ""
Write-Host "Test connection:" -ForegroundColor Cyan
Write-Host "  ssh -i <private_key> $DeployUser@<server_ip>" -ForegroundColor Gray
Write-Host ""

# Show connection info
$ipAddresses = Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual, Dhcp | 
    Where-Object { $_.IPAddress -notlike "127.*" } | 
    Select-Object -ExpandProperty IPAddress

Write-Host "Server IP addresses:" -ForegroundColor Yellow
$ipAddresses | ForEach-Object { Write-Host "  - ssh://$_" -ForegroundColor Gray }

# Create quick connect script for user
$quickConnect = @"
# Quick SSH connect script
# Run this from your client machine

`$privateKey = "C:\path\to\your\private_key"
`$server = "$($ipAddresses[0])"
`$user = "$DeployUser"

ssh -i `$privateKey `$user@`$server
"@

$quickConnect | Out-File -FilePath "$env:TEMP\QuickConnect-SSH.ps1" -Encoding UTF8
Write-Host "Quick connect script: $env:TEMP\QuickConnect-SSH.ps1" -ForegroundColor Gray