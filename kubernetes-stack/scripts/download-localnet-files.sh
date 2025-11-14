#!/bin/bash

# Script to download localnet files from Canopy repository
# Files from: https://github.com/canopy-network/canopy/tree/main/.docker/volumes

set -e

REPO_URL="https://raw.githubusercontent.com/canopy-network/canopy/main/.docker/volumes"
LOCAL_DIR="../localnet-files"

echo "📥 Downloading localnet files from Canopy repository..."

# Create directory if it doesn't exist
mkdir -p "$LOCAL_DIR"

# Download files for each node (node1, node2, node3)
for node_num in 1 2 3; do
    echo "Downloading files for node${node_num}..."
    
    # Download genesis.json (same for all nodes)
    if [ "$node_num" == "1" ]; then
        curl -s -o "$LOCAL_DIR/genesis.json" "$REPO_URL/node${node_num}/genesis.json" || {
            echo "⚠️  Warning: Could not download genesis.json, using fallback"
        }
    fi
    
    # Download validator_key.json for each node
    curl -s -o "$LOCAL_DIR/node${node_num}_validator_key.json" "$REPO_URL/node${node_num}/validator_key.json" || {
        echo "⚠️  Warning: Could not download validator_key.json for node${node_num}"
    }
    
    # Download keystore.json for each node
    curl -s -o "$LOCAL_DIR/node${node_num}_keystore.json" "$REPO_URL/node${node_num}/keystore.json" || {
        echo "⚠️  Warning: Could not download keystore.json for node${node_num}"
    }
    
    # Download config.json for each node (if available)
    curl -s -o "$LOCAL_DIR/node${node_num}_config.json" "$REPO_URL/node${node_num}/config.json" || {
        echo "ℹ️  Info: config.json not found for node${node_num}, will use template"
    }
done

echo "✅ Download complete!"
echo "Files downloaded to: $LOCAL_DIR"
echo ""
echo "Files:"
ls -lh "$LOCAL_DIR" || true

