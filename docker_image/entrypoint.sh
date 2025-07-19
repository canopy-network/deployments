#!/bin/sh

# Set default BIN_PATH if not provided
if [[ -z "${BIN_PATH:-}" ]]; then
    echo "BIN_PATH not provided, using /bin/cli as default"
    export BIN_PATH="/bin/cli"
else
    echo "Using provided BIN_PATH: $BIN_PATH"
fi

# Ensure directory exists
mkdir -p /root/.canopy

# Handle CLI binary persistence
if [[ -f "/root/.canopy/cli" ]]; then
    echo "Found existing CLI version"
else
    echo "Persisting build version for current CLI"
    if [[ -f "$BIN_PATH" ]]; then
        mv "$BIN_PATH" /root/.canopy/cli
    else
        echo "ERROR: Source binary not found at $BIN_PATH" >&2
        exit 1
    fi
fi

# Clean up existing symlink and create new one
rm -f "$BIN_PATH"
ln -s /root/.canopy/cli "$BIN_PATH"

# Execute the main application
exec /app/canopy "$@"
