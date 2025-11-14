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
