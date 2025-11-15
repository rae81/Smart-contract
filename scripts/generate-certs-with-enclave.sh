#!/bin/bash
###############################################################################
# Generate all certificates using SGX Enclave as single root CA
# This creates a unified trust model where enclave signs all org intermediate CAs
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${GREEN}=========================================="
echo "Certificate Generation with Enclave Root CA"
echo -e "==========================================${NC}"
echo ""

cd "$PROJECT_ROOT"

# Step 1: Start enclave simulator
echo -e "${YELLOW}[1/6] Starting SGX Enclave Simulator...${NC}"
if ! curl -s http://localhost:5000/health > /dev/null 2>&1; then
    cd enclave-simulator
    python3 enclave_sgx.py > /tmp/enclave.log 2>&1 &
    ENCLAVE_PID=$!
    echo $ENCLAVE_PID > /tmp/enclave.pid
    cd "$PROJECT_ROOT"
    sleep 3
    echo -e "${GREEN}✓ Enclave started (PID: $ENCLAVE_PID)${NC}"
else
    echo -e "${GREEN}✓ Enclave already running${NC}"
fi
echo ""

# Step 2: Initialize enclave and get root CA
echo -e "${YELLOW}[2/6] Initializing enclave root CA...${NC}"
ROOT_CA_RESPONSE=$(curl -s -X POST http://localhost:5000/initialize-ca \
    -H "Content-Type: application/json" \
    -d '{"common_name": "SGX Enclave Root CA", "organization": "Chain of Custody System"}')

# Extract root CA certificate
echo "$ROOT_CA_RESPONSE" | jq -r '.root_ca_cert' > /tmp/enclave-root-ca.pem

if [ -f /tmp/enclave-root-ca.pem ] && openssl x509 -in /tmp/enclave-root-ca.pem -noout -text > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Enclave root CA initialized${NC}"
    openssl x509 -in /tmp/enclave-root-ca.pem -noout -subject -serial
else
    echo -e "${RED}✗ Failed to get root CA from enclave${NC}"
    exit 1
fi
echo ""

# Step 3: Generate intermediate CAs for each organization using enclave
echo -e "${YELLOW}[3/6] Generating organization intermediate CAs signed by enclave...${NC}"

mkdir -p /tmp/org-cas

ORGS=("hot.coc.com:Orderer" "cold.coc.com:Orderer" "lawenforcement.hot.coc.com:LawEnforcement" "forensiclab.hot.coc.com:ForensicLab" "auditor.cold.coc.com:Auditor" "court.coc.com:Court")

for org_info in "${ORGS[@]}"; do
    IFS=':' read -r domain name <<< "$org_info"
    echo "  Generating CA for $name ($domain)..."

    # Create intermediate CA request via enclave
    CA_RESPONSE=$(curl -s -X POST http://localhost:5000/create-intermediate-ca \
        -H "Content-Type: application/json" \
        -d "{
            \"common_name\": \"ca.$domain\",
            \"organization\": \"$name\",
            \"domain\": \"$domain\"
        }")

    # Save intermediate CA cert
    echo "$CA_RESPONSE" | jq -r '.intermediate_cert' > "/tmp/org-cas/ca-$domain.pem"
    echo "$CA_RESPONSE" | jq -r '.intermediate_key' > "/tmp/org-cas/ca-$domain-key.pem"

    if [ -f "/tmp/org-cas/ca-$domain.pem" ]; then
        echo -e "${GREEN}  ✓ CA for $name created${NC}"
    else
        echo -e "${RED}  ✗ Failed to create CA for $name${NC}"
    fi
done
echo ""

# Step 4: Use cryptogen to generate identity certs, then replace CAs
echo -e "${YELLOW}[4/6] Generating identity certificates with cryptogen...${NC}"

# Remove old certs
rm -rf organizations
mkdir -p organizations

# Generate with cryptogen (this creates the full structure)
cryptogen generate --config=hot-blockchain/crypto-config.yaml --output=organizations
cryptogen generate --config=cold-blockchain/crypto-config.yaml --output=organizations

echo -e "${GREEN}✓ Identity certificates generated${NC}"
echo ""

