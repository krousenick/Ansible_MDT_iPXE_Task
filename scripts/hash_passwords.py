#!/usr/bin/env python3
"""Hash passwords for kickstart deployment."""

import crypt
import secrets
import os
import sys


def hash_password(password):
    salt = secrets.token_hex(8)
    return crypt.crypt(password, crypt.mksalt(crypt.METHOD_SHA512, salt=salt.encode()))


def main():
    if os.environ.get('ADMIN_PASSWORD_PLAINTEXT'):
        hashed = hash_password(os.environ['ADMIN_PASSWORD_PLAINTEXT'])
        with open('/tmp/admin_pass.env', 'w') as f:
            f.write(f'ADMIN_PASSWORD_HASHED={hashed}\n')
    
    if os.environ.get('GRUB_PASSWORD_PLAINTEXT'):
        hashed = hash_password(os.environ['GRUB_PASSWORD_PLAINTEXT'])
        with open('/tmp/grub_pass.env', 'w') as f:
            f.write(f'GRUB_PASSWORD_HASHED={hashed}\n')


if __name__ == '__main__':
    main()