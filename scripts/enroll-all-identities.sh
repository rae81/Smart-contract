#!/bin/bash
#
# Enroll all identities with fabric-ca to get dynamic mTLS certificates
# All certs are signed by fabric-ca which is signed by Enclave Root CA
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FABRIC_CA_CLIENT_HOME="$PROJECT_ROOT/organizations"

export PATH=$PROJECT_ROOT/bin:$PATH
export FABRIC_CA_CLIENT_HOME

echo "==============================================================="
echo "Enrolling all identities with Fabric CA"
echo "==============================================================="

# Wait for all CA servers to be ready
echo "Waiting for CA servers..."
for CA in lawenforcement:7054 forensiclab:8054 auditor:9054 court:10054 orderer-hot:11054 orderer-cold:12054; do
    IFS=':' read -r NAME PORT <<< "$CA"
    until curl -sk https://localhost:$PORT/cainfo > /dev/null 2>&1; do
        echo "  Waiting for ca-$NAME..."
        sleep 2
    done
    echo "✓ ca-$NAME is ready"
done

echo ""

# ============================================================================
# Function to enroll an identity
# ============================================================================
enroll_identity() {
    local CA_NAME=$1
    local CA_PORT=$2
    local ORG_NAME=$3
    local MSP_ID=$4
    local IDENTITY_TYPE=$5  # peer, orderer, user, admin
    local IDENTITY_NAME=$6

    echo "Enrolling $IDENTITY_NAME ($IDENTITY_TYPE) with ca-$CA_NAME..."

    local CA_URL="https://admin:adminpw@localhost:$CA_PORT"
    local TLS_CERT="$PROJECT_ROOT/fabric-ca/$CA_NAME/ca-cert.pem"
    local MSP_DIR="$FABRIC_CA_CLIENT_HOME/peerOrganizations/$ORG_NAME/msp"

    if [ "$IDENTITY_TYPE" = "orderer" ]; then
        MSP_DIR="$FABRIC_CA_CLIENT_HOME/ordererOrganizations/$ORG_NAME/msp"
    fi

    # Register identity if not admin
    if [ "$IDENTITY_NAME" != "admin" ]; then
        fabric-ca-client register \
            --caname ca-$CA_NAME \
            --id.name $IDENTITY_NAME \
            --id.secret ${IDENTITY_NAME}pw \
            --id.type $IDENTITY_TYPE \
            --tls.certfiles $TLS_CERT \
            --url $CA_URL \
            --mspdir $MSP_DIR/users/Admin@$ORG_NAME/msp || true
    fi

    # Enroll identity
    local ENROLL_DIR
    if [ "$IDENTITY_TYPE" = "peer" ]; then
        ENROLL_DIR="$FABRIC_CA_CLIENT_HOME/peerOrganizations/$ORG_NAME/peers/$IDENTITY_NAME"
    elif [ "$IDENTITY_TYPE" = "orderer" ]; then
        ENROLL_DIR="$FABRIC_CA_CLIENT_HOME/ordererOrganizations/$ORG_NAME/orderers/$IDENTITY_NAME"
    elif [ "$IDENTITY_TYPE" = "admin" ]; then
        ENROLL_DIR="$FABRIC_CA_CLIENT_HOME/peerOrganizations/$ORG_NAME/users/Admin@$ORG_NAME"
    else
        ENROLL_DIR="$FABRIC_CA_CLIENT_HOME/peerOrganizations/$ORG_NAME/users/$IDENTITY_NAME"
    fi

    mkdir -p $ENROLL_DIR

    fabric-ca-client enroll \
        -u https://$IDENTITY_NAME:${IDENTITY_NAME}pw@localhost:$CA_PORT \
        --caname ca-$CA_NAME \
        --tls.certfiles $TLS_CERT \
        --mspdir $ENROLL_DIR/msp

    # Enroll for TLS
    fabric-ca-client enroll \
        -u https://$IDENTITY_NAME:${IDENTITY_NAME}pw@localhost:$CA_PORT \
        --caname ca-$CA_NAME \
        --enrollment.profile tls \
        --csr.hosts $IDENTITY_NAME \
        --csr.hosts localhost \
        --tls.certfiles $TLS_CERT \
        --mspdir $ENROLL_DIR/tls

    # Rename TLS files to standard names
    cp $ENROLL_DIR/tls/keystore/* $ENROLL_DIR/tls/server.key
    cp $ENROLL_DIR/tls/signcerts/* $ENROLL_DIR/tls/server.crt
    cp $TLS_CERT $ENROLL_DIR/tls/ca.crt

    echo "✓ Enrolled $IDENTITY_NAME"
}

# ============================================================================
# Enroll Orderers
# ============================================================================

echo ""
echo "=== Enrolling HOT Blockchain Orderer ==="
enroll_identity "orderer-hot" "11054" "hot.coc.com" "OrdererMSP" "admin" "admin"
enroll_identity "orderer-hot" "11054" "hot.coc.com" "OrdererMSP" "orderer" "orderer.hot.coc.com"

echo ""
echo "=== Enrolling COLD Blockchain Orderer ==="
enroll_identity "orderer-cold" "12054" "cold.coc.com" "OrdererMSP" "admin" "admin"
enroll_identity "orderer-cold" "12054" "cold.coc.com" "OrdererMSP" "orderer" "orderer.cold.coc.com"

# ============================================================================
# Enroll Peers
# ============================================================================

echo ""
echo "=== Enrolling LawEnforcement Org ==="
enroll_identity "lawenforcement" "7054" "lawenforcement.hot.coc.com" "LawEnforcementMSP" "admin" "admin"
enroll_identity "lawenforcement" "7054" "lawenforcement.hot.coc.com" "LawEnforcementMSP" "peer" "peer0.lawenforcement.hot.coc.com"

echo ""
echo "=== Enrolling ForensicLab Org ==="
enroll_identity "forensiclab" "8054" "forensiclab.hot.coc.com" "ForensicLabMSP" "admin" "admin"
enroll_identity "forensiclab" "8054" "forensiclab.hot.coc.com" "ForensicLabMSP" "peer" "peer0.forensiclab.hot.coc.com"

echo ""
echo "=== Enrolling Auditor Org ==="
enroll_identity "auditor" "9054" "auditor.cold.coc.com" "AuditorMSP" "admin" "admin"
enroll_identity "auditor" "9054" "auditor.cold.coc.com" "AuditorMSP" "peer" "peer0.auditor.cold.coc.com"

echo ""
echo "=== Enrolling Court Org (client-only) ==="
enroll_identity "court" "10054" "court.coc.com" "CourtMSP" "admin" "admin"
enroll_identity "court" "10054" "court.coc.com" "CourtMSP" "client" "court-client"

# ============================================================================
# Copy MSP config and create config.yaml
# ============================================================================

echo ""
echo "=== Setting up MSP configurations ==="

for ORG_DIR in $FABRIC_CA_CLIENT_HOME/peerOrganizations/*; do
    if [ -d "$ORG_DIR/msp" ]; then
        # Copy CA chain
        cp $ORG_DIR/msp/cacerts/* $ORG_DIR/msp/ca.crt
        cp $ORG_DIR/msp/cacerts/* $ORG_DIR/msp/tlscacerts/

        # Create config.yaml
        cat > $ORG_DIR/msp/config.yaml <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: orderer
EOF
    fi
done

for ORG_DIR in $FABRIC_CA_CLIENT_HOME/ordererOrganizations/*; do
    if [ -d "$ORG_DIR/msp" ]; then
        cp $ORG_DIR/msp/cacerts/* $ORG_DIR/msp/ca.crt
        cp $ORG_DIR/msp/cacerts/* $ORG_DIR/msp/tlscacerts/

        cat > $ORG_DIR/msp/config.yaml <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca.crt
    OrganizationalUnitIdentifier: orderer
EOF
    fi
done

echo ""
echo "==============================================================="
echo "✓ All identities enrolled with dynamic mTLS certificates"
echo "==============================================================="
echo ""
echo "Certificate chain:"
echo "  SGX Enclave Root CA → Fabric CA Intermediate → Identity Certs"
echo ""
echo "All components now have dynamically issued certificates!"
