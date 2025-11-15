#!/bin/bash
###############################################################################
# Deploy DFIR Chaincode to Hot and Cold Blockchains
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${GREEN}=========================================="
echo "DFIR Chaincode Deployment"
echo -e "==========================================${NC}"
echo ""

CC_NAME="dfir"
CC_VERSION="1.0"
CC_SEQUENCE=1

# Step 1: Package Hot Blockchain Chaincode
echo -e "${YELLOW}[1/8] Packaging hot blockchain chaincode...${NC}"
docker exec cli peer lifecycle chaincode package /tmp/dfir-hot.tar.gz \
    --path /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode \
    --lang golang \
    --label dfir_hot_${CC_VERSION}
echo -e "${GREEN}✓ Hot chaincode packaged${NC}"
echo ""

# Step 2: Install on Law Enforcement Peer
echo -e "${YELLOW}[2/8] Installing on Law Enforcement peer...${NC}"
docker exec cli peer lifecycle chaincode install /tmp/dfir-hot.tar.gz
echo -e "${GREEN}✓ Installed on Law Enforcement${NC}"
echo ""

# Step 3: Install on Forensic Lab Peer
echo -e "${YELLOW}[3/8] Installing on Forensic Lab peer...${NC}"
docker exec \
    -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp \
    -e CORE_PEER_ADDRESS=peer0.forensiclab.hot.coc.com:8051 \
    -e CORE_PEER_LOCALMSPID=ForensicLabMSP \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt \
    cli peer lifecycle chaincode install /tmp/dfir-hot.tar.gz
echo -e "${GREEN}✓ Installed on Forensic Lab${NC}"
echo ""

# Step 4: Query Package ID
echo -e "${YELLOW}[4/8] Querying chaincode package ID...${NC}"
PACKAGE_ID=$(docker exec cli peer lifecycle chaincode queryinstalled | grep "dfir_hot_${CC_VERSION}" | awk '{print $3}' | sed 's/,$//')
echo "Package ID: $PACKAGE_ID"
echo ""

# Step 5: Approve for Law Enforcement
echo -e "${YELLOW}[5/8] Approving chaincode for Law Enforcement...${NC}"
docker exec cli peer lifecycle chaincode approveformyorg \
    -o orderer.hot.coc.com:7050 \
    --channelID hotchannel \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --package-id ${PACKAGE_ID} \
    --sequence ${CC_SEQUENCE} \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/ca.crt
echo -e "${GREEN}✓ Approved for Law Enforcement${NC}"
echo ""

# Step 6: Approve for Forensic Lab
echo -e "${YELLOW}[6/8] Approving chaincode for Forensic Lab...${NC}"
docker exec \
    -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp \
    -e CORE_PEER_ADDRESS=peer0.forensiclab.hot.coc.com:8051 \
    -e CORE_PEER_LOCALMSPID=ForensicLabMSP \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt \
    cli peer lifecycle chaincode approveformyorg \
    -o orderer.hot.coc.com:7050 \
    --channelID hotchannel \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --package-id ${PACKAGE_ID} \
    --sequence ${CC_SEQUENCE} \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/ca.crt
echo -e "${GREEN}✓ Approved for Forensic Lab${NC}"
echo ""

# Step 7: Check commit readiness
echo -e "${YELLOW}[7/8] Checking commit readiness...${NC}"
docker exec cli peer lifecycle chaincode checkcommitreadiness \
    --channelID hotchannel \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --sequence ${CC_SEQUENCE} \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/ca.crt
echo ""

# Step 8: Commit chaincode
echo -e "${YELLOW}[8/8] Committing chaincode to hot channel...${NC}"
docker exec cli peer lifecycle chaincode commit \
    -o orderer.hot.coc.com:7050 \
    --channelID hotchannel \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --sequence ${CC_SEQUENCE} \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/ca.crt \
    --peerAddresses peer0.lawenforcement.hot.coc.com:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/lawenforcement.hot.coc.com/peers/peer0.lawenforcement.hot.coc.com/tls/ca.crt \
    --peerAddresses peer0.forensiclab.hot.coc.com:8051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt
echo -e "${GREEN}✓ Chaincode committed${NC}"
echo ""

# Verify deployment
echo -e "${YELLOW}Verifying deployment...${NC}"
docker exec cli peer lifecycle chaincode querycommitted --channelID hotchannel
echo ""

echo -e "${GREEN}=========================================="
echo "✓ Hot Blockchain Chaincode Deployed!"
echo -e "==========================================${NC}"
echo ""
echo -e "${YELLOW}Next: Test transactions${NC}"
echo ""
