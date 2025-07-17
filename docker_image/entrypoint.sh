#!/bin/sh

# if BIN_PATH its defined we make a link to it from its volume to our system
if [[ -z "${BIN_PATH}" ]]; then
    echo "BIN_PATH not provided using /bin/cli as default"
    export BIN_PATH="/bin/cli"
else
    echo "using existing BIN_PATH $BIN_PATH"
    # if BIN_PATH it's no provided we sue '/bin/cli'
fi

# Persisting current version
# Check if it exist
if [ -f "/root/.canopy/cli" ]; then
  echo "Found existing persistent cli version"
else
  echo "Persisting build version for current cli"
  mv $BIN_PATH /root/.canopy/cli
fi
ln -s /root/.canopy/cli $BIN_PATH

exec /app/canopy "$@"
