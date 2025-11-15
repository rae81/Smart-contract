#!/bin/bash
###############################################################################
# Approve and Commit Already-Installed Chaincode
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd ~/Dual-hyperledger-Blockchain

echo -e "${GREEN}==========================================="
echo "Approve and Commit Chaincode"
echo -e "===========================================${NC}"
echo ""

###############################################################################
# HOT BLOCKCHAIN
###############################################################################

echo -e "${YELLOW}=== HOT BLOCKCHAIN ===${NC}"
echo ""

# Get package ID
echo -e "${YELLOW}[1/7] Getting package ID...${NC}"
PACKAGE_ID=$(docker exec cli peer lifecycle chaincode queryinstalled | grep "dfir_1.0" | awk '{print $3}' | sed 's/,$//')
echo "Package ID: $PACKAGE_ID"

# Approve for Law Enforcement
echo -e "${YELLOW}[2/7] Approving for Law Enforcement...${NC}"
docker exec cli peer lifecycle chaincode approveformyorg \
    -o orderer.hot.coc.com:7050 \
    --channelID hotchannel \
    --name dfir \
    --version 1.0 \
    --package-id ${PACKAGE_ID} \
    --sequence 1 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem
echo -e "${GREEN}✓ Approved for Law Enforcement${NC}"

# Approve for Forensic Lab
echo -e "${YELLOW}[3/7] Approving for Forensic Lab...${NC}"
docker exec \
    -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp \
    -e CORE_PEER_ADDRESS=peer0.forensiclab.hot.coc.com:8051 \
    -e CORE_PEER_LOCALMSPID=ForensicLabMSP \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt \
    cli peer lifecycle chaincode approveformyorg \
    -o orderer.hot.coc.com:7050 \
    --channelID hotchannel \
    --name dfir \
    --version 1.0 \
    --package-id ${PACKAGE_ID} \
    --sequence 1 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem
echo -e "${GREEN}✓ Approved for Forensic Lab${NC}"

# Check readiness
echo -e "${YELLOW}[4/7] Checking commit readiness...${NC}"
docker exec cli peer lifecycle chaincode checkcommitreadiness \
    --channelID hotchannel \
    --name dfir \
    --version 1.0 \
    --sequence 1 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem

# Commit
echo -e "${YELLOW}[5/7] Committing to hotchannel...${NC}"
docker exec cli peer lifecycle chaincode commit \
    -o orderer.hot.coc.com:7050 \
    --channelID hotchannel \
    --name dfir \
    --version 1.0 \
    --sequence 1 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem \
    --peerAddresses peer0.lawenforcement.hot.coc.com:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/lawenforcement.hot.coc.com/peers/peer0.lawenforcement.hot.coc.com/tls/ca.crt \
    --peerAddresses peer0.forensiclab.hot.coc.com:8051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt
echo -e "${GREEN}✓ Committed${NC}"

# Verify
echo -e "${YELLOW}[6/7] Verifying hot chaincode...${NC}"
docker exec cli peer lifecycle chaincode querycommitted --channelID hotchannel --name dfir
echo ""

echo -e "${GREEN}✓ Hot Blockchain Chaincode Deployed!${NC}"
echo ""

###############################################################################
# COLD BLOCKCHAIN
###############################################################################

echo -e "${YELLOW}=== COLD BLOCKCHAIN ===${NC}"
echo ""

# Get package ID
echo -e "${YELLOW}[7/7] Attempting cold blockchain deployment...${NC}"
PACKAGE_ID_COLD=$(docker exec cli-cold peer lifecycle chaincode queryinstalled 2>/dev/null | grep "audit_1.0" | awk '{print $3}' | sed 's/,$//' || echo "")

if [ -z "$PACKAGE_ID_COLD" ]; then
    echo -e "${YELLOW}Cold chaincode not installed yet, packaging and installing...${NC}"

    docker exec cli-cold peer lifecycle chaincode package /tmp/audit.tar.gz \
        --path /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode \
        --lang golang \
        --label audit_1.0

    docker exec cli-cold peer lifecycle chaincode install /tmp/audit.tar.gz

    PACKAGE_ID_COLD=$(docker exec cli-cold peer lifecycle chaincode queryinstalled | grep "audit_1.0" | awk '{print $3}' | sed 's/,$//')
fi

echo "Cold Package ID: $PACKAGE_ID_COLD"

# Approve for Auditor
docker exec cli-cold peer lifecycle chaincode approveformyorg \
    -o orderer.cold.coc.com:7150 \
    --channelID coldchannel \
    --name audit \
    --version 1.0 \
    --package-id ${PACKAGE_ID_COLD} \
    --sequence 1 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem

# Commit
docker exec cli-cold peer lifecycle chaincode commit \
    -o orderer.cold.coc.com:7150 \
    --channelID coldchannel \
    --name audit \
    --version 1.0 \
    --sequence 1 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem \
    --peerAddresses peer0.auditor.cold.coc.com:9051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/auditor.cold.coc.com/peers/peer0.auditor.cold.coc.com/tls/ca.crt

# Verify
docker exec cli-cold peer lifecycle chaincode querycommitted --channelID coldchannel --name audit
echo ""

echo -e "${GREEN}==========================================="
echo "✓ All Chaincodes Deployed Successfully!"
echo -e "===========================================${NC}"
echo ""
