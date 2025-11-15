#!/bin/bash
###############################################################################
# Restart containers to apply NodeOU configuration changes
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd /home/user/Dual-hyperledger-Blockchain

echo -e "${GREEN}==========================================="
echo "Restarting Blockchain Containers"
echo -e "===========================================${NC}"
echo ""

echo -e "${YELLOW}Restarting hot and cold blockchain containers...${NC}"
docker-compose -f docker-compose-hot.yml -f docker-compose-cold.yml restart

echo ""
echo -e "${YELLOW}Waiting for containers to stabilize (15 seconds)...${NC}"
sleep 15

echo ""
echo -e "${YELLOW}Checking container status...${NC}"
docker-compose -f docker-compose-hot.yml -f docker-compose-cold.yml ps

echo ""
echo -e "${GREEN}==========================================="
echo "✓ Containers Restarted Successfully"
echo -e "===========================================${NC}"
echo ""
echo -e "${YELLOW}NodeOU configuration is now active!${NC}"
echo ""
