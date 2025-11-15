#!/bin/bash
# Fix permissions, regenerate genesis, and create channels - ALL IN ONE

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd ~/Dual-hyperledger-Blockchain

echo -e "${YELLOW}[1/4] Fixing permissions...${NC}"
sudo rm -rf hot-blockchain/channel-artifacts cold-blockchain/channel-artifacts
mkdir -p hot-blockchain/channel-artifacts cold-blockchain/channel-artifacts
echo -e "${GREEN}✓ Permissions fixed${NC}"

echo -e "${YELLOW}[2/4] Regenerating genesis blocks WITHOUT Court...${NC}"
export FABRIC_CFG_PATH="$PWD/hot-blockchain"
configtxgen -profile HotChainChannel -outputBlock ./hot-blockchain/channel-artifacts/hotchannel.block -channelID hotchannel
configtxgen -profile HotChainChannel -outputAnchorPeersUpdate ./hot-blockchain/channel-artifacts/LawEnforcementMSPanchors.tx -channelID hotchannel -asOrg LawEnforcementMSP
configtxgen -profile HotChainChannel -outputAnchorPeersUpdate ./hot-blockchain/channel-artifacts/ForensicLabMSPanchors.tx -channelID hotchannel -asOrg ForensicLabMSP

export FABRIC_CFG_PATH="$PWD/cold-blockchain"
configtxgen -profile ColdChainChannel -outputBlock ./cold-blockchain/channel-artifacts/coldchannel.block -channelID coldchannel
configtxgen -profile ColdChainChannel -outputAnchorPeersUpdate ./cold-blockchain/channel-artifacts/AuditorMSPanchors.tx -channelID coldchannel -asOrg AuditorMSP
echo -e "${GREEN}✓ Genesis blocks regenerated${NC}"

echo -e "${YELLOW}[3/4] Restarting containers to pick up new genesis blocks...${NC}"
docker-compose -f docker-compose-hot.yml -f docker-compose-cold.yml restart
sleep 15
echo -e "${GREEN}✓ Containers restarted${NC}"

echo -e "${YELLOW}[4/4] Creating channels...${NC}"
./scripts/create-channels-with-dynamic-mtls.sh
