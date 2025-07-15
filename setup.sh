#!/bin/bash
echo "setting up the validator key"
docker build -t canopy --build-arg 'BRANCH=beta-0.1.3' --build-arg BUILD_PATH=cmd/cli  ./docker_image/ && \
docker run --user root -it -p 50000:50000 -p 50001:50001 -p 50002:50002 -p 50003:50003 -p 9001:9001 --name canopy-config  --volume ${PWD}/canopy_data/node1/:/root/.canopy/ canopynetwork/canopy && \

docker stop canopy-config && docker rm canopy-config && \
cp canopy_data/node1/validator_key.json canopy_data/node2/ && \
cp canopy_data/node1/keystore.json canopy_data/node2/

# ask user for setup type
echo "Please select setup type:"
echo "1) simple (only contains the node containers)"
echo "2) full (contains the node containers and the monitoring stack)"
read -p "Enter your choice (1 or 2): " SETUP_CHOICE

# validate and set SETUP_TYPE
while [[ "$SETUP_CHOICE" != "1" && "$SETUP_CHOICE" != "2" ]]; do
    echo "Invalid choice. Please enter 1 for simple or 2 for full."
    read -p "Enter your choice (1 or 2): " SETUP_CHOICE
done

if [[ "$SETUP_CHOICE" == "1" ]]; then
    SETUP_TYPE="simple"
else
    SETUP_TYPE="full"
fi

if [[ "$SETUP_TYPE" == "simple" ]]; then
  echo "setup complete ✅"
  exit 0
fi

STACK_PATH="$(realpath "$(dirname "$0")/monitoring-stack/")"

# ask user for domain input
read -p "Please enter the domain [default: localhost]: " DOMAIN

# ask user for acme email input
read -p "Please enter email to validate the domain against [default: test@example.com]: " ACME_EMAIL

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
  # perform the sed substitution for the node-1 config.json
  if grep -q "tcp://node1.localhost" "$NODE1_CONFIG"; then
    echo "Replacing localhost with $DOMAIN in $NODE1_CONFIG"
    sed -i "s|tcp://node1.localhost|tcp://node1.$DOMAIN|g" "$NODE1_CONFIG"
  else
    echo "localhost already replaced with $DOMAIN."
  fi
fi

if [[ -n "$DOMAIN" ]]; then
  # perform the sed substitution for the node-2 config.json
  if grep -q "tcp://node2.localhost" "$NODE2_CONFIG"; then
    echo "Replacing localhost with $DOMAIN in $NODE2_CONFIG"
    sed -i "s|tcp://node2.localhost|tcp://node2.$DOMAIN|g" "$NODE2_CONFIG"
  else
    echo "localhost already replaced with $DOMAIN."
  fi
fi

echo "setup complete ✅"
