#!/usr/bin/env python3
"""Hash passwords for kickstart deployment using SHA512."""

import subprocess
import os
import secrets


def hash_password(password):
    """Hash password using SHA512 via openssl."""
    result = subprocess.run(
        ['openssl', 'passwd', '-6', '-stdin'],
        input=password.encode(),
        capture_output=True,
        check=True
    )
    return result.stdout.decode().strip()


def main():
    if os.environ.get('ADMIN_PASSWORD_PLAINTEXT'):
        hashed = hash_password(os.environ['ADMIN_PASSWORD_PLAINTEXT'])
        with open('/tmp/admin_pass.env', 'w') as f:
            f.write(f'ADMIN_PASSWORD_HASHED={hashed}\n')
        print('Admin password hashed')
    
    if os.environ.get('GRUB_PASSWORD_PLAINTEXT'):
        hashed = hash_password(os.environ['GRUB_PASSWORD_PLAINTEXT'])
        with open('/tmp/grub_pass.env', 'w') as f:
            f.write(f'GRUB_PASSWORD_HASHED={hashed}\n')
        print('GRUB password hashed')


if __name__ == '__main__':
    main()