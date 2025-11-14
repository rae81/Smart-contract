#!/bin/bash

###############################################################################
# Complete Setup Script for Hot & Cold Blockchain System
# AUB Project 68: Chain of Custody Management
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ROOT="$(pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Blockchain CoC Setup - Complete Flow  ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Step 1: Download Fabric binaries if needed
echo -e "${GREEN}[Step 1/10] Checking Hyperledger Fabric binaries...${NC}"
if [ ! -d "fabric-samples" ]; then
    echo -e "${YELLOW}Downloading Fabric binaries and Docker images...${NC}"
    curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.0 1.5.5
    echo -e "${GREEN}✓ Downloaded successfully${NC}"
else
    echo -e "${GREEN}✓ Fabric binaries already present${NC}"
fi

export PATH="$PROJECT_ROOT/fabric-samples/bin:$PATH"
export FABRIC_CFG_PATH="$PROJECT_ROOT"

# Step 2: Generate crypto material for Hot Blockchain
echo -e "${GREEN}[Step 2/10] Generating crypto material for Hot Blockchain...${NC}"
cd "$PROJECT_ROOT/hot-blockchain"
cryptogen generate --config=./crypto-config.yaml --output="./crypto-config"
echo -e "${GREEN}✓ Hot blockchain crypto generated${NC}"

# Step 3: Generate crypto material for Cold Blockchain
echo -e "${GREEN}[Step 3/10] Generating crypto material for Cold Blockchain...${NC}"
cd "$PROJECT_ROOT/cold-blockchain"
cryptogen generate --config=./crypto-config.yaml --output="./crypto-config"
echo -e "${GREEN}✓ Cold blockchain crypto generated${NC}"

# Step 4: Generate genesis block for Hot Blockchain
echo -e "${GREEN}[Step 4/10] Generating genesis block for Hot Blockchain...${NC}"
cd "$PROJECT_ROOT/hot-blockchain"
export FABRIC_CFG_PATH="$PROJECT_ROOT/hot-blockchain"
configtxgen -profile HotChainGenesis -channelID system-channel -outputBlock ./channel-artifacts/genesis.block
echo -e "${GREEN}✓ Hot blockchain genesis block created${NC}"

# Step 5: Generate channel transaction for Hot Blockchain
echo -e "${GREEN}[Step 5/10] Generating channel configuration for Hot Blockchain...${NC}"
configtxgen -profile HotChainChannel -outputCreateChannelTx ./channel-artifacts/hotchannel.tx -channelID hotchannel
echo -e "${GREEN}✓ Hot blockchain channel config created${NC}"

# Step 6: Generate genesis block for Cold Blockchain
echo -e "${GREEN}[Step 6/10] Generating genesis block for Cold Blockchain...${NC}"
cd "$PROJECT_ROOT/cold-blockchain"
export FABRIC_CFG_PATH="$PROJECT_ROOT/cold-blockchain"
configtxgen -profile ColdChainGenesis -channelID system-channel -outputBlock ./channel-artifacts/genesis.block
echo -e "${GREEN}✓ Cold blockchain genesis block created${NC}"

# Step 7: Generate channel transaction for Cold Blockchain
echo -e "${GREEN}[Step 7/10] Generating channel configuration for Cold Blockchain...${NC}"
configtxgen -profile ColdChainChannel -outputCreateChannelTx ./channel-artifacts/coldchannel.tx -channelID coldchannel
echo -e "${GREEN}✓ Cold blockchain channel config created${NC}"

# Step 8: Start Storage Services (IPFS + MySQL)
echo -e "${GREEN}[Step 8/10] Starting IPFS and MySQL services...${NC}"
cd "$PROJECT_ROOT"
docker-compose -f docker-compose-storage.yml up -d
echo -e "${GREEN}✓ Storage services started${NC}"
echo -e "${YELLOW}  - IPFS API: http://localhost:5001${NC}"
echo -e "${YELLOW}  - IPFS Gateway: http://localhost:8080${NC}"
echo -e "${YELLOW}  - MySQL: localhost:3306${NC}"
echo -e "${YELLOW}  - phpMyAdmin: http://localhost:8081${NC}"

# Step 9: Start Hot Blockchain
echo -e "${GREEN}[Step 9/10] Starting Hot Blockchain network...${NC}"
cd "$PROJECT_ROOT"
docker-compose -f docker-compose-hot.yml up -d
echo -e "${GREEN}✓ Hot blockchain network started${NC}"
echo -e "${YELLOW}  - Orderer: localhost:7050${NC}"
echo -e "${YELLOW}  - Peer0 (Law Enforcement): localhost:7051${NC}"
echo -e "${YELLOW}  - Peer0 (Forensic Lab): localhost:8051${NC}"

# Wait for Hot Blockchain to initialize
echo -e "${YELLOW}Waiting for Hot Blockchain to initialize (15 seconds)...${NC}"
sleep 15

# Step 10: Start Cold Blockchain
echo -e "${GREEN}[Step 10/10] Starting Cold Blockchain network...${NC}"
cd "$PROJECT_ROOT"
docker-compose -f docker-compose-cold.yml up -d
echo -e "${GREEN}✓ Cold blockchain network started${NC}"
echo -e "${YELLOW}  - Orderer: localhost:7150${NC}"
echo -e "${YELLOW}  - Peer0 (Archive): localhost:9051${NC}"

# Wait for Cold Blockchain to initialize
echo -e "${YELLOW}Waiting for Cold Blockchain to initialize (15 seconds)...${NC}"
sleep 15

# Show status
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}        System Status Summary            ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "${GREEN}✓ Hot Blockchain (Active Investigation Data)${NC}"
echo -e "  Organizations: LawEnforcement, ForensicLab"
echo -e "  Purpose: Frequent metadata updates, custody events"
echo ""
echo -e "${GREEN}✓ Cold Blockchain (Immutable Archive)${NC}"
echo -e "  Organizations: Archive"
echo -e "  Purpose: Long-term evidence storage, IPFS references"
echo ""
echo -e "${GREEN}✓ IPFS (Distributed Storage)${NC}"
echo -e "  API: http://localhost:5001"
echo -e "  Gateway: http://localhost:8080"
echo ""
echo -e "${GREEN}✓ MySQL Database${NC}"
echo -e "  Host: localhost:3306"
echo -e "  Database: coc_evidence"
echo -e "  Username: cocuser"
echo -e "  Password: cocpassword"
echo -e "  Web UI: http://localhost:8081"
echo ""
echo -e "${YELLOW}To view logs:${NC}"
echo -e "  Hot Blockchain:  docker-compose -f docker-compose-hot.yml logs -f"
echo -e "  Cold Blockchain: docker-compose -f docker-compose-cold.yml logs -f"
echo -e "  Storage:         docker-compose -f docker-compose-storage.yml logs -f"
echo ""
echo -e "${YELLOW}To stop everything:${NC}"
echo -e "  ./stop-all.sh"
echo ""
echo -e "${GREEN}Setup complete! Both blockchains are running.${NC}"
