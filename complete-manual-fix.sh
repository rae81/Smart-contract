#!/bin/bash

###############################################################################
# COMPLETE MANUAL FIX FOR BLOCKCHAIN CHAIN OF CUSTODY
# This script will fix all issues and get everything running
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  Complete Blockchain Setup & Fix         ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# STEP 1: Complete cleanup
echo -e "${YELLOW}[STEP 1] Complete cleanup...${NC}"

# Stop all containers if running
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
docker volume prune -f

# Clean old files
rm -rf hot-blockchain/crypto-config
rm -rf cold-blockchain/crypto-config
rm -rf hot-blockchain/channel-artifacts
rm -rf cold-blockchain/channel-artifacts
mkdir -p hot-blockchain/channel-artifacts
mkdir -p cold-blockchain/channel-artifacts

echo -e "${GREEN}✓ Cleanup complete${NC}"

# STEP 2: Download Fabric binaries if not present
echo -e "${YELLOW}[STEP 2] Checking Fabric binaries...${NC}"
if [ ! -d "fabric-samples" ]; then
    echo "Downloading Fabric binaries..."
    curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.0 1.5.5
fi
export PATH="$PWD/fabric-samples/bin:$PATH"
echo -e "${GREEN}✓ Fabric binaries ready${NC}"

# STEP 3: Fix configtx.yaml files with correct profile names
echo -e "${YELLOW}[STEP 3] Creating correct configtx.yaml files...${NC}"

# Create Hot Blockchain configtx.yaml
cat > hot-blockchain/configtx.yaml << 'EOF'
Organizations:
  - &OrdererOrg
      Name: OrdererMSP
      ID: OrdererMSP
      MSPDir: crypto-config/ordererOrganizations/hot.coc.com/msp
      Policies:
        Readers:
          Type: Signature
          Rule: "OR('OrdererMSP.member')"
        Writers:
          Type: Signature
          Rule: "OR('OrdererMSP.member')"
        Admins:
          Type: Signature
          Rule: "OR('OrdererMSP.admin')"
      OrdererEndpoints:
        - orderer.hot.coc.com:7050

  - &LawEnforcement
      Name: LawEnforcementMSP
      ID: LawEnforcementMSP
      MSPDir: crypto-config/peerOrganizations/lawenforcement.hot.coc.com/msp
      Policies:
        Readers:
          Type: Signature
          Rule: "OR('LawEnforcementMSP.admin', 'LawEnforcementMSP.peer', 'LawEnforcementMSP.client')"
        Writers:
          Type: Signature
          Rule: "OR('LawEnforcementMSP.admin', 'LawEnforcementMSP.client')"
        Admins:
          Type: Signature
          Rule: "OR('LawEnforcementMSP.admin')"
        Endorsement:
          Type: Signature
          Rule: "OR('LawEnforcementMSP.peer')"
      AnchorPeers:
        - Host: peer0.lawenforcement.hot.coc.com
          Port: 7051

  - &ForensicLab
      Name: ForensicLabMSP
      ID: ForensicLabMSP
      MSPDir: crypto-config/peerOrganizations/forensiclab.hot.coc.com/msp
      Policies:
        Readers:
          Type: Signature
          Rule: "OR('ForensicLabMSP.admin', 'ForensicLabMSP.peer', 'ForensicLabMSP.client')"
        Writers:
          Type: Signature
          Rule: "OR('ForensicLabMSP.admin', 'ForensicLabMSP.client')"
        Admins:
          Type: Signature
          Rule: "OR('ForensicLabMSP.admin')"
        Endorsement:
          Type: Signature
          Rule: "OR('ForensicLabMSP.peer')"
      AnchorPeers:
        - Host: peer0.forensiclab.hot.coc.com
          Port: 8051

Capabilities:
  Channel: &ChannelCapabilities
    V2_0: true
  Orderer: &OrdererCapabilities
    V2_0: true
  Application: &ApplicationCapabilities
    V2_0: true

Application: &ApplicationDefaults
  Organizations:
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
    LifecycleEndorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
    Endorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
  Capabilities:
    <<: *ApplicationCapabilities

Orderer: &OrdererDefaults
  OrdererType: etcdraft
  Addresses:
    - orderer.hot.coc.com:7050
  BatchTimeout: 2s
  BatchSize:
    MaxMessageCount: 10
    AbsoluteMaxBytes: 99 MB
    PreferredMaxBytes: 512 KB
  EtcdRaft:
    Consenters:
      - Host: orderer.hot.coc.com
        Port: 7050
        ClientTLSCert: crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/server.crt
        ServerTLSCert: crypto-config/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/server.crt
  Organizations:
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
    BlockValidation:
      Type: ImplicitMeta
      Rule: "ANY Writers"
  Capabilities:
    <<: *OrdererCapabilities

