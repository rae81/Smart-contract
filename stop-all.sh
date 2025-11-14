#!/bin/bash

###############################################################################
# Stop All Services Script
###############################################################################

set -e

PROJECT_ROOT="/home/claude/blockchain-coc"
cd "$PROJECT_ROOT"

echo "Stopping all blockchain and storage services..."

# Stop Cold Blockchain
echo "Stopping Cold Blockchain..."
docker-compose -f docker-compose-cold.yml down -v

# Stop Hot Blockchain
echo "Stopping Hot Blockchain..."
docker-compose -f docker-compose-hot.yml down -v

# Stop Storage Services
echo "Stopping IPFS and MySQL..."
docker-compose -f docker-compose-storage.yml down -v

echo "All services stopped successfully!"
