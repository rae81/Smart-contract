#!/bin/bash
###############################################################################
# Complete DFIR Chaincode Deployment for Both Blockchains
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd ~/Dual-hyperledger-Blockchain

echo -e "${GREEN}=========================================="
echo "Complete DFIR Chaincode Deployment"
echo -e "==========================================${NC}"
echo ""

###############################################################################
# HOT BLOCKCHAIN DEPLOYMENT
###############################################################################

echo -e "${YELLOW}=== HOT BLOCKCHAIN ===${NC}"
echo ""

# Package
echo -e "${YELLOW}[1/9] Packaging hot chaincode...${NC}"
docker exec cli peer lifecycle chaincode package /tmp/dfir-hot.tar.gz \
    --path /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode \
    --lang golang \
    --label dfir_1.0
echo -e "${GREEN}✓ Packaged${NC}"

# Install on Law Enforcement
echo -e "${YELLOW}[2/9] Installing on Law Enforcement...${NC}"
docker exec cli peer lifecycle chaincode install /tmp/dfir-hot.tar.gz
echo -e "${GREEN}✓ Installed${NC}"

# Install on Forensic Lab
echo -e "${YELLOW}[3/9] Installing on Forensic Lab...${NC}"
docker exec \
    -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp \
    -e CORE_PEER_ADDRESS=peer0.forensiclab.hot.coc.com:8051 \
    -e CORE_PEER_LOCALMSPID=ForensicLabMSP \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt \
    cli peer lifecycle chaincode install /tmp/dfir-hot.tar.gz
echo -e "${GREEN}✓ Installed${NC}"

# Get package ID
echo -e "${YELLOW}[4/9] Getting package ID...${NC}"
PACKAGE_ID=$(docker exec cli peer lifecycle chaincode queryinstalled | grep "dfir_1.0" | awk '{print $3}' | sed 's/,$//')
echo "Package ID: $PACKAGE_ID"

# Approve for Law Enforcement
echo -e "${YELLOW}[5/9] Approving for Law Enforcement...${NC}"
docker exec cli peer lifecycle chaincode approveformyorg \
    -o orderer.hot.coc.com:7050 \
    --channelID hotchannel \
    --name dfir \
    --version 1.0 \
    --package-id ${PACKAGE_ID} \
    --sequence 1 \
    --init-required=false \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/ca.crt \
    --waitForEvent
echo -e "${GREEN}✓ Approved${NC}"

# Approve for Forensic Lab
echo -e "${YELLOW}[6/9] Approving for Forensic Lab...${NC}"
docker exec \
    -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp \
    -e CORE_PEER_ADDRESS=peer0.forensiclab.hot.coc.com:8051 \
    -e CORE_PEER_LOCALMSPID=ForensicLabMSP \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt \
    cli peer lifecycle chaincode approveformyorg \
    -o orderer.hot.coc.com:7050 \
    --channelID hotchannel \
    --name dfir \
    --version 1.0 \
    --package-id ${PACKAGE_ID} \
    --sequence 1 \
    --init-required=false \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/ca.crt \
    --waitForEvent
echo -e "${GREEN}✓ Approved${NC}"

# Check readiness
echo -e "${YELLOW}[7/9] Checking commit readiness...${NC}"
docker exec cli peer lifecycle chaincode checkcommitreadiness \
    --channelID hotchannel \
    --name dfir \
    --version 1.0 \
    --sequence 1 \
    --init-required=false \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/ca.crt

# Commit
echo -e "${YELLOW}[8/9] Committing to hotchannel...${NC}"
docker exec cli peer lifecycle chaincode commit \
    -o orderer.hot.coc.com:7050 \
    --channelID hotchannel \
    --name dfir \
    --version 1.0 \
    --sequence 1 \
    --init-required=false \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/ca.crt \
    --peerAddresses peer0.lawenforcement.hot.coc.com:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/lawenforcement.hot.coc.com/peers/peer0.lawenforcement.hot.coc.com/tls/ca.crt \
    --peerAddresses peer0.forensiclab.hot.coc.com:8051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt \
    --waitForEvent
echo -e "${GREEN}✓ Committed${NC}"

# Verify
echo -e "${YELLOW}[9/9] Verifying hot chaincode...${NC}"
docker exec cli peer lifecycle chaincode querycommitted --channelID hotchannel --name dfir
echo ""

echo -e "${GREEN}✓ Hot Blockchain Chaincode Deployed!${NC}"
echo ""

###############################################################################
# COLD BLOCKCHAIN DEPLOYMENT
###############################################################################

echo -e "${YELLOW}=== COLD BLOCKCHAIN ===${NC}"
echo ""

# Package
echo -e "${YELLOW}[1/5] Packaging cold chaincode...${NC}"
docker exec cli-cold peer lifecycle chaincode package /tmp/audit.tar.gz \
    --path /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode \
    --lang golang \
    --label audit_1.0
echo -e "${GREEN}✓ Packaged${NC}"

# Install on Auditor
echo -e "${YELLOW}[2/5] Installing on Auditor...${NC}"
docker exec cli-cold peer lifecycle chaincode install /tmp/audit.tar.gz
echo -e "${GREEN}✓ Installed${NC}"

# Get package ID
echo -e "${YELLOW}[3/5] Getting package ID...${NC}"
PACKAGE_ID_COLD=$(docker exec cli-cold peer lifecycle chaincode queryinstalled | grep "audit_1.0" | awk '{print $3}' | sed 's/,$//')
echo "Package ID: $PACKAGE_ID_COLD"

# Approve for Auditor
echo -e "${YELLOW}[4/5] Approving for Auditor...${NC}"
docker exec cli-cold peer lifecycle chaincode approveformyorg \
    -o orderer.cold.coc.com:7150 \
    --channelID coldchannel \
    --name audit \
    --version 1.0 \
    --package-id ${PACKAGE_ID_COLD} \
    --sequence 1 \
    --init-required=false \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/ca.crt \
    --waitForEvent
echo -e "${GREEN}✓ Approved${NC}"

# Commit
echo -e "${YELLOW}[5/5] Committing to coldchannel...${NC}"
docker exec cli-cold peer lifecycle chaincode commit \
    -o orderer.cold.coc.com:7150 \
    --channelID coldchannel \
    --name audit \
    --version 1.0 \
    --sequence 1 \
    --init-required=false \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/ca.crt \
    --peerAddresses peer0.auditor.cold.coc.com:9051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/auditor.cold.coc.com/peers/peer0.auditor.cold.coc.com/tls/ca.crt \
    --waitForEvent
echo -e "${GREEN}✓ Committed${NC}"

# Verify
docker exec cli-cold peer lifecycle chaincode querycommitted --channelID coldchannel --name audit
echo ""

echo -e "${GREEN}=========================================="
echo "✓ All Chaincodes Deployed Successfully!"
echo -e "==========================================${NC}"
echo ""
echo -e "${YELLOW}Next: Test transactions${NC}"
echo ""