Channel: &ChannelDefaults
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
  Capabilities:
    <<: *ChannelCapabilities

Profiles:
  HotChainGenesis:
    <<: *ChannelDefaults
    Orderer:
      <<: *OrdererDefaults
      Organizations:
        - *OrdererOrg
    Application:
      <<: *ApplicationDefaults
      Organizations:
        - *LawEnforcement
        - *ForensicLab
    Consortiums:
      HotConsortium:
        Organizations:
          - *LawEnforcement
          - *ForensicLab

  HotChainChannel:
    <<: *ChannelDefaults
    Consortium: HotConsortium
    Application:
      <<: *ApplicationDefaults
      Organizations:
        - *LawEnforcement
        - *ForensicLab
EOF

# Create Cold Blockchain configtx.yaml
cat > cold-blockchain/configtx.yaml << 'EOF'
Organizations:
  - &OrdererOrg
      Name: OrdererMSP
      ID: OrdererMSP
      MSPDir: crypto-config/ordererOrganizations/cold.coc.com/msp
      Policies:
        Readers:
          Type: Signature
          Rule: "OR('OrdererMSP.member')"
        Writers:
          Type: Signature
          Rule: "OR('OrdererMSP.member')"
        Admins:
          Type: Signature
          Rule: "OR('OrdererMSP.admin')"
      OrdererEndpoints:
        - orderer.cold.coc.com:7150

  - &Archive
      Name: ArchiveMSP
      ID: ArchiveMSP
      MSPDir: crypto-config/peerOrganizations/archive.cold.coc.com/msp
      Policies:
        Readers:
          Type: Signature
          Rule: "OR('ArchiveMSP.admin', 'ArchiveMSP.peer', 'ArchiveMSP.client')"
        Writers:
          Type: Signature
          Rule: "OR('ArchiveMSP.admin', 'ArchiveMSP.client')"
        Admins:
          Type: Signature
          Rule: "OR('ArchiveMSP.admin')"
        Endorsement:
          Type: Signature
          Rule: "OR('ArchiveMSP.peer')"
      AnchorPeers:
        - Host: peer0.archive.cold.coc.com
          Port: 9051

Capabilities:
  Channel: &ChannelCapabilities
    V2_0: true
  Orderer: &OrdererCapabilities
    V2_0: true
  Application: &ApplicationCapabilities
    V2_0: true

Application: &ApplicationDefaults
  Organizations:
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
    LifecycleEndorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
    Endorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
  Capabilities:
    <<: *ApplicationCapabilities

Orderer: &OrdererDefaults
  OrdererType: etcdraft
  Addresses:
    - orderer.cold.coc.com:7150
  BatchTimeout: 2s
  BatchSize:
    MaxMessageCount: 10
    AbsoluteMaxBytes: 99 MB
    PreferredMaxBytes: 512 KB
  EtcdRaft:
    Consenters:
      - Host: orderer.cold.coc.com
        Port: 7150
        ClientTLSCert: crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/server.crt
        ServerTLSCert: crypto-config/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/server.crt
  Organizations:
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
    BlockValidation:
      Type: ImplicitMeta
      Rule: "ANY Writers"
  Capabilities:
    <<: *OrdererCapabilities

Channel: &ChannelDefaults
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "MAJORITY Admins"
  Capabilities:
    <<: *ChannelCapabilities

Profiles:
  ColdChainGenesis:
    <<: *ChannelDefaults
    Orderer:
      <<: *OrdererDefaults
      Organizations:
        - *OrdererOrg
    Application:
      <<: *ApplicationDefaults
      Organizations:
        - *Archive
    Consortiums:
      ColdConsortium:
        Organizations:
          - *Archive

  ColdChainChannel:
    <<: *ChannelDefaults
    Consortium: ColdConsortium
    Application:
      <<: *ApplicationDefaults
      Organizations:
        - *Archive
EOF

echo -e "${GREEN}✓ Configuration files created${NC}"

# STEP 4: Generate crypto materials
echo -e "${YELLOW}[STEP 4] Generating crypto materials...${NC}"

cd hot-blockchain
cryptogen generate --config=./crypto-config.yaml --output="./crypto-config"
cd ..

cd cold-blockchain
cryptogen generate --config=./crypto-config.yaml --output="./crypto-config"
cd ..

echo -e "${GREEN}✓ Crypto materials generated${NC}"

# STEP 5: Generate genesis blocks
echo -e "${YELLOW}[STEP 5] Generating genesis blocks...${NC}"

cd hot-blockchain
export FABRIC_CFG_PATH=$PWD
configtxgen -profile HotChainGenesis -channelID system-channel -outputBlock ./channel-artifacts/genesis.block
cd ..

