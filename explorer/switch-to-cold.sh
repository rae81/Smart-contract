#!/bin/bash
# Switch Explorer to Cold Network
cat > config.json << 'INNER_EOF'
{
  "network-configs": {
    "cold-network": {
      "name": "Cold Blockchain Network",
      "profile": "./connection-profile/cold-network.json"
    },
    "hot-network": {
      "name": "Hot Blockchain Network",
      "profile": "./connection-profile/hot-network.json"
    }
  },
  "license": "Apache-2.0"
}
INNER_EOF
docker-compose -f docker-compose-explorer.yml restart explorer.mynetwork.com
echo "Switched to Cold Network. Wait 10 seconds then refresh browser."
