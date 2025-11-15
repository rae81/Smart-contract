# Deployment Next Steps

## Summary of Fixes Applied

The chaincode approval failures were caused by **MSP policy evaluation issues**. The configtx.yaml files defined policies requiring role-based identities (`.admin`, `.peer`, `.client`), but NodeOUs were not enabled, causing all identities to be generic "members" that couldn't satisfy these policies.

### Fixes Implemented:

1. **Enabled NodeOUs** for all organizations (Hot Orderer, Law Enforcement, Forensic Lab, Cold Orderer, Auditor)
2. **Fixed naming mismatch** - Renamed `archive.cold.coc.com` to `auditor.cold.coc.com` to match docker-compose and configtx.yaml
3. **Created CA certificate symlinks** - Added `ca-cert.pem` links in all cacerts directories to match NodeOU config references
4. **Updated MSP config.yaml** files with proper NodeOU role identifiers

## What You Need to Do Next

### Step 1: Restart Containers (REQUIRED)

The NodeOU configuration changes require a container restart:

```bash
cd ~/Dual-hyperledger-Blockchain
docker-compose -f docker-compose-hot.yml -f docker-compose-cold.yml restart
sleep 15  # Wait for containers to stabilize
```

Or use the provided script:

```bash
cd ~/Smart-contract
./scripts/restart-containers.sh
```

### Step 2: Verify Container Status

Check that all containers are running correctly:

```bash
cd ~/Dual-hyperledger-Blockchain
docker-compose -f docker-compose-hot.yml -f docker-compose-cold.yml ps
```

Expected output should show all containers in "Up" state.

### Step 3: Deploy Chaincode

After containers restart, deploy chaincode to both blockchains:

```bash
cd ~/Smart-contract
./scripts/deploy-all-chaincode.sh
```

This will:
1. Package chaincode for both hot and cold blockchains
2. Install on all peers (Law Enforcement, Forensic Lab, Auditor)
3. Approve for each organization
4. Commit to channels

### Step 4: Verify Deployment

Check that chaincode was committed successfully:

**Hot Blockchain:**
```bash
docker exec cli peer lifecycle chaincode querycommitted --channelID hotchannel --name dfir
```

**Cold Blockchain:**
```bash
docker exec cli-cold peer lifecycle chaincode querycommitted --channelID coldchannel --name audit
```

### Step 5: Test Transactions

Once chaincode is deployed, test basic operations:

**Hot Blockchain - Submit Evidence:**
```bash
docker exec cli peer chaincode invoke \
    -o orderer.hot.coc.com:7050 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/hot.coc.com/orderers/orderer.hot.coc.com/tls/ca.crt \
    -C hotchannel \
    -n dfir \
    -c '{"function":"SubmitEvidence","Args":["TEST001","testHash123","Device seizure","LAW001"]}'
```

**Cold Blockchain - Create Audit Record:**
```bash
docker exec cli-cold peer chaincode invoke \
    -o orderer.cold.coc.com:7150 \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/ordererOrganizations/cold.coc.com/orderers/orderer.cold.coc.com/tls/ca.crt \
    -C coldchannel \
    -n audit \
    -c '{"function":"LogAuditEvent","Args":["AUDIT001","Evidence submission","LAW001","Evidence TEST001 submitted"]}'
```

## Technical Explanation

### Root Cause

The error logs showed:
```
implicit policy evaluation failed - 0 sub-policies were satisfied,
but this policy requires 1 of the 'Readers' sub-policies to be satisfied
```

This occurred because:

1. **configtx.yaml** defined organization policies like:
   ```yaml
   Readers:
     Type: Signature
     Rule: "OR('LawEnforcementMSP.admin', 'LawEnforcementMSP.peer', 'LawEnforcementMSP.client')"
   ```

2. **Without NodeOUs**, peer certificates don't have role designations - they're just `LawEnforcementMSP.member`

3. **Policy evaluation failed** because the identity `LawEnforcementMSP.member` didn't match any of the required roles in the policy

### Solution

NodeOUs assign roles based on the OU (Organizational Unit) field in certificates:
- Certificates in `peers/` directory get the `.peer` role
- Certificates in `users/Admin@` directory get the `.admin` role
- Certificates in `users/User@` directory get the `.client` role

The `config.yaml` files configure how NodeOUs map certificate attributes to roles.

## Troubleshooting

### If Chaincode Approval Still Fails

1. **Check peer logs for policy errors:**
   ```bash
   docker logs peer0.lawenforcement.hot.coc.com 2>&1 | tail -50
   docker logs peer0.forensiclab.hot.coc.com 2>&1 | tail -50
   ```

2. **Verify NodeOU config is loaded:**
   ```bash
   docker exec cli peer channel getinfo -c hotchannel
   ```

3. **Check gossip communication:**
   Look for authentication errors between peers in logs

### If Containers Fail to Start

1. **Check for port conflicts:**
   ```bash
   docker ps -a
   netstat -tlnp | grep -E '(7050|7051|8051|9051|7150)'
   ```

2. **Review docker-compose logs:**
   ```bash
   docker-compose -f docker-compose-hot.yml logs orderer.hot.coc.com
   docker-compose -f docker-compose-hot.yml logs peer0.lawenforcement.hot.coc.com
   ```

## Files Modified

All changes are in the `/home/user/Dual-hyperledger-Blockchain` directory:

```
hot-blockchain/crypto-config/*/msp/config.yaml              (added NodeOU config)
hot-blockchain/crypto-config/*/cacerts/ca-cert.pem          (symlinks created)
cold-blockchain/crypto-config/*/msp/config.yaml             (added NodeOU config)
cold-blockchain/crypto-config/*/cacerts/ca-cert.pem         (symlinks created)
cold-blockchain/crypto-config/peerOrganizations/            (renamed archive → auditor)
```

## Repository Scripts

New scripts in `Smart-contract/scripts/`:
- `enable-nodeou.sh` - Creates NodeOU config.yaml files
- `fix-ca-cert-names.sh` - Creates ca-cert.pem symlinks
- `restart-containers.sh` - Restarts all containers
- `deploy-all-chaincode.sh` - Deploys chaincode to both blockchains
- `deploy-hot-chaincode.sh` - Hot blockchain only
- `deploy-cold-chaincode.sh` - Cold blockchain only

All changes have been committed to: `claude/dual-blockchain-mhz83hrxszs5xzzr-01KVuAGXoDLYAaEFYTTtR3PL`
