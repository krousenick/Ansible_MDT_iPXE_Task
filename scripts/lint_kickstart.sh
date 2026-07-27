#!/bin/bash
set -e

echo "=== Linting Kickstart Files ==="
FAILED=0

for ks_file in kickstart/*.ks; do
    if [ -f "$ks_file" ]; then
        echo "Validating: $ks_file"
        
        if ksvalidator "$ks_file"; then
            echo "  PASS: $ks_file"
        else
            echo "  FAIL: $ks_file validation failed"
            FAILED=1
        fi
    fi
done

if [ $FAILED -ne 0 ]; then
    echo "=== Kickstart Linting FAILED ==="
    exit 1
fi

echo "=== All kickstart files passed ==="