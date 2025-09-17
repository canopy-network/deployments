# Load .env if it exists
ifneq (,$(wildcard .env))
  include .env
  export
endif

build:
	docker compose build
pull:
	docker pull canopynetwork/canopy
up:
	docker compose down
	docker compose up -d
down:
	docker compose down
restart_with_latest:
	make pull
	make up
logs:
	docker compose logs -f node1 node2
reset:
	docker compose stop node1 node2

	rm -rf ../canopy_data/node1/canopy/
	rm -rf ../canopy_data/node1/logs/

	rm -rf ../canopy_data/node2/canopy/
	rm -rf ../canopy_data/node2/canopy/

	mkdir -p ../canopy_data/node1/canopy
	mkdir -p ../canopy_data/node1/logs

	mkdir -p ../canopy_data/node2/canopy
	mkdir -p ../canopy_data/node2/logs

# Development commands
dev-shell:
	@echo "Entering development shell in node1 container..."
	docker exec -it node1 /bin/sh

dev-start:
	@echo "Starting development mode..."
	@echo "Development server will be available at: http://localhost:3000"
	@echo "Use VSCode Remote Development extension to connect to:"
	@echo "  - Host: localhost"
	@echo "  - Port: 3000"
	@echo "  - Username: root"
	@echo "  - Password: (leave empty)"
	docker exec -d node1 /app/dev-start.sh

dev-stop:
	@echo "Stopping development mode..."
	docker exec node1 pkill -f "npm run dev" || true

dev-vscode:
	@echo "Starting development mode for VSCode connection..."
	@echo "1. Start development mode: make dev-start"
	@echo "2. In VSCode, install 'Remote Development' extension"
	@echo "3. Press Ctrl+Shift+P and select 'Remote-SSH: Connect to Host'"
	@echo "4. Enter: root@localhost:3000"
	@echo "5. Select the container folder to work with"
	make dev-start

dev-sync-explorer:
	@echo "Syncing explorer changes from Docker to local..."
	docker cp node1:/app/dev-explorer/. ../../canopy/web/explorer-new/

dev-sync-wallet:
	@echo "Syncing wallet changes from Docker to local..."
	docker cp node1:/app/dev-wallet/. ../../canopy/web/wallet/

dev-sync-all:
	@echo "Syncing all development changes..."
	make dev-sync-explorer
	make dev-sync-wallet

dev-rebuild-explorer:
	@echo "Rebuilding explorer inside Docker..."
	docker exec -it node1 sh -c "cd /app/dev-explorer && npm install && npm run build"

dev-rebuild-wallet:
	@echo "Rebuilding wallet inside Docker..."
	docker exec -it node1 sh -c "cd /app/dev-wallet && npm install && npm run build"

dev-rebuild-all:
	@echo "Rebuilding all projects inside Docker..."
	make dev-rebuild-explorer
	make dev-rebuild-wallet

start_with_snapshot:
	@echo "Checking for existing canopy data directories..."
	@if [ -d "../canopy_data/node1/canopy" ]; then \
		echo "Found existing canopy data in node1. Do you want to delete it? (y/N): "; \
		read confirm; \
		if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
			echo "Stopping node1 for downloading latest snapshot data chainID: 1"; \
			docker compose stop node1; \
			rm -rf ../canopy_data/node1/canopy/; \
			echo "Deleted node1 canopy data."; \
		else \
			echo "Keeping existing node1 data."; \
		fi; \
	fi
	@if [ -d "../canopy_data/node2/canopy" ]; then \
		echo "Found existing canopy data in node2. Do you want to delete it? (y/N): "; \
		read confirm; \
		if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
			echo "Keeping existing node2 data."; \
		fi; \
	fi

	echo "Downloading snapshot for mainnet chainID: 1"	
	wget -O snapshot.tar.gz $(SNAPSHOT_1_URL)

	echo "Deleting/Recreating node1 datadir"
	rm -rf ../canopy_data/node1/canopy/
	mkdir  ../canopy_data/node1/canopy/

	echo "Uncompressing snapshot for mainnet chainID: 1"
	tar -xvzf ./snapshot.tar.gz -C ../canopy_data/node1/canopy/

	echo "Deleting snapshot for chain ID 2"
	rm ./snapshot.tar.gz

	echo "Restarting node1"

	echo "Downloading snapshot for mainnet chainID: 2"
	wget -O snapshot.tar.gz $(SNAPSHOT_2_URL)

	echo "Deleting/Recreating node2 datadir"
	rm -rf ../canopy_data/node2/canopy/
	mkdir ../canopy_data/node2/canopy/

	echo "Uncompressing snapshot for mainnet chainID: 2"
	tar -xvzf ./snapshot.tar.gz -C ../canopy_data/node2/canopy/

	echo "Deleting snapshot for chain ID 2"
	rm ./snapshot.tar.gz

	echo "Restarting node2 and whole stack"
	docker compose up -d 
