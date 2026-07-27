#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures OpenSSH Server on Windows for key-based authentication
    
.PARAMETER DeployUser
    Username for deployment user (default: deploy)
    
.EXAMPLE
    .\Setup-SSHKeyAuth.ps1 -DeployUser "deploy" -PublicKeyPath "C:\keys\deploy.pub" -CreateUser
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$DeployUser = "deploy",
    
    [Parameter(Mandatory=$false)]
    [string]$PublicKeyPath = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateUser = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$AllowPasswordAuth
)

$ErrorActionPreference = "Stop"

Write-Output "=== OpenSSH Server Configuration ==="

# 1. Install OpenSSH Server
Write-Output "[1/6] Installing OpenSSH Server..."

$sshService = Get-Service -Name "sshd" -ErrorAction SilentlyContinue

if (-not $sshService) {
    Write-Output "  Installing OpenSSH Server..."
    
    try {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop
    } catch {
        Write-Output "  Trying Windows optional feature..."
        Enable-WindowsOptionalFeature -Online -FeatureName OpenSSH.Server -NoRestart -WarningAction SilentlyContinue
    }
}

Write-Output "  OpenSSH Server installed"

# 2. Create Deployment User (Optional)
if ($CreateUser) {
    Write-Output "[2/6] Creating deployment user..."
    
    $existingUser = Get-LocalUser -Name $DeployUser -ErrorAction SilentlyContinue
    
    if (-not $existingUser) {
        Write-Output "  Creating user: $DeployUser"
        $password = Read-Host -AsSecureString "Enter password for $DeployUser"
        
        New-LocalUser -Name $DeployUser -Password $password -Description "Deployment user" | Out-Null
        Add-LocalGroupMember -Group "Administrators" -Member $DeployUser -ErrorAction SilentlyContinue
        Write-Output "  User created"
    } else {
        Write-Output "  User already exists"
    }
} else {
    Write-Output "[2/6] Skipping user creation"
}

# 3. Setup SSH Directories
Write-Output "[3/6] Configuring SSH directories..."

$sshDir = "C:\ProgramData\ssh"
$authorizedKeys = "$sshDir\administrators_authorized_keys"

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

# 4. Configure Public Key
Write-Output "[4/6] Configuring authorized keys..."

if ($PublicKeyPath -and (Test-Path $PublicKeyPath)) {
    $publicKey = Get-Content -Path $PublicKeyPath -Raw
    $publicKey | Out-File -FilePath $authorizedKeys -Encoding utf8 -Force
    
    # Set correct permissions using icacls
    icacls $authorizedKeys /inheritance:r | Out-Null
    icacls $authorizedKeys /grant "Administrators:F" | Out-Null
    icacls $authorizedKeys /grant "SYSTEM:F" | Out-Null
    
    Write-Output "  Public key configured"
}

# 5. Configure sshd_config
Write-Output "[5/6] Configuring sshd_config..."

$sshdConfig = "$sshDir\sshd_config"

$configContent = @"
PasswordAuthentication $(-not $AllowPasswordAuth)
PubkeyAuthentication yes
PermitRootLogin yes
Subsystem sftp sftp-server.exe
"@

$configContent | Out-File -FilePath $sshdConfig -Encoding utf8 -Force

# 6. Start SSH Service
Write-Output "[6/6] Starting SSH service..."

Start-Service -Name "sshd" -ErrorAction SilentlyContinue
Set-Service -Name "sshd" -StartupType Automatic

# Configure firewall
New-NetFirewallRule -DisplayName "OpenSSH Server" -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow -ErrorAction SilentlyContinue | Out-Null

Write-Output "=== Done ==="
Write-Output "SSH service running on port 22"
Write-Output "Test: ssh $DeployUser@$(hostname)"