#!/bin/bash
###############################################################################
# NUCLEAR CLEANUP - Remove EVERYTHING and start completely fresh
###############################################################################

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${RED}=========================================="
echo "NUCLEAR CLEANUP - REMOVING EVERYTHING"
echo -e "==========================================${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C within 5 seconds to abort...${NC}"
sleep 5

cd "$PROJECT_ROOT"

# Step 1: Stop and remove all containers, networks, and volumes
echo -e "${YELLOW}[1/5] Removing all Docker containers, networks, and volumes...${NC}"
docker-compose -f docker-compose-hot.yml -f docker-compose-cold.yml down -v --remove-orphans 2>/dev/null || true
docker system prune -af --volumes 2>/dev/null || true
echo -e "${GREEN}✓ Docker completely cleaned${NC}"
echo ""

# Step 2: Remove all certificate directories
echo -e "${YELLOW}[2/5] Removing all certificate and data directories...${NC}"
rm -rf organizations organizations-backup-* 2>/dev/null || true
rm -rf channel-artifacts hot-blockchain/channel-artifacts cold-blockchain/channel-artifacts 2>/dev/null || true
rm -rf fabric-ca 2>/dev/null || true
rm -rf sealed-keys-backup 2>/dev/null || true
echo -e "${GREEN}✓ All old directories removed${NC}"
echo ""

# Step 3: Generate fresh certificates with cryptogen
echo -e "${YELLOW}[3/5] Generating fresh certificates with cryptogen...${NC}"
mkdir -p organizations channel-artifacts

echo "  Generating hot blockchain certificates..."
cryptogen generate --config=hot-blockchain/crypto-config.yaml --output=organizations
echo "  Generating cold blockchain certificates..."
cryptogen generate --config=cold-blockchain/crypto-config.yaml --output=organizations
echo -e "${GREEN}✓ Fresh certificates generated${NC}"
echo ""

# Step 4: Generate channel artifacts
echo -e "${YELLOW}[4/5] Generating channel genesis blocks...${NC}"

export FABRIC_CFG_PATH="$PROJECT_ROOT/hot-blockchain"
configtxgen -profile HotChainGenesis -outputBlock ./channel-artifacts/hotchannel.block -channelID hotchannel
configtxgen -profile HotChainChannel -outputAnchorPeersUpdate ./channel-artifacts/LawEnforcementMSPanchors.tx -channelID hotchannel -asOrg LawEnforcementMSP
configtxgen -profile HotChainChannel -outputAnchorPeersUpdate ./channel-artifacts/ForensicLabMSPanchors.tx -channelID hotchannel -asOrg ForensicLabMSP

export FABRIC_CFG_PATH="$PROJECT_ROOT/cold-blockchain"
configtxgen -profile ColdChainGenesis -outputBlock ./channel-artifacts/coldchannel.block -channelID coldchannel
configtxgen -profile ColdChainChannel -outputAnchorPeersUpdate ./channel-artifacts/AuditorMSPanchors.tx -channelID coldchannel -asOrg AuditorMSP

echo -e "${GREEN}✓ Channel artifacts generated${NC}"
echo ""

# Step 5: Start network
echo -e "${YELLOW}[5/5] Starting fresh blockchain network...${NC}"
docker-compose -f docker-compose-hot.yml -f docker-compose-cold.yml up -d
echo -e "${GREEN}✓ Network started${NC}"
echo ""

echo -e "${YELLOW}Waiting for network to stabilize (20 seconds)...${NC}"
sleep 20

echo -e "${GREEN}=========================================="
echo "✓ Nuclear Cleanup Complete"
echo -e "==========================================${NC}"
echo ""
echo -e "${YELLOW}Verifying orderers:${NC}"
docker logs orderer.hot.coc.com 2>&1 | tail -5
echo ""
docker logs orderer.cold.coc.com 2>&1 | tail -5
echo ""
echo -e "${GREEN}Ready to create channels!${NC}"
echo ""
