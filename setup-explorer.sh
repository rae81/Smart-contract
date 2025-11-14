#!/bin/bash
set -e

###############################################################################
# HYPERLEDGER EXPLORER SETUP
# Monitors both Hot and Cold blockchains
###############################################################################

echo "=============================================="
echo "  Hyperledger Explorer Setup"
echo "=============================================="
echo ""

cd ~/Desktop/"files (1)"

# Create explorer directory
echo "[1/8] Creating explorer directory..."
mkdir -p explorer
cd explorer

# Create docker-compose for Explorer
echo "[2/8] Creating docker-compose.yml..."
cat > docker-compose-explorer.yml << 'EXPLORER_COMPOSE'
version: '2.1'

networks:
  blockchain-network:
    external:
      name: files_1_blockchain-network

volumes:
  pgdata:
  walletstore:

services:
  explorerdb.mynetwork.com:
    image: hyperledger/explorer-db:latest
    container_name: explorerdb.mynetwork.com
    hostname: explorerdb.mynetwork.com
    environment:
      - DATABASE_DATABASE=fabricexplorer
      - DATABASE_USERNAME=hppoc
      - DATABASE_PASSWORD=password
    healthcheck:
      test: "pg_isready -h localhost -p 5432 -q -U postgres"
      interval: 30s
      timeout: 10s
      retries: 5
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - blockchain-network

  explorer.mynetwork.com:
    image: hyperledger/explorer:latest
    container_name: explorer.mynetwork.com
    hostname: explorer.mynetwork.com
    environment:
      - DATABASE_HOST=explorerdb.mynetwork.com
      - DATABASE_DATABASE=fabricexplorer
      - DATABASE_USERNAME=hppoc
      - DATABASE_PASSWD=password
      - LOG_LEVEL_APP=info
      - LOG_LEVEL_DB=info
      - LOG_LEVEL_CONSOLE=debug
      - LOG_CONSOLE_STDOUT=true
      - DISCOVERY_AS_LOCALHOST=false
    volumes:
      - ./config.json:/opt/explorer/app/platform/fabric/config.json
      - ./connection-profile:/opt/explorer/app/platform/fabric/connection-profile
      - ../hot-blockchain/crypto-config:/tmp/crypto
      - ../cold-blockchain/crypto-config:/tmp/crypto-cold
      - walletstore:/opt/explorer/wallet
    ports:
      - 8090:8080
    depends_on:
      explorerdb.mynetwork.com:
        condition: service_healthy
    networks:
      - blockchain-network
EXPLORER_COMPOSE

echo "✓ Docker compose created"

# Create Explorer configuration
echo "[3/8] Creating Explorer config.json..."
cat > config.json << 'CONFIG_JSON'
{
  "network-configs": {
    "hot-network": {
      "name": "Hot Blockchain Network",
      "profile": "./connection-profile/hot-network.json"
    },
    "cold-network": {
      "name": "Cold Blockchain Network",
      "profile": "./connection-profile/cold-network.json"
    }
  },
  "license": "Apache-2.0"
}
CONFIG_JSON

echo "✓ Config created"

# Create connection profiles directory
echo "[4/8] Creating connection profiles..."
mkdir -p connection-profile

# Hot blockchain connection profile
cat > connection-profile/hot-network.json << 'HOT_PROFILE'
{
  "name": "hot-network",
  "version": "1.0.0",
  "client": {
    "tlsEnable": true,
    "adminCredential": {
      "id": "exploreradmin",
      "password": "exploreradminpw"
    },
    "enableAuthentication": true,
    "organization": "LawEnforcementMSP",
    "connection": {
      "timeout": {
        "peer": {
          "endorser": "300"
        },
        "orderer": "300"
      }
    }
  },
  "channels": {
    "hotchannel": {
      "peers": {
        "peer0.lawenforcement.hot.coc.com": {},
        "peer0.forensiclab.hot.coc.com": {}
      }
    }
  },
  "organizations": {
    "LawEnforcementMSP": {
      "mspid": "LawEnforcementMSP",
      "adminPrivateKey": {
        "path": "/tmp/crypto/peerOrganizations/lawenforcement.hot.coc.com/users/Admin@lawenforcement.hot.coc.com/msp/keystore"
      },
      "peers": ["peer0.lawenforcement.hot.coc.com"],
      "signedCert": {
        "path": "/tmp/crypto/peerOrganizations/lawenforcement.hot.coc.com/users/Admin@lawenforcement.hot.coc.com/msp/signcerts"
      }
    },
    "ForensicLabMSP": {
      "mspid": "ForensicLabMSP",
      "adminPrivateKey": {
        "path": "/tmp/crypto/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp/keystore"
      },
      "peers": ["peer0.forensiclab.hot.coc.com"],
      "signedCert": {
        "path": "/tmp/crypto/peerOrganizations/forensiclab.hot.coc.com/users/Admin@forensiclab.hot.coc.com/msp/signcerts"
      }
    }
  },
  "peers": {
    "peer0.lawenforcement.hot.coc.com": {
      "tlsCACerts": {
        "path": "/tmp/crypto/peerOrganizations/lawenforcement.hot.coc.com/peers/peer0.lawenforcement.hot.coc.com/tls/ca.crt"
      },
      "url": "grpcs://peer0.lawenforcement.hot.coc.com:7051"
    },
    "peer0.forensiclab.hot.coc.com": {
      "tlsCACerts": {
        "path": "/tmp/crypto/peerOrganizations/forensiclab.hot.coc.com/peers/peer0.forensiclab.hot.coc.com/tls/ca.crt"
      },
      "url": "grpcs://peer0.forensiclab.hot.coc.com:8051"
    }
  }
}
HOT_PROFILE

