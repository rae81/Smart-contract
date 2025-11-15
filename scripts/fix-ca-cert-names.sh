#!/bin/bash
###############################################################################
# Create ca-cert.pem symlinks for NodeOU config
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd /home/user/Dual-hyperledger-Blockchain

echo -e "${GREEN}==========================================="
echo "Fixing CA Certificate References"
echo -e "===========================================${NC}"
echo ""

# Function to create ca-cert.pem symlink or copy
fix_cacert() {
    local cacerts_dir=$1
    local org_name=$2

    if [ -d "$cacerts_dir" ]; then
        cd "$cacerts_dir"
        # Find the actual CA cert file (should be only one .pem file)
        ca_file=$(ls *.pem | head -1)
        if [ ! -z "$ca_file" ] && [ ! -f "ca-cert.pem" ]; then
            ln -s "$ca_file" ca-cert.pem
            echo -e "${GREEN}✓ Created ca-cert.pem link for $org_name${NC}"
        elif [ -f "ca-cert.pem" ]; then
            echo -e "${GREEN}✓ ca-cert.pem already exists for $org_name${NC}"
        fi
        cd - > /dev/null
    fi
}

echo -e "${YELLOW}Fixing Hot Blockchain CA certs...${NC}"
fix_cacert "hot-blockchain/crypto-config/ordererOrganizations/hot.coc.com/msp/cacerts" "Hot Orderer"
fix_cacert "hot-blockchain/crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/cacerts" "Hot Orderer Instance"
fix_cacert "hot-blockchain/crypto-config/peerOrganizations/lawenforcement.hot.coc.com/msp/cacerts" "Law Enforcement"
fix_cacert "hot-blockchain/crypto-config/peerOrganizations/lawenforcement.hot.coc.com/peers/peer0.lawenforcement.hot.coc.com/msp/cacerts" "Law Enforcement Peer"
fix_cacert "hot-blockchain/crypto-config/peerOrganizations/forensiclab.hot.coc.com/msp/cacerts" "Forensic Lab"
fix_cacert "hot-blockchain/crypto-config/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/msp/cacerts" "Forensic Lab Peer"

echo ""
echo -e "${YELLOW}Fixing Cold Blockchain CA certs...${NC}"
fix_cacert "cold-blockchain/crypto-config/ordererOrganizations/cold.coc.com/msp/cacerts" "Cold Orderer"
fix_cacert "cold-blockchain/crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/cacerts" "Cold Orderer Instance"
fix_cacert "cold-blockchain/crypto-config/peerOrganizations/auditor.cold.coc.com/msp/cacerts" "Auditor"
fix_cacert "cold-blockchain/crypto-config/peerOrganizations/auditor.cold.coc.com/peers/peer0.auditor.cold.coc.com/msp/cacerts" "Auditor Peer"

echo ""
echo -e "${GREEN}==========================================="
echo "✓ CA Certificate References Fixed"
echo -e "===========================================${NC}"
echo ""
