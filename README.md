# Ansible MDT iPXE Task

Network PXE boot and automated OS installation infrastructure using iPXE and Kickstart.

## Overview

This repository contains:
- **iPXE boot scripts** (.ipxe) - Network boot menus for PXE booting
- **Kickstart files** (.ks) - Automated OS installation configs
- **GitLab CI** - Automated linting and deployment to IIS server
- **PowerShell scripts** - Server setup automation

## Directory Structure

```
.
├── *.ipxe                    # iPXE boot scripts
├── kickstart/                # Kickstart files
│   ├── rhel-9-fips.ks       # RHEL 9 FIPS
│   ├── rhel-10-fips.ks      # RHEL 10 FIPS
│   ├── rhel-10-fips-gui.ks  # RHEL 10 Gaming/FIPS
│   └── fedora-44-gaming.ks  # Fedora 44 Gaming Edition
├── scripts/                  # Setup scripts
│   ├── Setup-IISServer.ps1
│   └── Setup-SSHKeyAuth.ps1
├── .gitlab-ci.yml           # CI/CD pipeline
└── AGENTS.md               # Development guidelines
```

## iPXE Boot Scripts

| File | Description |
|------|-------------|
| `menu.ipxe` | Main boot menu |
| `linux.ipxe` | Linux installer selection |
| `microsoft.ipxe` | Windows boot options |
| `hypervisor.ipxe` | Hypervisor installations |
| `utils.ipxe` | Utility tools |

## Kickstart Files

### RHEL 10 Gaming (rhel-10-fips-gui.ks)
- FIPS enabled
- NVIDIA/CUDA drivers
- Wine, Steam, Lutris, gamescope
- Gaming tuned profile
- STIG compliance
- Bazzite-style gaming configuration

### Fedora 44 Gaming (fedora-44-gaming.ks)
- COPR repos (ublue-os/bazzite)
- Steam/Lutris/MangoHUD
- PipeWire audio
- GPU overclocking tools
- Distrobox support

## CI/CD Pipeline

### Jobs
- `ipxe-lint` - Validate iPXE syntax
- `kickstart-lint` - Validate kickstart files with ksvalidator
- `deploy-staging` - Deploy to staging (manual)
- `deploy-production` - Deploy to production (on tag)
- `download-fedora-iso` - Download and extract Fedora ISO

### Required GitLab CI Variables
```
# SSH (staging)
STAGING_SSH_HOST
STAGING_SSH_USER
STAGING_SSH_KEY

# SSH (production)
PROD_SSH_HOST
PROD_SSH_USER
PROD_SSH_KEY

# Passwords (will be hashed at deploy time)
ADMIN_PASSWORD_PLAINTEXT
GRUB_PASSWORD_PLAINTEXT
```

## Server Setup

### IIS Server
Run on your Windows server:
```powershell
.\scripts\Setup-IISServer.ps1 -NetbootPath "F:\wwwroot"
```

### SSH Key Authentication
```powershell
.\scripts\Setup-SSHKeyAuth.ps1 -DeployUser "deploy" -PublicKeyPath "C:\keys\deploy.pub" -CreateUser
```

## Usage

1. **Configure IIS server** using `Setup-IISServer.ps1`
2. **Set up SSH** using `Setup-SSHKeyAuth.ps1`
3. **Configure GitLab CI variables** for your deployment server
4. **Deploy** via GitLab CI manual jobs or tag push

## Testing

### Validate Kickstart
```bash
dnf install pykickstart
ksvalidator kickstart/rhel-10-fips-gui.ks
```

### Test iPXE
Use a VM with iPXE or test hardware. Key files:
- `${boot_url}/menu.ipxe` - Main menu
- `${boot_url}/kickstart/rhel-10-fips-gui.ks` - Kickstart URL in boot config

## Notes

- Passwords are hashed with SHA512 at deploy time (never commit plaintext)
- Changes to boot files affect production - always test first
- ISOs must be extracted to `${boot_url}/<os>/<version>/x86_64/iso/`

## License

See individual files for license information. All code is provided "AS IS" without warranty.