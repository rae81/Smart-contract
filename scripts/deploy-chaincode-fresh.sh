#!/bin/bash
###############################################################################
# Complete chaincode deployment from scratch
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd /home/user/Dual-hyperledger-Blockchain

echo -e "${GREEN}==========================================="
echo "Complete Chaincode Deployment"
echo -e "===========================================${NC}"
echo ""

###############################################################################
# HOT BLOCKCHAIN - DFIR Chaincode
###############################################################################

echo -e "${YELLOW}=== HOT BLOCKCHAIN ===${NC}"
echo ""

echo -e "${YELLOW}[1/8] Packaging DFIR chaincode...${NC}"
docker exec cli peer lifecycle chaincode package /tmp/dfir.tar.gz \
    --path /opt/gopath/src/github.com/chaincode \
    --lang golang \
    --label dfir_1.0

echo -e "${YELLOW}[2/8] Installing on Law Enforcement peer...${NC}"
docker exec cli peer lifecycle chaincode install /tmp/dfir.tar.gz

echo -e "${YELLOW}[3/8] Installing on Forensic Lab peer...${NC}"
docker exec \
    -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp \
    -e CORE_PEER_ADDRESS=peer0.forensiclab.hot.coc.com:8051 \
    -e CORE_PEER_LOCALMSPID=ForensicLabMSP \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt \
    cli peer lifecycle chaincode install /tmp/dfir.tar.gz

echo -e "${YELLOW}[4/8] Getting package ID...${NC}"
PACKAGE_ID=$(docker exec cli peer lifecycle chaincode queryinstalled | grep "dfir_1.0" | awk '{print $3}' | sed 's/,$//')
echo "Package ID: $PACKAGE_ID"

echo -e "${YELLOW}[5/8] Approving for Law Enforcement...${NC}"
docker exec cli peer lifecycle chaincode approveformyorg \
    -o orderer.hot.coc.com:7050 \
    --channelID hotchannel \
    --name dfir \
    --version 1.0 \
    --package-id ${PACKAGE_ID} \
    --sequence 1 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem

echo -e "${YELLOW}[6/8] Approving for Forensic Lab...${NC}"
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
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem

echo -e "${YELLOW}[7/8] Committing to hotchannel...${NC}"
docker exec cli peer lifecycle chaincode commit \
    -o orderer.hot.coc.com:7050 \
    --channelID hotchannel \
    --name dfir \
    --version 1.0 \
    --sequence 1 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem \
    --peerAddresses peer0.lawenforcement.hot.coc.com:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/lawenforcement.hot.coc.com/peers/peer0.lawenforcement.hot.coc.com/tls/ca.crt \
    --peerAddresses peer0.forensiclab.hot.coc.com:8051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt

echo -e "${YELLOW}[8/8] Verifying deployment...${NC}"
docker exec cli peer lifecycle chaincode querycommitted --channelID hotchannel --name dfir

echo ""
echo -e "${GREEN}✓ Hot Blockchain Chaincode Deployed!${NC}"
echo ""

###############################################################################
# COLD BLOCKCHAIN - Audit Chaincode
###############################################################################

echo -e "${YELLOW}=== COLD BLOCKCHAIN ===${NC}"
echo ""

echo -e "${YELLOW}[1/5] Packaging audit chaincode...${NC}"
docker exec cli-cold peer lifecycle chaincode package /tmp/audit.tar.gz \
    --path /opt/gopath/src/github.com/chaincode \
    --lang golang \
    --label audit_1.0

echo -e "${YELLOW}[2/5] Installing on Auditor peer...${NC}"
docker exec cli-cold peer lifecycle chaincode install /tmp/audit.tar.gz

echo -e "${YELLOW}[3/5] Getting package ID...${NC}"
PACKAGE_ID_COLD=$(docker exec cli-cold peer lifecycle chaincode queryinstalled | grep "audit_1.0" | awk '{print $3}' | sed 's/,$//')
echo "Package ID: $PACKAGE_ID_COLD"

echo -e "${YELLOW}[4/5] Approving and committing...${NC}"
docker exec cli-cold peer lifecycle chaincode approveformyorg \
    -o orderer.cold.coc.com:7150 \
    --channelID coldchannel \
    --name audit \
    --version 1.0 \
    --package-id ${PACKAGE_ID_COLD} \
    --sequence 1 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem

docker exec cli-cold peer lifecycle chaincode commit \
    -o orderer.cold.coc.com:7150 \
    --channelID coldchannel \
    --name audit \
    --version 1.0 \
    --sequence 1 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem \
    --peerAddresses peer0.auditor.cold.coc.com:9051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/auditor.cold.coc.com/peers/peer0.auditor.cold.coc.com/tls/ca.crt

echo -e "${YELLOW}[5/5] Verifying deployment...${NC}"
docker exec cli-cold peer lifecycle chaincode querycommitted --channelID coldchannel --name audit

echo ""
echo -e "${GREEN}==========================================="
echo "✓ All Chaincodes Deployed Successfully!"
echo -e "===========================================${NC}"
echo ""
