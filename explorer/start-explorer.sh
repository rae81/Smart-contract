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
