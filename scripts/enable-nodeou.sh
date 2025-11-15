#!/bin/bash
###############################################################################
# Enable NodeOUs for all organizations to fix policy evaluation
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd /home/user/Dual-hyperledger-Blockchain

echo -e "${GREEN}==========================================="
echo "Enabling NodeOUs for All Organizations"
echo -e "===========================================${NC}"
echo ""

# Create NodeOU config template
create_config_yaml() {
    local msp_dir=$1
    local org_name=$2

    cat > "${msp_dir}/config.yaml" <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca-cert.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca-cert.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca-cert.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca-cert.pem
    OrganizationalUnitIdentifier: orderer
EOF
    echo -e "${GREEN}✓ Created config.yaml for $org_name${NC}"
}

# Hot Blockchain Organizations
echo -e "${YELLOW}[1/6] Configuring Hot Orderer MSP...${NC}"
create_config_yaml "hot-blockchain/crypto-config/ordererOrganizations/hot.coc.com/msp" "Hot Orderer"
create_config_yaml "hot-blockchain/crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp" "Hot Orderer Instance"

echo -e "${YELLOW}[2/6] Configuring Law Enforcement MSP...${NC}"
create_config_yaml "hot-blockchain/crypto-config/peerOrganizations/lawenforcement.hot.coc.com/msp" "Law Enforcement"
create_config_yaml "hot-blockchain/crypto-config/peerOrganizations/lawenforcement.hot.coc.com/peers/peer0.lawenforcement.hot.coc.com/msp" "Law Enforcement Peer"

echo -e "${YELLOW}[3/6] Configuring Forensic Lab MSP...${NC}"
create_config_yaml "hot-blockchain/crypto-config/peerOrganizations/forensiclab.hot.coc.com/msp" "Forensic Lab"
create_config_yaml "hot-blockchain/crypto-config/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/msp" "Forensic Lab Peer"

# Cold Blockchain Organizations
echo -e "${YELLOW}[4/6] Configuring Cold Orderer MSP...${NC}"
create_config_yaml "cold-blockchain/crypto-config/ordererOrganizations/cold.coc.com/msp" "Cold Orderer"
create_config_yaml "cold-blockchain/crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp" "Cold Orderer Instance"

echo -e "${YELLOW}[5/6] Configuring Archive MSP...${NC}"
create_config_yaml "cold-blockchain/crypto-config/peerOrganizations/archive.cold.coc.com/msp" "Archive"
create_config_yaml "cold-blockchain/crypto-config/peerOrganizations/archive.cold.coc.com/peers/peer0.archive.cold.coc.com/msp" "Archive Peer"

# Court (if exists)
if [ -d "hot-blockchain/crypto-config/peerOrganizations/court.coc.com" ]; then
    echo -e "${YELLOW}[6/6] Configuring Court MSP...${NC}"
    create_config_yaml "hot-blockchain/crypto-config/peerOrganizations/court.coc.com/msp" "Court"
    create_config_yaml "hot-blockchain/crypto-config/peerOrganizations/court.coc.com/peers/peer0.court.coc.com/msp" "Court Peer"
else
    echo -e "${YELLOW}[6/6] Court organization not found, skipping...${NC}"
fi

echo ""
echo -e "${GREEN}==========================================="
echo "✓ NodeOUs Enabled for All Organizations"
echo -e "===========================================${NC}"
echo ""
echo -e "${YELLOW}Next: Restart containers for changes to take effect${NC}"
echo ""
