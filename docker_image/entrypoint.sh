#!/bin/sh

# Set default BIN_PATH if not provided
if [[ -z "${BIN_PATH}" ]]; then
    echo "BIN_PATH not provided, using /bin/cli as default"
    export BIN_PATH="/bin/cli"
else
    echo "Using existing BIN_PATH: ${BIN_PATH}"
fi

# Ensure canopy directory exists
mkdir -p /root/.canopy

# Handle CLI binary persistence
if [[ -f "/root/.canopy/cli" ]]; then
    echo "Found existing persistent CLI version"
else
    echo "Persisting build version for current CLI"
    if [[ -f "${BIN_PATH}" ]]; then
        mv "${BIN_PATH}" /root/.canopy/cli
    else
        echo "Error: Binary not found at ${BIN_PATH}" >&2
        exit 1
    fi
fi

# Create symlink
ln -s /root/.canopy/cli $BIN_PATH

# Execute main application
exec /app/canopy "$@"
