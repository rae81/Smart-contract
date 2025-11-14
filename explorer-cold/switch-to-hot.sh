#!/bin/bash
# Switch Explorer to Hot Network
cat > config.json << 'INNER_EOF'
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
INNER_EOF
docker-compose -f docker-compose-explorer.yml restart explorer.mynetwork.com
echo "Switched to Hot Network. Wait 10 seconds then refresh browser."
