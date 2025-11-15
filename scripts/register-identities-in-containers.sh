#!/bin/bash
# Register identities inside CA containers (workaround for authentication issue)
# This script runs registration commands INSIDE the CA containers where bootstrap admin credentials work
# After registration, enrollment from host will still get dynamic mTLS certificates from Enclave Root CA chain

set -e

echo "=============================================="
echo "Registering identities inside CA containers"
echo "=============================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to enroll admin in CA container (only once per container)
enroll_admin_in_container() {
    local CONTAINER_NAME=$1
    local CA_NAME=$2

    # Check if admin already enrolled in this container
    if docker exec $CONTAINER_NAME test -f /tmp/ca-admin/msp/signcerts/cert.pem 2>/dev/null; then
        return 0
    fi

    echo "  Enrolling admin in $CONTAINER_NAME..."
    docker exec $CONTAINER_NAME sh -c \
        "FABRIC_CA_CLIENT_HOME=/tmp/ca-admin fabric-ca-client enroll \
        -u https://admin:adminpw@localhost:7054 \
        --caname ca-$CA_NAME \
        --tls.certfiles /etc/hyperledger/fabric-ca-server/ca-chain.pem" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ Admin enrolled${NC}"
        return 0
    else
        echo -e "  ${RED}✗ Admin enrollment failed${NC}"
        return 1
    fi
}

# Function to register identity inside CA container
register_in_container() {
    local CONTAINER_NAME=$1
    local CA_NAME=$2
    local IDENTITY_NAME=$3
    local IDENTITY_TYPE=$4

    # Ensure admin is enrolled first
    enroll_admin_in_container "$CONTAINER_NAME" "$CA_NAME"
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Cannot register - admin enrollment failed${NC}"
        return 1
    fi

    echo "Registering $IDENTITY_NAME in $CONTAINER_NAME..."

    # Register using the enrolled admin credentials
    docker exec $CONTAINER_NAME sh -c \
        "FABRIC_CA_CLIENT_HOME=/tmp/ca-admin fabric-ca-client register \
        --caname ca-$CA_NAME \
        --id.name $IDENTITY_NAME \
        --id.secret ${IDENTITY_NAME}pw \
        --id.type $IDENTITY_TYPE \
        --tls.certfiles /etc/hyperledger/fabric-ca-server/ca-chain.pem \
        -u https://localhost:7054"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Registered $IDENTITY_NAME successfully${NC}"
    else
        echo -e "${RED}✗ Failed to register $IDENTITY_NAME${NC}"
        return 1
    fi
    echo ""
}

echo "=== Registering Hot Orderer Identities ==="
register_in_container "ca-orderer-hot" "orderer-hot" "orderer.hot.coc.com" "orderer"

echo "=== Registering Cold Orderer Identities ==="
register_in_container "ca-orderer-cold" "orderer-cold" "orderer.cold.coc.com" "orderer"

echo "=== Registering Law Enforcement Identities ==="
register_in_container "ca-lawenforcement" "lawenforcement" "peer0.lawenforcement.hot.coc.com" "peer"
register_in_container "ca-lawenforcement" "lawenforcement" "user1" "client"

echo "=== Registering Forensic Lab Identities ==="
register_in_container "ca-forensiclab" "forensiclab" "peer0.forensiclab.hot.coc.com" "peer"
register_in_container "ca-forensiclab" "forensiclab" "user1" "client"

echo "=== Registering Auditor Identities ==="
register_in_container "ca-auditor" "auditor" "peer0.auditor.cold.coc.com" "peer"
register_in_container "ca-auditor" "auditor" "user1" "client"

echo "=== Registering Court Identities ==="
register_in_container "ca-court" "court" "peer0.court.cold.coc.com" "peer"
register_in_container "ca-court" "court" "user1" "client"

echo ""
echo "=============================================="
echo -e "${GREEN}Registration complete inside CA containers${NC}"
echo "=============================================="
echo ""
echo "Next: Run scripts/enroll-all-identities.sh to enroll and get dynamic mTLS certificates"
echo "       Certificates will be issued through: Enclave Root CA → Fabric CA → Identity Certs"
