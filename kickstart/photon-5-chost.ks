{
    "hostname": "photon",
    "password":
        {
            "crypted": true,
            "text": "$ADMIN_PASSWORD_HASHED"
        },
    "disk": "/dev/sda",
    "partitions": [
        {"mountpoint": "/", "size": 0, "filesystem": "xfs"},
        {"mountpoint": "/boot", "size": 128, "filesystem": "xfs"},
        {"mountpoint": "/root", "size": 128, "filesystem": "xfs"},
        {"size": 128, "filesystem": "swap"}
    ],
    "bootmode": "efi",
    "packages": [
        "minimal",
        "linux-esx",
        "initramfs",
        "sudo",
        "vim",
        "cloud-utils",
        "wget",
        "tar",
        "unzip",
        "logrotate",
        "openssl",
        "python3"
    ],
    "install_linux_esx" : true,
    "postinstall": [
        "#!/bin/sh",
        "useradd -m -p '${ADMIN_PASSWORD_HASHED}' -s /bin/bash ${ADMIN_USERNAME}",
        "usermod -aG sudo ${ADMIN_USERNAME}",
        "echo \"${ADMIN_USERNAME} ALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers.d/${ADMIN_USERNAME}",
        "chage -I -1 -m 0 -M 99999 -E -1 root",
        "chage -I -1 -m 0 -M 99999 -E -1 ${ADMIN_USERNAME}",
        "systemctl restart iptables",
        "sed -i 's/.*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config",
        "sed -i 's/.*MaxAuthTries.*/MaxAuthTries 10/g' /etc/ssh/sshd_config",
        "systemctl restart sshd.service"
    ],
    "linux_flavor": "linux-esx",
    "network": {
        "type": "dhcp"
    }
}