#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Fabric 2.5 Channel Creation Script    ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Set paths
export PATH="$PWD/fabric-samples/bin:$PATH"
CHANNEL_NAME_HOT="hotchannel"
CHANNEL_NAME_COLD="coldchannel"

# Step 1: Generate channel genesis blocks
echo -e "${YELLOW}[1/6] Generating channel genesis blocks...${NC}"

cd hot-blockchain
export FABRIC_CFG_PATH=$PWD
configtxgen -profile HotChainChannel \
    -outputBlock ./channel-artifacts/${CHANNEL_NAME_HOT}.block \
    -channelID ${CHANNEL_NAME_HOT}
cd ..

cd cold-blockchain
export FABRIC_CFG_PATH=$PWD
configtxgen -profile ColdChainChannel \
    -outputBlock ./channel-artifacts/${CHANNEL_NAME_COLD}.block \
    -channelID ${CHANNEL_NAME_COLD}
cd ..

echo -e "${GREEN}✓ Channel genesis blocks created${NC}"

# Step 2: Join orderers to channels using osnadmin from HOST
echo -e "${YELLOW}[2/6] Joining orderers to channels (using osnadmin)...${NC}"

# Hot blockchain orderer - use hostname instead of localhost
osnadmin channel join \
    --channelID ${CHANNEL_NAME_HOT} \
    --config-block ./hot-blockchain/channel-artifacts/${CHANNEL_NAME_HOT}.block \
    -o orderer.hot.coc.com:7053 \
    --ca-file ./hot-blockchain/crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem \
    --client-cert ./hot-blockchain/crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/server.crt \
    --client-key ./hot-blockchain/crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/server.key

echo -e "${GREEN}✓ Hot orderer joined channel${NC}"

# Cold blockchain orderer - use hostname instead of localhost
osnadmin channel join \
    --channelID ${CHANNEL_NAME_COLD} \
    --config-block ./cold-blockchain/channel-artifacts/${CHANNEL_NAME_COLD}.block \
    -o orderer.cold.coc.com:7153 \
    --ca-file ./cold-blockchain/crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem \
    --client-cert ./cold-blockchain/crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/server.crt \
    --client-key ./cold-blockchain/crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/server.key

echo -e "${GREEN}✓ Cold orderer joined channel${NC}"

# Step 3: Wait for orderers to be ready
echo -e "${YELLOW}[3/6] Waiting for orderers to process channels...${NC}"
sleep 5
echo -e "${GREEN}✓ Orderers ready${NC}"

# Step 4: Copy channel blocks to CLI containers
echo -e "${YELLOW}[4/6] Copying channel blocks to peer CLI containers...${NC}"

docker cp hot-blockchain/channel-artifacts/${CHANNEL_NAME_HOT}.block cli:/opt/gopath/src/github.com/hyperledger/fabric/peer/
docker cp cold-blockchain/channel-artifacts/${CHANNEL_NAME_COLD}.block cli-cold:/opt/gopath/src/github.com/hyperledger/fabric/peer/

echo -e "${GREEN}✓ Channel blocks copied${NC}"

# Step 5: Join peers to Hot channel
echo -e "${YELLOW}[5/6] Joining peers to Hot channel...${NC}"

# Join Law Enforcement peer
docker exec cli peer channel join -b ${CHANNEL_NAME_HOT}.block

# Join Forensic Lab peer
docker exec \
    -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp \
    -e CORE_PEER_ADDRESS=peer0.forensiclab.hot.coc.com:8051 \
    -e CORE_PEER_LOCALMSPID=ForensicLabMSP \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt \
    cli peer channel join -b ${CHANNEL_NAME_HOT}.block

echo -e "${GREEN}✓ Hot blockchain peers joined${NC}"

# Step 6: Join peer to Cold channel
echo -e "${YELLOW}[6/6] Joining peer to Cold channel...${NC}"

docker exec cli-cold peer channel join -b ${CHANNEL_NAME_COLD}.block

echo -e "${GREEN}✓ Cold blockchain peer joined${NC}"

# Verification
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}         VERIFICATION                    ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

echo -e "${YELLOW}Hot Blockchain Channels:${NC}"
docker exec cli peer channel list

echo ""
echo -e "${YELLOW}Cold Blockchain Channels:${NC}"
docker exec cli-cold peer channel list

echo ""
echo -e "${YELLOW}Hot Channel Info:${NC}"
docker exec cli peer channel getinfo -c ${CHANNEL_NAME_HOT}

echo ""
echo -e "${YELLOW}Cold Channel Info:${NC}"
docker exec cli-cold peer channel getinfo -c ${CHANNEL_NAME_COLD}

echo ""
echo -e "${YELLOW}Orderer Channels (Hot):${NC}"
osnadmin channel list -o orderer.hot.coc.com:7053 \
    --ca-file ./hot-blockchain/crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem \
    --client-cert ./hot-blockchain/crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/server.crt \
    --client-key ./hot-blockchain/crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/server.key

echo ""
echo -e "${YELLOW}Orderer Channels (Cold):${NC}"
osnadmin channel list -o orderer.cold.coc.com:7153 \
    --ca-file ./cold-blockchain/crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem \
    --client-cert ./cold-blockchain/crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/server.crt \
    --client-key ./cold-blockchain/crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/server.key

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Channels Created Successfully!        ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Deploy chaincode to both blockchains"
echo -e "  2. Test the web interface at http://localhost:5000"
echo -e "  3. Check blockchain status in web UI"
echo ""
