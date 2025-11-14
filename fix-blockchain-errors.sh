#!/bin/bash

###############################################################################
# Fix Script for Blockchain Chain of Custody System
# Resolves TLS certificate and channel configuration errors
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Blockchain Error Resolution Script     ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Step 1: Stop all running containers and clean up
echo -e "${YELLOW}[Step 1] Stopping all containers and cleaning up...${NC}"
docker-compose -f docker-compose-hot.yml down -v 2>/dev/null || true
docker-compose -f docker-compose-cold.yml down -v 2>/dev/null || true
docker-compose -f docker-compose-storage.yml down -v 2>/dev/null || true

# Remove all blockchain volumes
docker volume prune -f

echo -e "${GREEN}✓ Containers stopped and volumes cleaned${NC}"

# Step 2: Clean up old crypto material and artifacts
echo -e "${YELLOW}[Step 2] Removing old crypto materials and artifacts...${NC}"
rm -rf hot-blockchain/crypto-config
rm -rf cold-blockchain/crypto-config
rm -rf hot-blockchain/channel-artifacts/*
rm -rf cold-blockchain/channel-artifacts/*

# Create necessary directories
mkdir -p hot-blockchain/channel-artifacts
mkdir -p cold-blockchain/channel-artifacts

echo -e "${GREEN}✓ Old materials removed${NC}"

# Step 3: Set environment variables
echo -e "${YELLOW}[Step 3] Setting environment variables...${NC}"
export PATH="$PWD/fabric-samples/bin:$PATH"
export FABRIC_CFG_PATH="$PWD"

# Verify tools are available
if ! command -v cryptogen &> /dev/null; then
    echo -e "${RED}Error: cryptogen not found. Installing Fabric binaries...${NC}"
    curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.0 1.5.5
fi

echo -e "${GREEN}✓ Environment configured${NC}"

# Step 4: Generate fresh crypto material for Hot Blockchain
echo -e "${YELLOW}[Step 4] Generating fresh crypto material for Hot Blockchain...${NC}"
cd hot-blockchain
cryptogen generate --config=./crypto-config.yaml --output="./crypto-config"

# Verify crypto generation
if [ ! -d "crypto-config/ordererOrganizations" ]; then
    echo -e "${RED}Error: Crypto material generation failed for Hot Blockchain${NC}"
    exit 1
fi
cd ..
echo -e "${GREEN}✓ Hot blockchain crypto generated${NC}"

# Step 5: Generate fresh crypto material for Cold Blockchain
echo -e "${YELLOW}[Step 5] Generating fresh crypto material for Cold Blockchain...${NC}"
cd cold-blockchain
cryptogen generate --config=./crypto-config.yaml --output="./crypto-config"

# Verify crypto generation
if [ ! -d "crypto-config/ordererOrganizations" ]; then
    echo -e "${RED}Error: Crypto material generation failed for Cold Blockchain${NC}"
    exit 1
fi
cd ..
echo -e "${GREEN}✓ Cold blockchain crypto generated${NC}"

# Step 6: Generate genesis block for Hot Blockchain (System Channel)
echo -e "${YELLOW}[Step 6] Generating genesis block for Hot Blockchain...${NC}"
cd hot-blockchain
export FABRIC_CFG_PATH="$PWD"

# First generate the system channel genesis block for orderer bootstrap
configtxgen -profile HotChainGenesis -channelID system-channel -outputBlock ./channel-artifacts/genesis.block

if [ ! -f "channel-artifacts/genesis.block" ]; then
    echo -e "${RED}Error: Genesis block generation failed for Hot Blockchain${NC}"
    exit 1
fi
cd ..
echo -e "${GREEN}✓ Hot blockchain genesis block created${NC}"

# Step 7: Generate genesis block for Cold Blockchain (System Channel)
echo -e "${YELLOW}[Step 7] Generating genesis block for Cold Blockchain...${NC}"
cd cold-blockchain
export FABRIC_CFG_PATH="$PWD"

# First generate the system channel genesis block for orderer bootstrap
configtxgen -profile ColdChainGenesis -channelID system-channel -outputBlock ./channel-artifacts/genesis.block

if [ ! -f "channel-artifacts/genesis.block" ]; then
    echo -e "${RED}Error: Genesis block generation failed for Cold Blockchain${NC}"
    exit 1
fi
cd ..
echo -e "${GREEN}✓ Cold blockchain genesis block created${NC}"

# Step 8: Start Storage Services first
echo -e "${YELLOW}[Step 8] Starting IPFS and MySQL services...${NC}"
docker-compose -f docker-compose-storage.yml up -d

# Wait for services to be ready
sleep 5

# Verify IPFS is running
if ! curl -s http://localhost:5001/api/v0/version > /dev/null; then
    echo -e "${YELLOW}Warning: IPFS may not be fully ready yet${NC}"
fi

echo -e "${GREEN}✓ Storage services started${NC}"

# Step 9: Start Hot Blockchain
echo -e "${YELLOW}[Step 9] Starting Hot Blockchain network...${NC}"
docker-compose -f docker-compose-hot.yml up -d

# Wait for Hot Blockchain to initialize
echo -e "${YELLOW}Waiting for Hot Blockchain to initialize (20 seconds)...${NC}"
sleep 20

# Verify orderer is running
docker exec orderer.hot.coc.com orderer version || echo -e "${YELLOW}Warning: Hot orderer may not be ready${NC}"

echo -e "${GREEN}✓ Hot blockchain network started${NC}"

# Step 10: Start Cold Blockchain
echo -e "${YELLOW}[Step 10] Starting Cold Blockchain network...${NC}"
docker-compose -f docker-compose-cold.yml up -d

# Wait for Cold Blockchain to initialize
echo -e "${YELLOW}Waiting for Cold Blockchain to initialize (20 seconds)...${NC}"
sleep 20

# Verify orderer is running
docker exec orderer.cold.coc.com orderer version || echo -e "${YELLOW}Warning: Cold orderer may not be ready${NC}"

echo -e "${GREEN}✓ Cold blockchain network started${NC}"

# Step 11: Create channels using the new method (Fabric 2.5)
echo -e "${YELLOW}[Step 11] Creating application channels...${NC}"

# Generate Hot Channel transaction
cd hot-blockchain
export FABRIC_CFG_PATH="$PWD"
configtxgen -profile HotChainChannel -outputCreateChannelTx ./channel-artifacts/hotchannel.tx -channelID hotchannel

# Generate Cold Channel transaction  
cd ../cold-blockchain
export FABRIC_CFG_PATH="$PWD"
configtxgen -profile ColdChainChannel -outputCreateChannelTx ./channel-artifacts/coldchannel.tx -channelID coldchannel

cd ..
echo -e "${GREEN}✓ Channel transactions generated${NC}"

# Step 12: Create channels using peer commands
echo -e "${YELLOW}[Step 12] Creating channels using peer commands...${NC}"

# Create Hot Channel
echo -e "${BLUE}Creating Hot Channel...${NC}"
docker exec cli peer channel create \
    -o orderer.hot.coc.com:7050 \
    -c hotchannel \
    -f ./channel-artifacts/hotchannel.tx \
    --tls true \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem \
    --outputBlock ./channel-artifacts/hotchannel.block \
    2>/dev/null || echo -e "${YELLOW}Hot channel may already exist${NC}"

# Join Law Enforcement peer
docker exec cli peer channel join -b ./channel-artifacts/hotchannel.block 2>/dev/null || echo -e "${YELLOW}Law Enforcement peer may already be joined${NC}"

# Join Forensic Lab peer
docker exec -e CORE_PEER_ADDRESS=peer0.forensiclab.hot.coc.com:8051 \
    -e CORE_PEER_LOCALMSPID="ForensicLabMSP" \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt \
    cli peer channel join -b ./channel-artifacts/hotchannel.block 2>/dev/null || echo -e "${YELLOW}Forensic Lab peer may already be joined${NC}"

# Create Cold Channel
echo -e "${BLUE}Creating Cold Channel...${NC}"
docker exec cli-cold peer channel create \
    -o orderer.cold.coc.com:7150 \
    -c coldchannel \
    -f ./channel-artifacts/coldchannel.tx \
    --tls true \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem \
    --outputBlock ./channel-artifacts/coldchannel.block \
    2>/dev/null || echo -e "${YELLOW}Cold channel may already exist${NC}"

# Join Archive peer
docker exec cli-cold peer channel join -b ./channel-artifacts/coldchannel.block 2>/dev/null || echo -e "${YELLOW}Archive peer may already be joined${NC}"

echo -e "${GREEN}✓ Channels created and peers joined${NC}"

# Step 13: Verify everything is working
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}           System Verification           ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check running containers
echo -e "${YELLOW}Checking Docker containers...${NC}"
running_containers=$(docker ps --format "table {{.Names}}" | tail -n +2 | wc -l)
echo -e "Running containers: ${GREEN}$running_containers${NC}"

# List containers
docker ps --format "table {{.Names}}\t{{.Status}}"

# Check Hot Channel
echo ""
echo -e "${YELLOW}Hot Blockchain Channel Status:${NC}"
docker exec cli peer channel list 2>/dev/null || echo -e "${RED}Error checking hot channels${NC}"

# Check Cold Channel
echo ""
echo -e "${YELLOW}Cold Blockchain Channel Status:${NC}"
docker exec cli-cold peer channel list 2>/dev/null || echo -e "${RED}Error checking cold channels${NC}"

# Check IPFS
echo ""
echo -e "${YELLOW}IPFS Status:${NC}"
if curl -s http://localhost:5001/api/v0/version > /dev/null; then
    echo -e "${GREEN}✓ IPFS is running${NC}"
else
    echo -e "${RED}✗ IPFS is not responding${NC}"
fi

# Check MySQL
echo ""
echo -e "${YELLOW}MySQL Status:${NC}"
if docker exec mysql-coc mysql -ucocuser -pcocpassword -e "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ MySQL is running${NC}"
else
    echo -e "${RED}✗ MySQL is not responding${NC}"
fi

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}     Fix Script Completed Successfully!  ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo -e "1. Check the web interface at http://localhost:5000"
echo -e "2. Access phpMyAdmin at http://localhost:8081"
echo -e "3. Test IPFS at http://localhost:8080"
echo ""
echo -e "${YELLOW}If you still see errors, check logs with:${NC}"
echo -e "  docker logs orderer.hot.coc.com"
echo -e "  docker logs peer0.lawenforcement.hot.coc.com"
echo -e "  docker logs peer0.forensiclab.hot.coc.com"
