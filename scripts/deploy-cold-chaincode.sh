#!/bin/bash
###############################################################################
# Deploy Audit Chaincode to Cold Blockchain
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${GREEN}=========================================="
echo "Cold Blockchain Chaincode Deployment"
echo -e "==========================================${NC}"
echo ""

CC_NAME="audit"
CC_VERSION="1.0"
CC_SEQUENCE=1

# Step 1: Package Cold Blockchain Chaincode
echo -e "${YELLOW}[1/5] Packaging cold blockchain chaincode...${NC}"
docker exec cli-cold peer lifecycle chaincode package /tmp/audit-cold.tar.gz \
    --path /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode \
    --lang golang \
    --label audit_cold_${CC_VERSION}
echo -e "${GREEN}✓ Cold chaincode packaged${NC}"
echo ""

# Step 2: Install on Auditor Peer
echo -e "${YELLOW}[2/5] Installing on Auditor peer...${NC}"
docker exec cli-cold peer lifecycle chaincode install /tmp/audit-cold.tar.gz
echo -e "${GREEN}✓ Installed on Auditor${NC}"
echo ""

# Step 3: Query Package ID
echo -e "${YELLOW}[3/5] Querying chaincode package ID...${NC}"
PACKAGE_ID=$(docker exec cli-cold peer lifecycle chaincode queryinstalled | grep "audit_cold_${CC_VERSION}" | awk '{print $3}' | sed 's/,$//')
echo "Package ID: $PACKAGE_ID"
echo ""

# Step 4: Approve for Auditor
echo -e "${YELLOW}[4/5] Approving chaincode for Auditor...${NC}"
docker exec cli-cold peer lifecycle chaincode approveformyorg \
    -o orderer.cold.coc.com:7150 \
    --channelID coldchannel \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --package-id ${PACKAGE_ID} \
    --sequence ${CC_SEQUENCE} \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/ca.crt
echo -e "${GREEN}✓ Approved for Auditor${NC}"
echo ""

# Step 5: Commit chaincode
echo -e "${YELLOW}[5/5] Committing chaincode to cold channel...${NC}"
docker exec cli-cold peer lifecycle chaincode commit \
    -o orderer.cold.coc.com:7150 \
    --channelID coldchannel \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --sequence ${CC_SEQUENCE} \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/ca.crt \
    --peerAddresses peer0.auditor.cold.coc.com:9051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/auditor.cold.coc.com/peers/peer0.auditor.cold.coc.com/tls/ca.crt
echo -e "${GREEN}✓ Chaincode committed${NC}"
echo ""

# Verify deployment
echo -e "${YELLOW}Verifying deployment...${NC}"
docker exec cli-cold peer lifecycle chaincode querycommitted --channelID coldchannel
echo ""

echo -e "${GREEN}=========================================="
echo "✓ Cold Blockchain Chaincode Deployed!"
echo -e "==========================================${NC}"
echo ""
