# Canopy simple stack overview


The following docker-compose.yaml contains a simple configuration to run the canopy software

We added a [.env](./.env) which is the file we use to parametrice all configurations. It is intented to run by default for local testing but can be easily modified via .env variable to be configured for staging/production purposes


## Setup

### System Requirements

#### Canopy Nodes
- **Minimum**: 4GB RAM | 2vCPU | 100GB storage
- **Recommended**: 8GB RAM | 4vCPU | 100GB storage

### .env 

Copy the env variable as example in order to activate it's usage 

```bash

cp .env.template .env

```

## Running


```bash

sudo make pull
sudo make up

```

If you like to start from the most recent snapshot for canopy mainnet full nodechainID 1 and chainID 2, you should consider using

```bash

sudo make start_with_snapshot

```


This stack runs the following local services:

- http://localhost:50000 Wallet of chain 1
- http://localhost:50001 Explorer of chain 1
- http://localhost:40000 Wallet of chain 2
- http://localhost:40001 Explorer of chain 2

### Clearing data


This command clears all canopy nodes data for a hard reset of the environment

```bash
sudo make reset
```
