#!/bin/bash
cd ~/Desktop/"files (1)"/explorer
docker-compose -f docker-compose-explorer.yml down -v
echo "✅ Explorer stopped"
