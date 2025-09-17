FROM node:20-alpine AS builder 

ARG BRANCH='latest'
ARG CLI_DIR
ARG BUILD_PATH=cmd/cli
ARG GO_BIN_DIR
ARG BUILD_LOCAL=False
ARG BIN_PATH=/bin/cli
ARG DEV_MODE=False
ARG CANOPY_SRC_DIR

# downloads git and clones selected version
RUN apk add --no-cache git ca-certificates alpine-sdk
WORKDIR /go/src/github.com/canopy-network/canopy

# Check if we're in DEV_MODE to use local files or clone from GitHub
RUN if [ "$DEV_MODE" = "True" ]; then \
        echo "Using local development files..."; \
    else \
        echo "Building from BRANCH=${BRANCH}" && \
        if [ "$BRANCH" = "latest" ]; then \
            echo "Fetching latest tag..."; \
            git clone https://github.com/canopy-network/canopy.git . && \
            LATEST_TAG=$(git describe --tags `git rev-list --tags --max-count=1`) && \
            echo "Checking out tag $LATEST_TAG" && \
            git checkout $LATEST_TAG; \
        else \
            echo "Cloning branch $BRANCH" && \
            git clone -b "$BRANCH" https://github.com/canopy-network/canopy.git .; \
        fi; \
    fi

# Copy golang
COPY --from=golang:1.23.9-alpine /usr/local/go/ /usr/local/go/
ENV PATH="/usr/local/go/bin:${PATH}"

RUN go version

# Copy local files if in DEV_MODE
# This COPY instruction will be used only when building with DEV_MODE=True
# Note: The source directory must be passed as a build argument
COPY ${CANOPY_SRC_DIR:-./canopy-placeholder}/ /go/src/github.com/canopy-network/canopy/

# Builds 
RUN apk update && apk add --no-cache make bash nodejs npm 
# Configure npm to avoid SSL issues
RUN npm config set registry https://registry.npmjs.org/
RUN npm config set strict-ssl false
RUN npm config set ca ""
# Try to build wallet with npm cache clear
RUN npm cache clean --force

# Skip wallet build if web directories are empty
RUN if [ -d "web/wallet" ] && [ "$(ls -A web/wallet)" ]; then \
        echo "Building wallet..."; \
        make build/wallet; \
    else \
        echo "Wallet directory is empty, skipping build..."; \
    fi

# Build the new explorer if it exists and has content
RUN if [ -d "web/explorer-new" ] && [ "$(ls -A web/explorer-new)" ] && [ -f "web/explorer-new/package.json" ]; then \
        echo "Building new explorer from web/explorer-new..."; \
        cd web/explorer-new && npm install && npm run build; \
    else \
        echo "web/explorer-new is empty or no package.json, skipping explorer build..."; \
    fi

# Builds auto-update CLI - skip if it fails
RUN if [ -d "./cmd/auto-update" ]; then \
        echo "Building auto-update CLI..."; \
        CGO_ENABLED=0 GOOS=linux go build -a -o bin ./cmd/auto-update/.; \
    else \
        echo "auto-update directory not found, skipping..."; \
        mkdir -p bin; \
    fi

# Only build if the file at ${BIN_PATH} doesn't already exist
RUN if [ ! -f "${BIN_PATH}" ]; then \
    echo "File ${BIN_PATH} not found. Building it..."; \
    if [ -d "./cmd/main" ]; then \
        CGO_ENABLED=0 GOOS=linux go build -a -o "${BIN_PATH}" ./cmd/main/...; \
    else \
        echo "cmd/main directory not found, creating empty CLI file..."; \
        echo "#!/bin/sh\necho 'CLI not available'" > "${BIN_PATH}"; \
        chmod +x "${BIN_PATH}"; \
    fi; \
  else \
    echo "File ${BIN_PATH} already exists. Skipping build."; \
  fi

FROM node:20-alpine
WORKDIR /app

# Install development tools
RUN apk add --no-cache git bash vim nano openssh-server

# Copying for command
COPY --from=builder /go/src/github.com/canopy-network/canopy/bin ./canopy
# Copying cli for auto update
COPY --from=builder /bin/cli /bin/cli 
# Copying the new explorer build if it exists
RUN if [ -d "/go/src/github.com/canopy-network/canopy/web/explorer-new/dist" ]; then \
        cp -r /go/src/github.com/canopy-network/canopy/web/explorer-new/dist ./explorer; \
    else \
        echo "No explorer build found, creating empty directory"; \
        mkdir -p ./explorer; \
    fi
# Copying entrypoint for persisting update cli
COPY ./deployments/docker_image/entrypoint.sh /app/entrypoint.sh

RUN apk add --no-cache pigz ca-certificates

RUN chmod +x /bin/cli
RUN chmod +x /app/canopy
RUN chmod +x /app/entrypoint.sh

# Create development directories
RUN mkdir -p /app/dev-explorer
RUN mkdir -p /app/dev-wallet
RUN mkdir -p /app/canopy-source

# Install global development tools
RUN npm install -g nodemon concurrently

# Configure SSH for VSCode Remote
RUN mkdir -p /root/.ssh && \
    echo "root:root" | chpasswd && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "Port 22" >> /etc/ssh/sshd_config

# Create development startup script
RUN echo '#!/bin/sh\n\
echo "Starting development environment..."\n\
echo "Development directories:"\n\
echo "  - /app/dev-explorer (mounted from ../../canopy/web/explorer-new)"\n\
echo "  - /app/dev-wallet (mounted from ../../canopy/web/wallet)"\n\
echo "  - /app/canopy-source (mounted from ../../canopy)"\n\
echo "SSH server available at port 22 for VSCode Remote"\n\
echo "Use VSCode Remote Development extension to connect to:"\n\
echo "  - Host: localhost"\n\
echo "  - Port: 2222"\n\
echo "  - Username: root"\n\
echo "  - Password: root"\n\
\n\
# Start SSH server\n\
/usr/sbin/sshd\n\
\n\
# Start development servers if directories exist and have content\n\
if [ -d "/app/dev-explorer" ] && [ "$(ls -A /app/dev-explorer)" ] && [ -f "/app/dev-explorer/package.json" ]; then\n\
    echo "Starting explorer development server..."\n\
    cd /app/dev-explorer && npm run dev &\n\
fi\n\
\n\
if [ -d "/app/dev-wallet" ] && [ "$(ls -A /app/dev-wallet)" ] && [ -f "/app/dev-wallet/package.json" ]; then\n\
    echo "Starting wallet development server..."\n\
    cd /app/dev-wallet && npm run dev &\n\
fi\n\
\n\
# Keep container running\n\
wait\n\
' > /app/dev-start.sh && chmod +x /app/dev-start.sh

ENTRYPOINT ["/app/entrypoint.sh"]