# Cold blockchain connection profile
cat > connection-profile/cold-network.json << 'COLD_PROFILE'
{
  "name": "cold-network",
  "version": "1.0.0",
  "client": {
    "tlsEnable": true,
    "adminCredential": {
      "id": "exploreradmin",
      "password": "exploreradminpw"
    },
    "enableAuthentication": true,
    "organization": "ArchiveMSP",
    "connection": {
      "timeout": {
        "peer": {
          "endorser": "300"
        },
        "orderer": "300"
      }
    }
  },
  "channels": {
    "coldchannel": {
      "peers": {
        "peer0.archive.cold.coc.com": {}
      }
    }
  },
  "organizations": {
    "ArchiveMSP": {
      "mspid": "ArchiveMSP",
      "adminPrivateKey": {
        "path": "/tmp/crypto-cold/peerOrganizations/archive.cold.coc.com/users/Admin@archive.cold.coc.com/msp/keystore"
      },
      "peers": ["peer0.archive.cold.coc.com"],
      "signedCert": {
        "path": "/tmp/crypto-cold/peerOrganizations/archive.cold.coc.com/users/Admin@archive.cold.coc.com/msp/signcerts"
      }
    }
  },
  "peers": {
    "peer0.archive.cold.coc.com": {
      "tlsCACerts": {
        "path": "/tmp/crypto-cold/peerOrganizations/archive.cold.coc.com/peers/peer0.archive.cold.coc.com/tls/ca.crt"
      },
      "url": "grpcs://peer0.archive.cold.coc.com:9051"
    }
  }
}
COLD_PROFILE

echo "✓ Connection profiles created"

# Create start script
echo "[5/8] Creating start script..."
cat > start-explorer.sh << 'START_SCRIPT'
#!/bin/bash
set -e

echo "Starting Hyperledger Explorer..."
cd ~/Desktop/"files (1)"/explorer

# Start Explorer services
docker-compose -f docker-compose-explorer.yml up -d

echo ""
echo "Waiting for Explorer to initialize..."
sleep 15

echo ""
echo "=============================================="
echo "✅ Hyperledger Explorer Started!"
echo "=============================================="
echo ""
echo "Access Explorer at: http://localhost:8090"
echo ""
echo "Default credentials:"
echo "  Username: exploreradmin"
echo "  Password: exploreradminpw"
echo ""
echo "Monitoring:"
echo "  - Hot Blockchain (hotchannel)"
echo "  - Cold Blockchain (coldchannel)"
echo ""
START_SCRIPT

chmod +x start-explorer.sh

# Create stop script
echo "[6/8] Creating stop script..."
cat > stop-explorer.sh << 'STOP_SCRIPT'
#!/bin/bash
cd ~/Desktop/"files (1)"/explorer
docker-compose -f docker-compose-explorer.yml down -v
echo "✅ Explorer stopped"
STOP_SCRIPT

chmod +x stop-explorer.sh

# Create README
echo "[7/8] Creating README..."
cat > README.md << 'README'
# Hyperledger Explorer - Blockchain Visualization

## 🌐 Access Explorer

**URL:** http://localhost:8090

**Credentials:**
- Username: `exploreradmin`
- Password: `exploreradminpw`

## 🚀 Start Explorer

```bash
cd ~/Desktop/"files (1)"/explorer
./start-explorer.sh
```

## 🛑 Stop Explorer

```bash
cd ~/Desktop/"files (1)"/explorer
./stop-explorer.sh
```

## 📊 What You Can See

### Hot Blockchain Dashboard
- **Channel:** hotchannel
- **Organizations:** Law Enforcement, Forensic Lab
- **Blocks:** Real-time block creation
- **Transactions:** Evidence creation, custody transfers
- **Chaincode:** dfir v1.0

### Cold Blockchain Dashboard
- **Channel:** coldchannel
- **Organizations:** Archive
- **Blocks:** Archived evidence records
- **Transactions:** Case archival events

## 🔍 Features

- **Block Explorer:** View all blocks and transactions
- **Transaction Details:** See transaction payloads and metadata
- **Chaincode Info:** Installed and instantiated chaincodes
- **Peer Status:** Monitor peer health and sync status
- **Network Metrics:** Transaction per second, block height
- **Search:** Find blocks, transactions, or addresses

## 🔧 Troubleshooting

### Explorer won't start
```bash
# Check if ports are available
sudo lsof -i :8090

# Check Explorer logs
docker logs explorer.mynetwork.com
docker logs explorerdb.mynetwork.com
```

### Can't connect to blockchain
```bash
# Verify blockchains are running
docker ps | grep peer

# Check Explorer can access peers
docker exec explorer.mynetwork.com ping peer0.lawenforcement.hot.coc.com
```

### Database errors
```bash
# Reset database
cd ~/Desktop/"files (1)"/explorer
docker-compose -f docker-compose-explorer.yml down -v
docker volume rm explorer_pgdata
./start-explorer.sh
```
README

echo "✓ Documentation created"

echo "[8/8] Starting Explorer..."
./start-explorer.sh

echo ""
echo "=============================================="
echo "✅ EXPLORER SETUP COMPLETE!"
echo "=============================================="
echo ""
echo "📊 Access Explorer:"
echo "   URL: http://localhost:8090"
echo "   Username: exploreradmin"
echo "   Password: exploreradminpw"
echo ""
echo "🔍 What to do next:"
echo "   1. Open http://localhost:8090 in browser"
echo "   2. Login with credentials above"
echo "   3. Select 'hot-network' to view Hot blockchain"
echo "   4. Select 'cold-network' to view Cold blockchain"
echo ""
