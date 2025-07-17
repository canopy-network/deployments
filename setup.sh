#!/bin/bash
# This script builds a Canopy node.
echo "  ____    _    _   _  ___  ______   __"
echo " / ___|  / \  | \ | |/ _ \|  _ \ \ / /"
echo "| |     / _ \ |  \| | | | | |_) \ V / "
echo "| |___ / ___ \| |\  | |_| |  __/ | |  "
echo " \____/_/   \_\_| \_|\___/|_|    |_|  "
echo
echo "Welcome to Canopy setup!"
echo

CONFIG_FILE=config.env

# Default canopy branch to build, can be overridden in config file
BRANCH=beta-0.1.3

# Function to show current setup configuration
show_config() {
    echo "Loaded setup configuration:"
    echo
    echo "SETUP_TYPE: $SETUP_TYPE"
    echo "DOMAIN: $DOMAIN"
    echo "ACME_EMAIL: $ACME_EMAIL"
    echo "BRANCH: $BRANCH"
    echo
}

# Function to save config to a file
save_config() {
    echo "SETUP_TYPE=${SETUP_TYPE}" > "${CONFIG_FILE}"
    echo "DOMAIN=${DOMAIN}" >> "${CONFIG_FILE}"
    echo "ACME_EMAIL=${ACME_EMAIL}" >> "${CONFIG_FILE}"
    echo "BRANCH=${BRANCH}" >> "${CONFIG_FILE}"
    echo "Setup configuration saved to ${CONFIG_FILE}"
}
# Function to load config from a file
load_config() {
    config_file="${CONFIG_FILE}"
    if [[ -f "${config_file}" ]]; then
        source "${config_file}"
    else
        echo "Config file ${config_file} not found"
        return 1
    fi
}

if [[ -f "$CONFIG_FILE" ]]; then
    should_load_config() {
        # Auto-load if AUTOLOAD is present
        if grep -q "AUTOLOAD=yes\|AUTOLOAD=true" $CONFIG_FILE; then
            return 0
        fi
        # Ask user for confirmation
        read -p "$CONFIG_FILE found. Do you want to load the existing configuration? (Y/n): " LOAD_CONFIG
        echo
        [[ "$LOAD_CONFIG" != "n" && "$LOAD_CONFIG" != "N" ]]
    }
    if should_load_config; then
        load_config
        show_config
    fi
fi

# Function to read SETUP, DOMAIN and ACME_EMAIL configuration options from user
read_variables() {
    # Ask user for setup type
    echo "Please select setup type:"
    echo "1) simple (only contains the node containers)"
    echo "2) full (contains the node containers and the monitoring stack)"
    read -p "Enter your choice (1 or 2): " SETUP_CHOICE
    # Validate and set SETUP
    while [[ "$SETUP_CHOICE" != "1" && "$SETUP_CHOICE" != "2" ]]; do
        echo "Invalid choice. Please enter 1 for simple or 2 for full."
        read -p "Enter your choice (1 or 2): " SETUP_CHOICE
    done
    if [[ "$SETUP_CHOICE" == "1" ]]; then
        SETUP_TYPE="simple"
    else
        SETUP_TYPE="full"
    fi
    # Ask for domain input
    read -p "Please enter the domain [default: localhost]: " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        DOMAIN="localhost"
    fi
    # Ask for email input
    read -p "Please enter email to validate the domain against [default: test@example.com]: " ACME_EMAIL
    if [[ -z "$ACME_EMAIL" ]]; then
        ACME_EMAIL="test@example.com"
    fi
}

# Prompt user for variables if SETUP_TYPE is not present
if [[ -z "$SETUP_TYPE" ]]; then
    # Read variables from user
    read_variables
    # Save them to $CONFIG_FILE
    save_config
fi

# Remove any previous canopy-config container still around
docker stop canopy-config > /dev/null 2>&1
docker rm canopy-config > /dev/null 2>&1

echo "Setting up the validator key"
docker pull canopynetwork/canopy && \
docker run --user root -it -p 50000:50000 -p 50001:50001 -p 50002:50002 -p 50003:50003 -p 9001:9001 --name canopy-config  --volume ${PWD}/canopy_data/node1/:/root/.canopy/ canopynetwork/canopy && \
docker stop canopy-config && docker rm canopy-config && \
cp canopy_data/node1/validator_key.json canopy_data/node2/ && \
cp canopy_data/node1/keystore.json canopy_data/node2/

if [[ "$SETUP_TYPE" == "simple" ]]; then
  echo "setup complete ✅"
  exit 0
fi

STACK_PATH="$(realpath "$(dirname "$0")/monitoring-stack/")"

# define the path to the template and new .env file
ENV_TEMPLATE_FILE="$STACK_PATH/.env.template"
ENV_FILE="$STACK_PATH/.env"

# check if .env.template file exists
if [[ ! -f "$ENV_TEMPLATE_FILE" ]]; then
  echo ".env.template file not found, please create it with the default values from the repository."
    exit 1
fi

