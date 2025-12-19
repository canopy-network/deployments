# install deps
echo "Install deps"
sudo docker plugin install  grafana/loki-docker-driver --alias loki

# Setup env keys

# Function to update Canopy config files with DOMAIN
update_canopy_config() {
  local domain="$1"
  local hostname="$2"
  
  if [ -z "$domain" ]; then
    echo "DOMAIN not provided, skipping config updates"
    return
  fi
  
  echo "Updating Canopy config files with DOMAIN: $domain"
  
  # Function to update config file
  update_config() {
    local config_file="$1"
    local node_name="$2"
    local port_suffix="$3"

    if [ -f "$config_file" ]; then
      echo "Updating $config_file for $node_name"

      # Replace any existing domain values with the new domain
      # This handles both localhost and existing domain values
      
      # Update RPC URLs - replace any existing domain with new domain
      sed -i "s|https://rpc\.[^/]*|https://rpc.${hostname}.${domain}|g" "$config_file"
      sed -i "s|http://rpc\.[^/]*|https://rpc.${hostname}.${domain}|g" "$config_file"
      sed -i "s|http://localhost:50002|https://rpc.${hostname}.${domain}|g" "$config_file"
      sed -i "s|http://localhost:40002|https://rpc.${hostname}.${domain}|g" "$config_file"

      # Update Admin RPC URLs - replace any existing domain with new domain
      sed -i "s|https://adminrpc\.[^/]*|https://adminrpc.${hostname}.${domain}|g" "$config_file"
      sed -i "s|http://adminrpc\.[^/]*|https://adminrpc.${hostname}.${domain}|g" "$config_file"
      sed -i "s|http://localhost:50003|https://adminrpc.${hostname}.${domain}|g" "$config_file"
      sed -i "s|http://localhost:40003|https://adminrpc.${hostname}.${domain}|g" "$config_file"

      # Update external addresses - replace any existing domain with new domain
      sed -i "s|tcp://[^/]*\.localhost|tcp://${hostname}.${domain}|g" "$config_file"
      sed -i "s|tcp://node1\.[^/]*|tcp://${hostname}.${domain}|g" "$config_file"
      sed -i "s|tcp://node2\.[^/]*|tcp://${hostname}.${domain}|g" "$config_file"

      echo "Updated $config_file successfully"
    else
      echo "Warning: Config file $config_file not found"
    fi
  }

  # Update node1 config
  update_config "canopy_data/node1/canopy/config.json" "node1" "500"

  # Update node2 config if it exists
  if [ -f "canopy_data/node2/canopy/config.json" ]; then
    update_config "canopy_data/node2/canopy/config.json" "node2" "400"
  fi

  echo "Canopy config files updated with DOMAIN: $domain"
}

# Check if .env file exists and load DOMAIN
if [ -f ".env" ]; then
  echo "Loading environment variables from .env file"
  export $(cat .env | grep -v '^#' | xargs)
  
  # Update Canopy configs if DOMAIN is set
  if [ ! -z "$DOMAIN" ]; then
    # Use hostname or default to 'node1' for setup
    HOSTNAME=${HOSTNAME:-node1}
    update_canopy_config "$DOMAIN" "$HOSTNAME"
  else
    echo "DOMAIN not found in .env file, skipping config updates"
  fi
else
  echo ".env file not found, skipping config updates"
fi

