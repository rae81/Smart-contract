#!/bin/bash

echo "=========================================="
echo "Creating Channels for Fabric 2.5"
echo "=========================================="

# Get the actual current directory
WORK_DIR="$(pwd)"
echo "Working directory: $WORK_DIR"

# Generate Hot Channel Genesis Block
echo "Generating Hot Channel genesis block..."
export FABRIC_CFG_PATH="$WORK_DIR/hot-blockchain"
"$WORK_DIR/fabric-samples/bin/configtxgen" \
  -profile HotChainChannel \
  -outputBlock "$WORK_DIR/hot-blockchain/channel-artifacts/hotchannel.block" \
  -channelID hotchannel

if [ -f "$WORK_DIR/hot-blockchain/channel-artifacts/hotchannel.block" ]; then
    echo "✅ Hot channel genesis block created!"
else
    echo "❌ Failed to create hot channel genesis block"
    exit 1
fi

# Generate Cold Channel Genesis Block
echo "Generating Cold Channel genesis block..."
export FABRIC_CFG_PATH="$WORK_DIR/cold-blockchain"
"$WORK_DIR/fabric-samples/bin/configtxgen" \
  -profile ColdChainChannel \
  -outputBlock "$WORK_DIR/cold-blockchain/channel-artifacts/coldchannel.block" \
  -channelID coldchannel

if [ -f "$WORK_DIR/cold-blockchain/channel-artifacts/coldchannel.block" ]; then
    echo "✅ Cold channel genesis block created!"
else
    echo "❌ Failed to create cold channel genesis block"
    exit 1
fi

echo ""
echo "Channel blocks created successfully!"
echo "Now joining peers to channels..."
echo ""

# Copy genesis blocks to CLI containers
echo "Copying hot channel block to CLI container..."
docker cp "$WORK_DIR/hot-blockchain/channel-artifacts/hotchannel.block" cli:/opt/gopath/src/github.com/hyperledger/fabric/peer/

echo "Copying cold channel block to CLI-COLD container..."
docker cp "$WORK_DIR/cold-blockchain/channel-artifacts/coldchannel.block" cli-cold:/opt/gopath/src/github.com/hyperledger/fabric/peer/

# Join Hot Channel to Orderer using osnadmin
echo "Joining Hot Channel to orderer..."
docker exec cli osnadmin channel join \
  --channelID hotchannel \
  --config-block /opt/gopath/src/github.com/hyperledger/fabric/peer/hotchannel.block \
  -o orderer.hot.coc.com:7053 \
  --ca-file /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/ca.crt \
  --client-cert /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/server.crt \
  --client-key /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/server.key

# Join Law Enforcement peer to Hot Channel
echo "Joining Law Enforcement peer to Hot Channel..."
docker exec cli peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/hotchannel.block

# Join Forensic Lab peer to Hot Channel
echo "Joining Forensic Lab peer to Hot Channel..."
docker exec cli bash -c "
  export CORE_PEER_ADDRESS=peer0.forensiclab.hot.coc.com:8051
  export CORE_PEER_LOCALMSPID=ForensicLabMSP
  export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp
  peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/hotchannel.block
"

# Join Cold Channel to Orderer
echo "Joining Cold Channel to orderer..."
docker exec cli-cold osnadmin channel join \
  --channelID coldchannel \
  --config-block /opt/gopath/src/github.com/hyperledger/fabric/peer/coldchannel.block \
  -o orderer.cold.coc.com:7153 \
  --ca-file /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/ca.crt \
  --client-cert /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/server.crt \
  --client-key /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/server.key

# Join Archive peer to Cold Channel
echo "Joining Archive peer to Cold Channel..."
docker exec cli-cold peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/coldchannel.block

echo ""
echo "=========================================="
echo "✅ CHANNELS CREATED SUCCESSFULLY!"
echo "=========================================="

# Verify channels
echo ""
echo "Hot Blockchain Channels:"
docker exec cli peer channel list

echo ""
echo "Cold Blockchain Channels:"
docker exec cli-cold peer channel list

echo ""
echo "✅ Setup complete!"
