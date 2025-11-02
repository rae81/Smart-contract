#!/bin/bash
set -e

echo "======================================"
echo "Building PRV Service"
echo "======================================"

cd "$(dirname "$0")/.."

echo ""
echo "Step 1: Check protoc installation..."
if ! command -v protoc &> /dev/null; then
    echo "✗ protoc not found"
    echo ""
    echo "Install with:"
    echo "  sudo apt-get install protobuf-compiler"
    echo "  go install google.golang.org/protobuf/cmd/protoc-gen-go@latest"
    echo "  go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest"
    exit 1
fi

echo "✓ protoc found: $(protoc --version)"

echo ""
echo "Step 2: Generate gRPC code..."
protoc --go_out=. --go_opt=paths=source_relative \
       --go-grpc_out=. --go-grpc_opt=paths=source_relative \
       prv.proto

if [ -f "prv.pb.go" ] && [ -f "prv_grpc.pb.go" ]; then
    echo "✓ gRPC code generated"
else
    echo "✗ gRPC code generation failed"
    exit 1
fi

echo ""
echo "Step 3: Download Go dependencies..."
go mod download
go mod tidy

echo ""
echo "Step 4: Build PRV service..."
go build -o prv-service main.go prv.pb.go prv_grpc.pb.go

if [ -f "prv-service" ]; then
    echo "✓ PRV service built successfully"
    echo ""
    echo "Binary: $(pwd)/prv-service"
    echo "Size: $(du -h prv-service | cut -f1)"
    echo ""
    echo "Run with: ./prv-service"
else
    echo "✗ Build failed"
    exit 1
fi

echo ""
echo "======================================"
echo "Build Complete!"
echo "======================================"