# Step 5: Replace all CA certificates with enclave-signed ones
echo -e "${YELLOW}[5/6] Replacing CA certificates with enclave-signed versions...${NC}"

# Function to replace CA certs
replace_ca_certs() {
    local org_dir=$1
    local ca_file=$2

    if [ -d "$org_dir" ]; then
        # Replace in MSP cacerts
        find "$org_dir" -type d -name "cacerts" | while read cacerts_dir; do
            rm -f "$cacerts_dir"/*.pem
            cp /tmp/enclave-root-ca.pem "$cacerts_dir/root-ca.pem"
            cp "$ca_file" "$cacerts_dir/ca-cert.pem"
            echo "  Replaced CA in: $cacerts_dir"
        done

        # Replace in TLS ca.crt files
        find "$org_dir" -type f -name "ca.crt" | while read ca_crt; do
            cat /tmp/enclave-root-ca.pem "$ca_file" > "$ca_crt"
            echo "  Updated TLS CA: $ca_crt"
        done
    fi
}

# Replace for orderers
replace_ca_certs "organizations/ordererOrganizations/hot.coc.com" "/tmp/org-cas/ca-hot.coc.com.pem"
replace_ca_certs "organizations/ordererOrganizations/cold.coc.com" "/tmp/org-cas/ca-cold.coc.com.pem"

# Replace for peers
replace_ca_certs "organizations/peerOrganizations/lawenforcement.hot.coc.com" "/tmp/org-cas/ca-lawenforcement.hot.coc.com.pem"
replace_ca_certs "organizations/peerOrganizations/forensiclab.hot.coc.com" "/tmp/org-cas/ca-forensiclab.hot.coc.com.pem"
replace_ca_certs "organizations/peerOrganizations/auditor.cold.coc.com" "/tmp/org-cas/ca-auditor.cold.coc.com.pem"
replace_ca_certs "organizations/peerOrganizations/court.coc.com" "/tmp/org-cas/ca-court.coc.com.pem"

echo -e "${GREEN}✓ All CA certificates replaced with enclave-signed versions${NC}"
echo ""

# Step 6: Generate channel artifacts
echo -e "${YELLOW}[6/6] Generating channel artifacts...${NC}"

mkdir -p channel-artifacts hot-blockchain/channel-artifacts cold-blockchain/channel-artifacts

export FABRIC_CFG_PATH="$PROJECT_ROOT/hot-blockchain"
configtxgen -profile HotChainGenesis -outputBlock ./hot-blockchain/channel-artifacts/hotchannel.block -channelID hotchannel
configtxgen -profile HotChainChannel -outputAnchorPeersUpdate ./hot-blockchain/channel-artifacts/LawEnforcementMSPanchors.tx -channelID hotchannel -asOrg LawEnforcementMSP
configtxgen -profile HotChainChannel -outputAnchorPeersUpdate ./hot-blockchain/channel-artifacts/ForensicLabMSPanchors.tx -channelID hotchannel -asOrg ForensicLabMSP

export FABRIC_CFG_PATH="$PROJECT_ROOT/cold-blockchain"
configtxgen -profile ColdChainGenesis -outputBlock ./cold-blockchain/channel-artifacts/coldchannel.block -channelID coldchannel
configtxgen -profile ColdChainChannel -outputAnchorPeersUpdate ./cold-blockchain/channel-artifacts/AuditorMSPanchors.tx -channelID coldchannel -asOrg AuditorMSP

echo -e "${GREEN}✓ Channel artifacts generated${NC}"
echo ""

echo -e "${GREEN}=========================================="
echo "✓ Certificate Generation Complete!"
echo -e "==========================================${NC}"
echo ""
echo -e "${YELLOW}Trust Model:${NC}"
echo "  SGX Enclave Root CA (single root of trust)"
echo "    ↓"
echo "  Organization Intermediate CAs (signed by enclave)"
echo "    ↓"
echo "  Identity Certificates (signed by org CAs)"
echo ""
echo -e "${GREEN}All organizations now trust the same root CA!${NC}"
echo ""
echo -e "${YELLOW}Next: Start network and create channels${NC}"
echo ""
