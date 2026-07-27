#!/bin/bash
set -e

echo "=== Linting iPXE Scripts ==="
FAILED=0

for ipxe_file in *.ipxe; do
    if [ -f "$ipxe_file" ]; then
        echo "Linting: $ipxe_file"
        
        if ! head -1 "$ipxe_file" | grep -q '^#!ipxe'; then
            echo "  ERROR: Missing #!ipxe shebang"
            FAILED=1
        fi
        
        LABEL_COUNT=$(grep -c '^:' "$ipxe_file" 2>/dev/null || echo 0)
        if [ "$LABEL_COUNT" -eq 0 ]; then
            echo "  WARNING: No labels found"
        fi
        
        if ! grep -q 'menu ' "$ipxe_file"; then
            echo "  WARNING: No menu definition"
        fi
        
        if ! grep -q 'choose ' "$ipxe_file"; then
            echo "  WARNING: No choose command"
        fi
        
        if ! grep -q 'goto ' "$ipxe_file"; then
            echo "  WARNING: No goto statements"
        fi
        
        echo "  PASS: $ipxe_file"
    fi
done

if [ $FAILED -ne 0 ]; then
    echo "=== iPXE Linting FAILED ==="
    exit 1
fi

echo "=== All iPXE files passed ==="