# perform sed substitution and create new .env file
if [[ -n "$DOMAIN" ]]; then
  sed -e "s/DOMAIN=.*/DOMAIN=$DOMAIN/" -e "s/ACME_EMAIL=.*/ACME_EMAIL=$ACME_EMAIL/" "$ENV_TEMPLATE_FILE" > "$ENV_FILE"
  echo "Created .env file with domain: $DOMAIN and email: $ACME_EMAIL"
else
  cp "$ENV_TEMPLATE_FILE" "$ENV_FILE"
  echo "Created .env file with default values"
fi

# perform the sed substitution for the traefik.yml
if [[ -n "$ACME_EMAIL" ]]; then
  TRAEFIK_PATH="$STACK_PATH/loadbalancer/traefik.yml"
  if grep -q "\${ACME_EMAIL}" "$TRAEFIK_PATH"; then
    echo "Replacing \${ACME_EMAIL} with $ACME_EMAIL in $TRAEFIK_PATH"
    sed -i "s|\${ACME_EMAIL}|$ACME_EMAIL|g" "$TRAEFIK_PATH"
  else
    echo "ACME_EMAIL already set."
  fi
fi

NODE1_CONFIG="$(realpath "$(dirname "$0")/canopy_data/node1/config.json")"
NODE2_CONFIG="$(realpath "$(dirname "$0")/canopy_data/node2/config.json")"

if [[ -n "$DOMAIN" ]]; then
  echo "Using domain: $DOMAIN"

  # Replace tcp URLs in node1 config
  if grep -q "tcp://node1.localhost" "$NODE1_CONFIG"; then
    echo "Replacing node1.localhost with node1.$DOMAIN"
    sed -i "s|tcp://node1.localhost|tcp://node1.$DOMAIN|g" "$NODE1_CONFIG"
  fi

  # Replace tcp URLs in node2 config
  if grep -q "tcp://node2.localhost" "$NODE2_CONFIG"; then
    echo "Replacing node2.localhost with node2.$DOMAIN"
    sed -i "s|tcp://node2.localhost|tcp://node2.$DOMAIN|g" "$NODE2_CONFIG"
  fi

  # Replace RPC and Admin RPC URLs for node1
  sed -i -E \
    -e "s|\"rpcURL\": *\"http://localhost:50002\"|\"rpcURL\": \"https://rpc.node1.$DOMAIN\"|" \
    -e "s|\"adminRPCUrl\": *\"http://localhost:50003\"|\"adminRPCUrl\": \"https://adminrpc.node1.$DOMAIN\"|" \
    "$NODE1_CONFIG"

  # Replace RPC and Admin RPC URLs for node2
  sed -i -E \
    -e "s|\"rpcURL\": *\"http://localhost:40002\"|\"rpcURL\": \"https://rpc.node2.$DOMAIN\"|" \
    -e "s|\"adminRPCUrl\": *\"http://localhost:40003\"|\"adminRPCUrl\": \"https://adminrpc.node2.$DOMAIN\"|" \
    "$NODE2_CONFIG"
fi

set -e


YAML_PATH="monitoring-stack/loadbalancer/services/middleware.yaml"

echo "Enter username:"
read USERNAME

echo "Enter password:"
read -s PASSWORD
echo

if ! command -v htpasswd &> /dev/null; then
  echo "Error: htpasswd not found. Please install apache2-utils."
  exit 1
fi

HTPASSWD_LINE=$(htpasswd -nbB "$USERNAME" "$PASSWORD")

# Escape $ for sed and wrap in quotes
ESCAPED_LINE=$(printf '%s' "$HTPASSWD_LINE" | sed 's/\$/\\\$/g')
# Use sed to replace the entire users list in the yaml
# This assumes your users list is indented exactly 8 spaces under users:
# and users: line is at indentation level 6 spaces.
# Adjust indentation accordingly if different.

# Wrap in quotes and indent with 8 spaces (adjust as needed)
FINAL_LINE="          - \"$ESCAPED_LINE\""

sed -i.bak -E "/basicAuth:/,/- /{
  /users:/ {
    N
    s|users:\n *-.*|users:\n$FINAL_LINE|
  }
}" "$YAML_PATH"

echo "Updated users list in $YAML_PATH"
echo "setup complete ✅"
echo

if [[ "$SETUP_TYPE" == "simple" ]]; then
    echo "These are your configured URLs:"
    echo
    echo http://wallet.node1.localhost/
    echo http://explorer.node1.localhost/
    echo http://rpc.node1.localhost/
    echo http://adminrpc.node1.localhost/
    echo
    echo http://wallet.node2.localhost/
    echo http://explorer.node2.localhost/
    echo http://rpc.node2.localhost/
    echo http://adminrpc.node2.localhost/
fi

if [[ "$SETUP_TYPE" == "full" ]]; then
    echo "These are your configured URLs:"
    echo
    echo http://wallet.node1.$DOMAIN/
    echo http://explorer.node1.$DOMAIN/
    echo http://rpc.node1.$DOMAIN/
    echo http://adminrpc.node1.$DOMAIN/
    echo
    echo http://wallet.node2.$DOMAIN/
    echo http://explorer.node2.$DOMAIN/
    echo http://rpc.node2.$DOMAIN/
    echo http://adminrpc.node2.$DOMAIN/
fi
