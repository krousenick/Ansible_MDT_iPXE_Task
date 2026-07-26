#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures IIS server for iPXE network boot and kickstart installations
    
.DESCRIPTION
    This script:
    - Installs IIS and required features
    - Creates directory structure for netboot files
    - Configures MIME types for PXE boot files
    - Sets up DHCP options (optional)
    - Creates firewall rules
    - Configures directory browsing and default documents
    
.EXAMPLE
    .\Setup-IISServer.ps1 -NetbootPath "F:\wwwroot" -EnableDHCP
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$NetbootPath = "F:\wwwroot",
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableDHCP,
    
    [Parameter(Mandatory=$false)]
    [string]$DHCP_server = "10.3.0.5",
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableTFTP
)

$ErrorActionPreference = "Stop"

Write-Host "=== IIS Netboot Server Configuration ===" -ForegroundColor Cyan
Write-Host "Netboot Path: $NetbootPath"
Write-Host ""

# ==============================================================================
# 1. Install IIS and required Windows Features
# ==============================================================================
Write-Host "[1/8] Installing IIS and required features..." -ForegroundColor Yellow

$features = @(
    "IIS-WebServer",
    "IIS-WebServerManagementTools",
    "IIS-ManagementScriptingTools",
    "IIS-DefaultDocument",
    "IIS-DirectoryBrowsing",
    "IIS-HttpCompressionStatic",
    "IIS-HttpCompressionDynamic"
)

foreach ($feature in $features) {
    $featureState = Get-WindowsOptionalFeature -Online -FeatureName $feature
    if ($featureState.State -ne "Enabled") {
        Write-Host "  Enabling: $feature"
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -WarningAction SilentlyContinue | Out-Null
    }
}

# Install IIS via DISM if not present
$dismCheck = Get-WindowsOptionalFeature -Online -FeatureName IIS-WebServer
if ($dismCheck.State -ne "Enabled") {
    Write-Host "  Installing IIS via DISM..."
    DISM /Online /Enable-Feature /FeatureName:IIS /All /Source:$(Get-WindowsImage -Online | Select-Object -First 1).ImagePath 2>$null || true
}

Write-Host "  IIS installed successfully" -ForegroundColor Green

# ==============================================================================
# 2. Create Directory Structure
# ==============================================================================
Write-Host "[2/8] Creating directory structure..." -ForegroundColor Yellow

$directories = @(
    $NetbootPath,
    "$NetbootPath\kickstart",
    "$NetbootPath\fedora\44\x86_64\iso",
    "$NetbootPath\fedora\latest",
    "$NetbootPath\rhel\9\x86_64\iso",
    "$NetbootPath\rhel\10\x86_64\iso",
    "$NetbootPath\photon\5"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  Created: $dir"
    }
}

# Create URLRewrite rules folder
$rewritePath = "$env:SystemRoot\inetpub\wwwroot\app_data\rewrite"
if (-not (Test-Path $rewritePath)) {
    New-Item -ItemType Directory -Path $rewritePath -Force | Out-Null
}

Write-Host "  Directories created" -ForegroundColor Green

# ==============================================================================
# 3. Configure MIME Types
# ==============================================================================
Write-Host "[3/8] Configuring MIME types..." -ForegroundColor Yellow

# Get IIS MIME types configuration
$mimeTypes = @(
    ".ipxe",    "text/plain",
    ".ks",      "text/plain",
    ".vmlinuz", "application/octet-stream",
    ".initrd",  "application/octet-stream", 
    ".iso",     "application/octet-stream",
    ".img",     "application/octet-stream",
    ".efi",     "application/x-ndpi",
    ".xml",     "application/xml",
    ".json",    "application/json",
    ".gz",      "application/gzip",
    ".xz",      "application/x-xz"
)

# Add MIME types via appcmd
$mimeMap = Get-WebConfigurationProperty -Filter "system.webServer/staticContent" -Name "." 2>$null

