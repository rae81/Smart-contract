#!/bin/bash

echo "==========================================="
echo "   Safely Shutting Down Blockchain System"
echo "==========================================="
echo ""

# 1. Stop Flask web application
echo "📊 Stopping Flask web application..."
pkill -f "python3 app.py" 2>/dev/null
echo "✓ Flask stopped"

# 2. Stop Hot Blockchain
echo "🔥 Stopping Hot Blockchain..."
docker-compose -f docker-compose-hot.yml down
echo "✓ Hot blockchain stopped"

# 3. Stop Cold Blockchain
echo "❄️  Stopping Cold Blockchain..."
docker-compose -f docker-compose-cold.yml down
echo "✓ Cold blockchain stopped"

# 4. Stop Storage Services (IPFS + MySQL)
echo "📦 Stopping Storage Services..."
docker-compose -f docker-compose-storage.yml down
echo "✓ Storage services stopped"

# 5. Verify all containers are stopped
echo ""
echo "Verifying shutdown..."
remaining=$(docker ps -q | wc -l)
if [ "$remaining" -eq "0" ]; then
    echo "✅ All containers stopped successfully!"
else
    echo "⚠️  Warning: $remaining containers still running"
    docker ps
fi

echo ""
echo "==========================================="
echo "   System Shutdown Complete"
echo "==========================================="
echo ""
echo "To restart tomorrow, run: ./startup-blockchain.sh"