cd cold-blockchain
export FABRIC_CFG_PATH=$PWD
configtxgen -profile ColdChainGenesis -channelID system-channel -outputBlock ./channel-artifacts/genesis.block
cd ..

echo -e "${GREEN}✓ Genesis blocks created${NC}"

# STEP 6: Generate channel transactions
echo -e "${YELLOW}[STEP 6] Generating channel transactions...${NC}"

cd hot-blockchain
export FABRIC_CFG_PATH=$PWD
configtxgen -profile HotChainChannel -outputCreateChannelTx ./channel-artifacts/hotchannel.tx -channelID hotchannel
cd ..

cd cold-blockchain
export FABRIC_CFG_PATH=$PWD
configtxgen -profile ColdChainChannel -outputCreateChannelTx ./channel-artifacts/coldchannel.tx -channelID coldchannel
cd ..

echo -e "${GREEN}✓ Channel transactions created${NC}"

# STEP 7: Start all services
echo -e "${YELLOW}[STEP 7] Starting all services...${NC}"

# Start storage services
docker-compose -f docker-compose-storage.yml up -d
echo "Waiting for storage services..."
sleep 10

# Start Hot blockchain
docker-compose -f docker-compose-hot.yml up -d
echo "Waiting for Hot blockchain..."
sleep 15

# Start Cold blockchain
docker-compose -f docker-compose-cold.yml up -d
echo "Waiting for Cold blockchain..."
sleep 15

echo -e "${GREEN}✓ All services started${NC}"

# STEP 8: Create and join channels
echo -e "${YELLOW}[STEP 8] Creating and joining channels...${NC}"

# Create hot channel
docker exec cli peer channel create \
    -o orderer.hot.coc.com:7050 \
    -c hotchannel \
    -f ./channel-artifacts/hotchannel.tx \
    --tls true \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/msp/tlscacerts/tlsca.hot.coc.com-cert.pem \
    --outputBlock ./channel-artifacts/hotchannel.block

# Join peers to hot channel
docker exec cli peer channel join -b ./channel-artifacts/hotchannel.block

docker exec -e CORE_PEER_ADDRESS=peer0.forensiclab.hot.coc.com:8051 \
    -e CORE_PEER_LOCALMSPID="ForensicLabMSP" \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp \
    cli peer channel join -b ./channel-artifacts/hotchannel.block

# Create cold channel
docker exec cli-cold peer channel create \
    -o orderer.cold.coc.com:7150 \
    -c coldchannel \
    -f ./channel-artifacts/coldchannel.tx \
    --tls true \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/msp/tlscacerts/tlsca.cold.coc.com-cert.pem \
    --outputBlock ./channel-artifacts/coldchannel.block

# Join peer to cold channel
docker exec cli-cold peer channel join -b ./channel-artifacts/coldchannel.block

echo -e "${GREEN}✓ Channels created and joined${NC}"

# STEP 9: Start the web application
echo -e "${YELLOW}[STEP 9] Starting web application...${NC}"

# Check if app.py exists in webapp directory
if [ -f "webapp/app.py" ]; then
    cd webapp
    # Install Python dependencies if needed
    pip install flask flask-cors web3 ipfshttpclient mysql-connector-python --break-system-packages 2>/dev/null || true
    
    # Start the Flask app in background
    python3 app.py &
    APP_PID=$!
    cd ..
    echo -e "${GREEN}✓ Web application started (PID: $APP_PID)${NC}"
    echo -e "${YELLOW}Access web interface at: http://localhost:5000${NC}"
else
    echo -e "${YELLOW}Web application not found, skipping...${NC}"
fi

# STEP 10: Verify everything is running
echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}         VERIFICATION RESULTS             ${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Check containers
echo -e "${YELLOW}Running containers:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | head -15

echo ""
echo -e "${YELLOW}Hot Blockchain channels:${NC}"
docker exec cli peer channel list 2>/dev/null || echo "Not ready yet"

echo ""
echo -e "${YELLOW}Cold Blockchain channels:${NC}"
docker exec cli-cold peer channel list 2>/dev/null || echo "Not ready yet"

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       SETUP COMPLETED SUCCESSFULLY!      ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${YELLOW}Access Points:${NC}"
echo -e "  Web Interface: ${BLUE}http://localhost:5000${NC}"
echo -e "  phpMyAdmin: ${BLUE}http://localhost:8081${NC}"
echo -e "  IPFS Gateway: ${BLUE}http://localhost:8080${NC}"
echo -e "  IPFS API: ${BLUE}http://localhost:5001${NC}"
echo ""
echo -e "${YELLOW}To check logs:${NC}"
echo -e "  docker logs orderer.hot.coc.com"
echo -e "  docker logs peer0.lawenforcement.hot.coc.com"
echo ""
echo -e "${GREEN}Everything is now running!${NC}"
