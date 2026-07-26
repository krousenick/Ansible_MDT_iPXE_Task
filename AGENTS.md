# AGENTS.md - Development Guidelines

This repository contains **iPXE boot scripts** (.ipxe) and **Kickstart files** (.ks) for network PXE boot and automated OS installations.

## 1. Build/Lint/Test Commands

### No Build System
This is a configuration repository with no build commands, linters, or unit tests.

### Manual Validation
- **iPXE Scripts**: Test on VM or test hardware with iPXE boot; review syntax manually
- **Kickstart Files**: Validate with `ksvalidator`:
  ```bash
  dnf install pykickstart
  ksvalidator kickstart/rhel-10-fips.ks
  ```

---

## 2. Code Style Guidelines

### iPXE Scripts (.ipxe)

#### Structure
```
#!ipxe

:start
menu MenuTitle
item --gap Section Header
item item_name  Description
choose --timeout ${timeout} --default ${menu} menu || goto fallback
goto ${menu}

:item_name
# commands
goto start

:fallback
echo Error occurred
prompt
goto start
```

#### Naming Conventions
- **Labels**: lowercase with underscores (e.g., `:change_menu`, `:utils_exit`)
- **Variables**: lowercase (e.g., `set boot_url`, `set arch:x86_64`)
- **Menu items**: descriptive names (e.g., `local`, `reboot`)

#### Formatting
- 2-4 spaces indentation (consistent within file)
- Blank lines between logical sections
- Use `--gap` for menu section headers
- Comments prefixed with `#`

#### Best Practices
- Use hex encoding: `set cls:hex 1b:5b:4a`
- Chain conditional assignments: `iseq ${netX/gateway} x && set var value || set var value`
- Variable expansion: `${variable}` syntax

#### Error Handling
- Add fallbacks: `|| goto error`
- Provide feedback: `echo` before destructive operations
- Use `prompt` for confirmations

---

### Kickstart Files (.ks)

#### Section Order
1. License/header comments
2. Language/Keyboard
3. Network configuration
4. Root/user setup
5. Security (firewall, SELinux)
6. Bootloader
7. Partitioning
8. Package selection (`%packages`)
9. Addons (`%addon`)
10. Post-install (`%post`)

#### Naming Conventions
- **Comments**: Full sentences with periods
- **Variables**: Uppercase (e.g., `$ADMIN_PASSWORD_HASHED`)
- **Partitions**: Descriptive (e.g., `pv.01`, `lv_root`)

#### Formatting
- 4-space indentation
- Blank lines between sections
- Inline comments for complex options
- Wrap long lines at ~80-100 characters

#### Security
- Use hashed passwords: `$6$salt$hash...`
- Lock root: `rootpw --lock`
- Enable firewall: `firewall --enabled --ssh`
- Configure SELinux: `selinux --permissive`

#### Partitioning Pattern
```kickstart
part /boot       --fstype=xfs  --size=512    --label=BOOTFS
part /boot/efi   --fstype=efi  --size=50     --label=EFIFS
part pv.01                               --size=100  --grow
volgroup sysvg --pesize=4096 pv.01
logvol /         --fstype=xfs  --name=lv_root  --vgname=sysvg --size=12288 --grow
```

#### Post-Installation (%post)
- Use HEREDOCs for scripts
- Log changes: `--log=/root/ks-post.log`

---

## 3. Version Control

### Commit Messages
- Prefix with file type: `[ipxe]`, `[kickstart]`, `[ks]`
- Example: `[ipxe] Add utility menu option`

### Branch Strategy
- Descriptive names: `feature/add-windows-boot`

---

## 4. Common Patterns

### Gateway Detection
```ipxe
iseq ${netX/gateway} 10.0.103.1 && set boot_url http://netboot.krouse.io || \
iseq ${netX/gateway} 10.3.0.1 && set boot_url http://kro-dct-netboot.krouse.io
```

### Architecture Detection
```ipxe
cpuid --ext 29 && set arch x86_64 || set arch aarch64
```

### WDS Boot
```ipxe
set wdsserver:ipv4 10.3.0.9
set netX/next-server ${wdsserver}
chain tftp://${wdsserver}/Boot\x64\wdsmgfw.efi
```

---

## 5. Important Notes

- **Production Impact**: Changes affect boot processes - always test first
- **Passwords**: Never commit plain-text passwords; use hashed versions
- **Network Config**: URLs and IPs are environment-specific
- **Ansible**: Files may be templated by Ansible playbooks

---

## 6. Reference

- iPXE: https://ipxe.org/scripting
- Kickstart: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/performing_an_advanced_rhel_9_installation/kickstart_references