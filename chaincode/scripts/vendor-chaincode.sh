#!/bin/bash
set -e

echo "======================================"
echo "Vendoring Chaincode Dependencies"
echo "======================================"

cd "$(dirname "$0")/.."

echo ""
echo "Step 1: Initialize Go module..."
if [ ! -f "go.mod" ]; then
    go mod init github.com/rae81/Smart-contract/chaincode
fi

echo ""
echo "Step 2: Download dependencies..."
go mod download
go mod tidy

echo ""
echo "Step 3: Vendor all dependencies..."
go mod vendor

if [ ! -d "vendor" ]; then
    echo "✗ Vendor directory not created"
    exit 1
fi

echo ""
echo "✓ Dependencies vendored successfully"
echo ""
echo "Vendor directory size: $(du -sh vendor/ | cut -f1)"
echo ""
echo "Key vendored packages:"
ls vendor/github.com/hyperledger/ 2>/dev/null || echo "  - Fabric packages"
echo ""
echo "======================================"
echo "Vendoring Complete!"
echo "======================================"
echo ""
echo "All dependencies are now in ./vendor/"
echo "Chaincode can be deployed offline to Fabric network"
