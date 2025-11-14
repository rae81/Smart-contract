#!/bin/bash

###############################################################################
# Hyperledger Fabric Hot & Cold Blockchain Setup Script
# Based on AUB Project 68: Chain of Custody Management System
###############################################################################

set -e

echo "========================================="
echo "Setting up Hot & Cold Blockchain System"
echo "========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project directories
PROJECT_ROOT="/home/claude/blockchain-coc"
HOT_CHAIN_DIR="$PROJECT_ROOT/hot-blockchain"
COLD_CHAIN_DIR="$PROJECT_ROOT/cold-blockchain"
SHARED_DIR="$PROJECT_ROOT/shared"

# Create directory structure
echo -e "${GREEN}Creating directory structure...${NC}"
mkdir -p "$HOT_CHAIN_DIR"/{crypto-config,channel-artifacts,chaincode,scripts}
mkdir -p "$COLD_CHAIN_DIR"/{crypto-config,channel-artifacts,chaincode,scripts}
mkdir -p "$SHARED_DIR"/{ipfs,database,certificates}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${GREEN}Checking prerequisites...${NC}"

# Check Docker
if ! command_exists docker; then
    echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Check Docker Compose
if ! command_exists docker-compose; then
    echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

echo -e "${GREEN}All prerequisites satisfied!${NC}"

# Download Hyperledger Fabric binaries and Docker images
echo -e "${GREEN}Downloading Hyperledger Fabric binaries...${NC}"
cd "$PROJECT_ROOT"

if [ ! -d "fabric-samples" ]; then
    curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.0 1.5.5
fi

# Add binaries to PATH
export PATH="$PROJECT_ROOT/fabric-samples/bin:$PATH"
export FABRIC_CFG_PATH="$PROJECT_ROOT/fabric-samples/config"

echo -e "${GREEN}Hyperledger Fabric binaries downloaded successfully!${NC}"
echo -e "${YELLOW}Hot Blockchain: Handles frequent investigative metadata${NC}"
echo -e "${YELLOW}Cold Blockchain: Stores immutable evidence records${NC}"

echo ""
echo "Next steps:"
echo "1. Run ./configure-hot-chain.sh to set up Hot Blockchain"
echo "2. Run ./configure-cold-chain.sh to set up Cold Blockchain"
echo "3. Run ./setup-ipfs.sh to configure IPFS storage"
echo "4. Run ./setup-database.sh to configure MySQL database"
