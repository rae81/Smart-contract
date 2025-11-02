#!/bin/bash
set -e

echo "======================================"
echo "Initializing PRV Service"
echo "======================================"

# Check if grpcurl is installed
if ! command -v grpcurl &> /dev/null; then
    echo "Installing grpcurl..."
    go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
    export PATH=$PATH:$HOME/go/bin
fi

echo ""
echo "Initializing PRV with default user roles..."
echo ""

grpcurl -plaintext -d '{
  "roles": [
    {
      "user_id": "admin001",
      "role": "admin",
      "clearance": 1
    },
    {
      "user_id": "inv001",
      "role": "investigator",
      "clearance": 2
    },
    {
      "user_id": "inv002",
      "role": "investigator",
      "clearance": 2
    },
    {
      "user_id": "inv003",
      "role": "investigator",
      "clearance": 2
    },
    {
      "user_id": "aud001",
      "role": "auditor",
      "clearance": 3
    },
    {
      "user_id": "aud002",
      "role": "auditor",
      "clearance": 3
    },
    {
      "user_id": "court001",
      "role": "court",
      "clearance": 4
    }
  ]
}' localhost:50051 dfir.prv.PRV/InitPRV

echo ""
echo "======================================"
echo "Initialization Complete!"
echo "======================================"
echo ""
echo "Initialized with 7 users:"
echo "  - admin001 (admin, clearance 1)"
echo "  - inv001-003 (investigator, clearance 2)"
echo "  - aud001-002 (auditor, clearance 3)"
echo "  - court001 (court, clearance 4)"
