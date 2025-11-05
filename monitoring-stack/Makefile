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

	rm -rf monitoring/loki/data/*
	rm -rf monitoring/grafana/data/*

	rm -rf ../canopy_data/node1/canopy/
	rm -rf ../canopy_data/node1/logs/

	rm -rf ../canopy_data/node2/canopy/
	rm -rf ../canopy_data/node2/logs/


	mkdir -p ../canopy_data/node1/canopy
	mkdir -p ../canopy_data/node1/logs

	mkdir -p ../canopy_data/node2/canopy
	mkdir -p ../canopy_data/node2/logs
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
			echo "Stopping node2 for downloading latest snapshot data chainID: 2"; \
			docker compose stop node2; \
			rm -rf ../canopy_data/node2/canopy/; \
			echo "Deleted node2 canopy data."; \
		else \
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
fix_perm:
        chown  65534:65534 -R ./monitoring/prometheus/data/
	chown 10001:10001 -R ./monitoring/loki/data
	chown 472:472 -R ./monitoring/grafana/
