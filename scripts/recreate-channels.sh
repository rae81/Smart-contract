#!/bin/bash
###############################################################################
# Recreate channels with member-based policies
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd /home/user/Dual-hyperledger-Blockchain

echo -e "${GREEN}==========================================="
echo "Recreating Channels with Member Policies"
echo -e "===========================================${NC}"
echo ""

# Stop containers
echo -e "${YELLOW}[1/6] Stopping containers...${NC}"
docker-compose -f docker-compose-hot.yml -f docker-compose-cold.yml down

# Clean old channel artifacts
echo -e "${YELLOW}[2/6] Cleaning old channel artifacts...${NC}"
rm -rf hot-blockchain/channel-artifacts/*
rm -rf cold-blockchain/channel-artifacts/*
mkdir -p hot-blockchain/channel-artifacts
mkdir -p cold-blockchain/channel-artifacts

# Generate new genesis blocks with member-based policies
echo -e "${YELLOW}[3/6] Generating hot blockchain genesis block...${NC}"
cd hot-blockchain
configtxgen -profile HotChainChannel -outputBlock ./channel-artifacts/hotchannel.block -channelID hotchannel -configPath .
cd ..

echo -e "${YELLOW}[4/6] Generating cold blockchain genesis block...${NC}"
cd cold-blockchain
configtxgen -profile ColdChainChannel -outputBlock ./channel-artifacts/coldchannel.block -channelID coldchannel -configPath .
cd ..

# Start containers
echo -e "${YELLOW}[5/6] Starting containers...${NC}"
docker-compose -f docker-compose-hot.yml -f docker-compose-cold.yml up -d
sleep 20

# Join peers to channels
echo -e "${YELLOW}[6/6] Joining peers to channels...${NC}"

# Hot blockchain
echo "Joining Law Enforcement to hotchannel..."
docker exec cli osnadmin channel join \
    --channelID hotchannel \
    --config-block /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/hotchannel.block \
    -o orderer.hot.coc.com:7053 \
    --ca-file /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/ca.crt \
    --client-cert /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/server.crt \
    --client-key /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/server.key || true

docker exec cli peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/hotchannel.block

echo "Joining Forensic Lab to hotchannel..."
docker exec \
    -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp \
    -e CORE_PEER_ADDRESS=peer0.forensiclab.hot.coc.com:8051 \
    -e CORE_PEER_LOCALMSPID=ForensicLabMSP \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt \
    cli peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/hotchannel.block

# Cold blockchain
echo "Joining Auditor to coldchannel..."
docker exec cli-cold osnadmin channel join \
    --channelID coldchannel \
    --config-block /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/coldchannel.block \
    -o orderer.cold.coc.com:7153 \
    --ca-file /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/ca.crt \
    --client-cert /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/server.crt \
    --client-key /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/server.key || true

docker exec cli-cold peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/coldchannel.block

sleep 5

echo ""
echo -e "${GREEN}==========================================="
echo "✓ Channels Recreated Successfully!"
echo -e "===========================================${NC}"
echo ""
echo "Verify with:"
echo "  docker exec cli peer channel list"
echo "  docker exec cli-cold peer channel list"
echo ""