foreach ($ext in $mimeTypes[0..($mimeTypes.Length-1)] by 2) {
    $mimeType = $mimeTypes[$mimeTypes.IndexOf($ext) + 1]
    $existing = Get-WebConfigurationProperty -Filter "system.webServer/staticContent/mimeMap" -Name "." -ErrorAction SilentlyContinue | 
        Where-Object { $_.fileExtension -eq $ext }
    
    if (-not $existing) {
        Write-Host "  Adding MIME type: $ext -> $mimeType"
        Add-WebConfigurationProperty -Filter "system.webServer/staticContent" -Name "." -Value @{fileExtension=$ext; mimeType=$mimeType}
    }
}

Write-Host "  MIME types configured" -ForegroundColor Green

# ==============================================================================
# 4. Configure IIS Website
# ==============================================================================
Write-Host "[4/8] Configuring IIS website..." -ForegroundColor Yellow

$siteName = "Default Web Site"
$appPool = "NetbootAppPool"

# Create Application Pool with appropriate settings
if (-not (Get-WebAppPoolState -Name $appPool -ErrorAction SilentlyContinue)) {
    New-WebAppPool -Name $appPool
    Set-ItemProperty "IIS:\AppPools\$appPool" -Name processModel.identityType -Value NetworkService
    Set-ItemProperty "IIS:\AppPools\$appPool" -Name enable32BitAppOnWin64 -Value "True"
    Write-Host "  Created Application Pool: $appPool"
}

# Set up the root virtual directory
$rootPath = $env:InetPub + "\wwwroot"

# Enable directory browsing
Set-WebConfigurationProperty -Filter "system.webServer/directoryBrowse" -Name enabled -Value "True"

# Set default documents
Add-WebConfiguration -Filter "system.webServer/defaultDocument" -Name "files" -Value @{value="index.html"} -ErrorAction SilentlyContinue

# Set HTTP headers forPXE boot
Set-WebConfigurationProperty -Filter "system.webServer/httpProtocol" -Name "customHeaders" -Value @{name="X-UA-Compatible";value="IE=Edge"}

Write-Host "  IIS website configured" -ForegroundColor Green

# ==============================================================================
# 5. Set Permissions
# ==============================================================================
Write-Host "[5/8] Setting permissions..." -ForegroundColor Yellow

# Get IIS_IUSRS group
$iisUsers = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-568")
$acls = @(
    @{Path=$rootPath; User="IIS_IUSRS"; Rights="ReadAndExecute"},
    @{Path=$rootPath; User="IIS_IUSRS"; Rights="Modify"},
    @{Path=$NetbootPath; User="IIS_IUSRS"; Rights="ReadAndExecute"},
    @{Path=$NetbootPath; User="IIS_IUSRS"; Rights="Modify"}
)

foreach ($acl in $acls) {
    $aclObj = Get-Acl -Path $acl.Path -ErrorAction SilentlyContinue
    if ($aclObj) {
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $acl.User,
            $acl.Rights,
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )
        $aclObj.SetAccessRule($accessRule)
        Set-Acl -Path $acl.Path -AclObject $aclObj
    }
}

# Ensure IUSR can read files
icacrl "$rootPath\*" /grant "IUSR:(R)" 2>$null
icacrl "$NetbootPath\*" /grant "IUSR:(R)" 2>$null

Write-Host "  Permissions set" -ForegroundColor Green

# ==============================================================================
# 6. Configure Firewall Rules
# ==============================================================================
Write-Host "[6/8] Configuring firewall rules..." -ForegroundColor Yellow

$firewallRules = @(
    @{Name="IIS HTTP"; Port=80; Protocol="TCP"},
    @{Name="IIS HTTPS"; Port=443; Protocol="TCP"}
)

foreach ($rule in $firewallRules) {
    $existing = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound -Protocol $rule.Protocol -LocalPort $rule.Port -Action Allow -Profile Any | Out-Null
        Write-Host "  Created firewall rule: $($rule.Name) (port $($rule.Port))"
    }
}

Write-Host "  Firewall rules configured" -ForegroundColor Green

