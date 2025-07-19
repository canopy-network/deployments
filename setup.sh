#!/bin/bash
# This script builds a Canopy node.
echo "  ____    _    _   _  ___  ______   __"
echo " / ___|  / \  | \ | |/ _ \|  _ \ \ / /"
echo "| |     / _ \ |  \| | | | | |_) \ V / "
echo "| |___ / ___ \| |\  | |_| |  __/ | |  "
echo " \____/_/   \_\_| \_|\___/|_|    |_|  "
echo
echo "Welcome to Canopy Setup!"
echo

CONFIG_FILE=setup.conf

# Default canopy branch to build, can be overridden in config file
BRANCH=latest

# Read configuration file, if available
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"

    echo "Loaded setup configuration:"
    echo
    echo "SETUP_TYPE: $SETUP_TYPE"
    echo "DOMAIN: $DOMAIN"
    echo "ACME_EMAIL: $ACME_EMAIL"
    echo "BRANCH: $BRANCH"
    echo "HTPASSWD: $HTPASSWD"
    echo
fi

# SETUP_TYPE is not present, request from user
if [[ -z "$SETUP_TYPE" ]]; then
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
fi

# DOMAIN not present, request from user
if [[ -z "$DOMAIN" ]]; then
    # Ask for domain input
    read -p "Please enter the domain [default: localhost]: " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        DOMAIN="localhost"
    fi
fi

# ACME_EMAIL not present, request from user
if [[ -z "$ACME_EMAIL" ]]; then
    # Ask for email input
    read -p "Please enter email to validate the domain against [default: test@example.com]: " ACME_EMAIL
    if [[ -z "$ACME_EMAIL" ]]; then
        ACME_EMAIL="test@example.com"
    fi
fi

# BRANCH not present, request from user
if [[ -z "$BRANCH" ]]; then
    read -p "Enter canopy git branch [default: latest]: " BRANCH
    if [[ -z "$BRANCH" ]]; then
        BRANCH=latest
    fi
fi

# Remove any previous canopy-config container still around
docker stop canopy-config > /dev/null 2>&1
docker rm canopy-config > /dev/null 2>&1

echo "Setting up the validator key"
echo

docker pull canopynetwork/canopy && \
    docker run --user root -it -p 50000:50000 -p 50001:50001 -p 50002:50002 -p 50003:50003 -p 9001:9001 --name canopy-config  --volume ${PWD}/canopy_data/node1/:/root/.canopy/ canopynetwork/canopy && \
    cp canopy_data/node1/validator_key.json canopy_data/node2/ && \
    cp canopy_data/node1/keystore.json canopy_data/node2/

# Remove any previous canopy-config container still around
docker stop canopy-config > /dev/null 2>&1
docker rm canopy-config > /dev/null 2>&1

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
    echo "Replacing node1.localhost with $DOMAIN"
    sed -i "s|tcp://node1.localhost|tcp://$DOMAIN|g" "$NODE1_CONFIG"
  fi

  # Replace tcp URLs in node2 config
  if grep -q "tcp://node2.localhost" "$NODE2_CONFIG"; then
    echo "Replacing node2.localhost with $DOMAIN"
    sed -i "s|tcp://node2.localhost|tcp://$DOMAIN|g" "$NODE2_CONFIG"
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

# HTPASSWD not present, ask user for credentials and construct it
if [[ -z "$HTPASSWD" ]]; then
    echo "Enter username for htpasswd:"
    read USERNAME

    echo "Enter password for htpasswd:"
    read -s PASSWORD
    echo

    if ! command -v htpasswd &> /dev/null; then
        echo "Error: htpasswd not found. Please install apache2-utils."
        exit 1
    fi

    HTPASSWD=$(htpasswd -nbB "$USERNAME" "$PASSWORD")
fi

# Escape $ for sed and wrap in quotes
ESCAPED_LINE=$(printf '%s' "$HTPASSWD" | sed 's/\$/\\\$/g')
# Use sed to replace the entire users list in the yaml
# This assumes your users list is indented exactly 8 spaces under users:
# and users: line is at indentation level 6 spaces.
# Adjust indentation accordingly if different.

YAML_PATH="monitoring-stack/loadbalancer/services/middleware.yaml"

# Wrap in quotes and indent with 8 spaces (adjust as needed)
FINAL_LINE="          - \"$ESCAPED_LINE\""

sed -i.bak -E "/basicAuth:/,/- /{
  /users:/ {
    N
    s|users:\n *-.*|users:\n$FINAL_LINE|
  }
}" "$YAML_PATH"

echo "Updated users list in $YAML_PATH"
