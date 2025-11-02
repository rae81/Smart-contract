#!/bin/bash
set -e

echo "======================================"
echo "Packaging Chaincode for Fabric"
echo "======================================"

CHAINCODE_NAME="dfir"
CHAINCODE_VERSION="1.0"
CHAINCODE_LABEL="${CHAINCODE_NAME}_${CHAINCODE_VERSION}"

cd "$(dirname "$0")/.."

echo ""
echo "Step 1: Check vendor directory..."
if [ ! -d "vendor" ]; then
    echo "Vendor directory not found. Running vendor script..."
    ./scripts/vendor-chaincode.sh
fi

echo "✓ Vendor directory exists"

echo ""
echo "Step 2: Verify peer CLI..."
if ! command -v peer &> /dev/null; then
    echo "✗ peer CLI not found"
    echo ""
    echo "Install Fabric peer CLI or ensure it's in PATH"
    exit 1
fi

echo "✓ peer CLI found: $(peer version | head -1)"

echo ""
echo "Step 3: Package chaincode..."
peer lifecycle chaincode package ${CHAINCODE_NAME}.tar.gz \
    --path . \
    --lang golang \
    --label ${CHAINCODE_LABEL}

if [ ! -f "${CHAINCODE_NAME}.tar.gz" ]; then
    echo "✗ Packaging failed"
    exit 1
fi

echo ""
echo "✓ Chaincode packaged successfully"
echo ""
echo "Package: $(pwd)/${CHAINCODE_NAME}.tar.gz"
echo "Size: $(du -h ${CHAINCODE_NAME}.tar.gz | cut -f1)"
echo ""
echo "Contents:"
tar -tzf ${CHAINCODE_NAME}.tar.gz | head -20
echo "..."
echo ""
echo "======================================"
echo "Package Ready for Deployment!"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. Install: peer lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz"
echo "  2. Approve: peer lifecycle chaincode approveformyorg ..."
echo "  3. Commit: peer lifecycle chaincode commit ..."
echo ""
echo "See docs/DEPLOYMENT.md for detailed instructions"