# ==============================================================================
# 7. TFTP Configuration (Optional)
# ==============================================================================
if ($EnableTFTP) {
    Write-Host "[7/8] Configuring TFTP..." -ForegroundColor Yellow
    
    # Install TFTP server feature if available
    $tftpFeature = Get-WindowsOptionalFeature -Online -FeatureName "TFTP-Server" -ErrorAction SilentlyContinue
    if ($tftpFeature -and $tftpFeature.State -ne "Enabled") {
        Enable-WindowsOptionalFeature -Online -FeatureName "TFTP-Server" -NoRestart -WarningAction SilentlyContinue
    }
    
    # Create TFTP root
    $tftpRoot = "$NetbootPath\tftp"
    if (-not (Test-Path $tftpRoot)) {
        New-Item -ItemType Directory -Path $tftpRoot -Force | Out-Null
    }
    
    # Note: TFTP requires additional configuration for write access
    Write-Host "  TFTP root created at: $tftpRoot" -ForegroundColor Green
    Write-Host "  Note: Configure TFTP security separately for write access" -ForegroundColor Yellow
} else {
    Write-Host "[7/8] Skipping TFTP configuration" -ForegroundColor Gray
}

# ==============================================================================
# 8. DHCP Options (Optional)
# ==============================================================================
if ($EnableDHCP) {
    Write-Host "[8/8] Configuring DHCP options..." -ForegroundColor Yellow
    
    # Note: DHCP server configuration requires Server Manager or netsh
    # This sets up recommended options for PXE boot
    
    Write-Host "  DHCP Configuration Notes:" -ForegroundColor Yellow
    Write-Host "    Option 066 (Boot Server Host Name): $DHCP_server" -ForegroundColor Gray
    Write-Host "    Option 067 (Bootfile Name): boot\x64\wdsmgfw.efi" -ForegroundColor Gray
    Write-Host "    Option 017 (Domain Name): krouse.local" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Configure DHCP via Server Manager or:" -ForegroundColor Yellow
    Write-Host "    netsh dhcp server add optiondef 066 String" -ForegroundColor Gray
    Write-Host "    netsh dhcp server set value 066 1 $DHCP_server" -ForegroundColor Gray
    
    $dhcpScript = @"
# Run as Administrator to apply DHCP options
# Configure DHCP Options for PXE Boot

`$dhcpServer = "$DHCP_server"

# Option 066 - Boot Server Host Name
netsh dhcp server add optiondef 066 "Boot Server Host Name" String 
netsh dhcp server set value 066 1 `$dhcpServer

# Option 067 - Bootfile Name (iPXE)
netsh dhcp server add optiondef 067 "Bootfile Name" String
netsh dhcp server set value 067 1 "http://`$dhcpServer/menu.ipxe"

# Option 060 - PXE Client (Optional)
netsh dhcp server add optiondef 060 "PXE Client" String
netsh dhcp server set value 060 1 "PXEClient"
"@
    
    $dhcpScript | Out-File -FilePath "$env:TEMP\Configure-DHCP-PXE.ps1" -Encoding UTF8
    Write-Host "  DHCP script saved to: $env:TEMP\Configure-DHCP-PXE.ps1" -ForegroundColor Gray
} else {
    Write-Host "[8/8] Skipping DHCP configuration" -ForegroundColor Gray
}

# ==============================================================================
# Summary
# ==============================================================================
Write-Host ""
Write-Host "=== Configuration Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "IIS is now configured for netboot:" -ForegroundColor Cyan
Write-Host "  - Web Root: $rootPath"
Write-Host "  - Netboot Path: $NetbootPath"
Write-Host "  - Kickstart URL: http://<server>/kickstart/"
Write-Host "  - iPXE Menu: http://<server>/menu.ipxe"
Write-Host ""
Write-Host "Test with:" -ForegroundColor Cyan
Write-Host "  Invoke-WebRequest -Uri 'http://localhost/menu.ipxe'" -ForegroundColor Gray
Write-Host "  Invoke-WebRequest -Uri 'http://localhost/kickstart/rhel-10-fips.ks'" -ForegroundColor Gray
Write-Host ""

# Start IIS if not running
$site = Get-Website -Name "Default Web Site"
if ($site.State -ne "Started") {
    Write-Host "Starting IIS..." -ForegroundColor Yellow
    Start-Website -Name "Default Web Site"
}

Write-Host "Done!" -ForegroundColor Green