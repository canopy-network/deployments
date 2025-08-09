# Canopy monitoring stack overview


This  docker-compose.yaml contains the following software stack for production grade and monitoring purposes; prometheus, grafana for monitoring and cadvisor and node-exporter for container and server metrics respectively and traefik for loadbalancing purposes

We added a [.env](./.env) which is the file we use to parametrice all configurations in order to setup your personal canopy monitoring stack. It is intented to run by default for local testing but can be easily modified via .env variable to be configured for more robust staging/production purposes



## Setup

### System Requirements


#### Complete Monitoring Stack
- **Minimum**: 8GB RAM | 4vCPU | 100GB storage
- **Recommended**: 16GB RAM | 8vCPU | 250GB storage

**Component-specific requirements:**


#### Canopy Nodes
- **Minimum**: 4GB RAM | 2vCPU | 25GB storage
- **Recommended**: 8GB RAM | 4vCPU | 100GB storage

#### Monitoring components

- **Prometheus**: 1GB RAM | 1vCPU | 20GB storage (for metrics storage)
- **Grafana**: 512MB RAM | 1vCPU | 5GB storage (for dashboards and UI)
- **Loki**: 1GB RAM | 1vCPU | 20GB storage (for log storage)
- **Cadvisor**: 256MB RAM | 1vCPU | 2GB storage (for container metrics)
- **Traefik**: 256MB RAM | 1vCPU | 1GB storage (for load balancing)
- **Node Exporter**: 128MB RAM | 1vCPU | 1GB storage (for host metrics)
- **Blackbox Exporter**: 128MB RAM | 1vCPU | 1GB storage (for endpoint monitoring)

### .env 

Copy the env variable as example in order to activate it's usage 

```bash

cp .env.template .env

```

### Grafana loki plugin

Install the loki plugin so all of our logs can be ingested by loki 


``` bash

sudo docker plugin install  grafana/loki-docker-driver --alias loki

```


### Grafana notification channels

In order to correctly receive the infrastructure and canopy alerts on this setup stack you should configure the discord and the pagerduty notification channel configs:

[Discord channel webhook](./monitoring/grafana/provisioning/alerting/discord-alert.yaml#L28)

[Pagerduty APIKEY](./monitoring/grafana/provisioning/alerting/pagerduty-alert.yaml#L9)

### Required Ports

This section describes the ports opened externally and internally by this setup. 

Make sure you open the external ports in order to properly configure canopy 

External ports

#### Canopy Node Ports
- **9001**: TCP P2P communication for node1
- **9002**: TCP P2P communication for node2

#### Load Balancer Ports
- **80**: HTTP traffic (redirects to HTTPS in production)
- **443**: HTTPS traffic (SSL/TLS)

Internal ports

#### Monitoring Ports
- **3000**: Grafana web interface
- **9090**: Prometheus metrics endpoint
- **3100**: Loki log aggregation
- **8082**: Traefik metrics endpoint
- **9115**: Blackbox exporter metrics
- **8080**: cAdvisor container metrics
- **9100**: Node exporter host metrics

#### Canopy service Ports
- **50000**: Wallet service for node1 (exposed via Traefik)
- **50001**: Explorer service for node1 (exposed via Traefik)
- **50002**: RPC service for node1 (exposed via Traefik)
- **50003**: Admin RPC service for node1 (exposed via Traefik)
- **40000**: Wallet service for node2 (exposed via Traefik)
- **40001**: Explorer service for node2 (exposed via Traefik)
- **40002**: RPC service for node2 (exposed via Traefik)
- **40003**: Admin RPC service for node2 (exposed via Traefik)

## Running


### Local

```bash

sudo make up

```

If you like to start from the most recent snapshot for canopy mainnet full nodechainID 1 and chainID 2, you should consider using

```bash

sudo make start_with_snapshot

```


This stack runs the following local and production services:

- http://wallet.node1.localhost/
	user: canopy, pass:canopy (production usage)
- http://explorer.node1.localhost/
- http://rpc.node1.localhost/
- http://adminrpc.node1.localhost/

- http://wallet.node2.localhost/
(password protected by canopy:canopy)
- http://explorer.node2.localhost/
- http://rpc.node1.localhost/
- http://adminrpc.node1.localhost/


Grafana monitorign service 

- http://monitoring.localhost/
	user: admin, pass: canopy


### Clearing data


This command clears all canopy nodes data for a hard reset of the environment

```bash
sudo make reset
```


## Production


This stack lets you run a semi-production deployment of the canopy stack by just changing a small number of settings shown below: 


### Step 1: Define your env variables
 
#### $DOMAIN

With a `DOMAIN` variable defined on [.env.template](/.env.template) traefik will expose and validate SSL on this endpoints externally using the prefix shown in the first running section  

It will also properly configure to expose canopy nodes explorer, rpc and wallet services on the config.json files by using 
[entrypoint.sh](../docker_image/entrypoint.sh)  on [node1 config.json](../canopy_data/node1/config.json) and [node2 config.json](../canopy_data/node2/config.json) 


Node1 config.json
```
  "rpcURL": "https://node1.<YOUR_DOMAIN>/rpc",

  "adminRPCUrl": "https://node1.<YOUR_DOMAIN>/adminrpc",

  "externalAddress": "tcp://node1.<YOUR_DOMAIN>",
```

Node2 config.json

```
  "rpcURL": "https://node2.<YOUR_DOMAIN>/rpc",
  
  "adminRPCUrl": "https://node2.<YOUR_DOMAIN>/adminrpc",

  "externalAddress": "tcp://node2.<YOUR_DOMAIN>",
```


#### $ACME_EMAIL

We use this env variable to request SSL ACME certificate during [traefik HTTPS validation](./loadbalancer/traefik.yml)

For more information check the Traefik section below



### Step 3:  Configure your DNS


Your domain should point to your production server under a wild card subdomain as shown:

*.node1.<YOUR_DOMAIN> A record -> ||YOUR IP||

*.node2.<YOUR_DOMAIN> A Record -> ||YOUR IP||


Once it's done, make sure your DNS are properly configured so traefik can request the SSL certificates and expose your canopy and monitoring services under your domain


### Step 4: Open external ports


As described in the ports section, canopy requires the following ports opened in order for canopy and traefik to work:


#### Canopy Node Ports
- **9001**: TCP P2P communication for node1
- **9002**: TCP P2P communication for node2

#### Load Balancer Ports
- **80**: HTTP traffic (redirects to HTTPS in production)
- **443**: HTTPS traffic (SSL/TLS)


You should be able to expose this ports via your cloud provider and/or by opening as well ufw as described below

#### Firewall Configuration Example (UFW)
```bash
# Canopy P2P ports
sudo ufw allow 9001/tcp
sudo ufw allow 9002/tcp

# Load balancer ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```


### Step 5: Define BASIC AUTH

By default wallet and explorer endpoints are sensitive endpoints accessed using basic AUTH with the following default password

```
username: canopy

passwd: canopy 
```

It's mandatory to change this default passwords since wallet/explorer endpoints are SENSITIVES for securing your validator
 
For customizing the loadbalancer basic auth access for production purposes on wallet production endpoints, create a custom password using the following command:

``` bash
htpasswd -nb  canopy canopy
```

Which will print a username and a hashed password that you need to replace it on [middleware.yaml](./loadbalancer/services/middleware.yaml)

After you save this file, traefik will automatically reload and allow the new password to be used right away on your production environment

```
IMPORTANT: WE DO NOT RECOMMEND exposing wallet endpoint without making sure you are securing your validator 
```

### Step 6: Run


```bash

sudo make up

```

Traefik will take sometime for requesting the SSL Certificates and will expose the services accordingly with the prefix described in the # Running section of this document 

We recommend to check the traefik section below on the Monitoring stack configuration for additonal modifications  

```
DISCLAIMER
This semi-production monitoring setup guide which doesn't include security measures over your server security or canopy key management make sure you take your own measures to secure them 
```

## Monitoring stack configuration

Below you will find the configuration file references and instructions in order to understand and customize the current setup

You can also find additional documentation below regarding the current setup:

[Metric documentation](./METRICS.md)

[Alert documentation](./ALERTS.md)


### Grafana

Grafana comes with defaults dashboard described below along with their configuration files and some other env variables described on (.env)[.env]

#### - [Blackbox dashboard](http://localhost:3000/d/xtkCtBkis/blackbox-exporter?var-interval=10s&orgId=1&from=now-15m&to=now&timezone=browser&var-target=$__all&var-source=$__all&var-destination=$__all&refresh=1m)

Dashboard with blackbox metrics which continously tests the wallet, RPC, and explorer endpoints on the canopy nodes 

#### - [Cadvisor exporter](http://localhost:3000/d/pMEd7m0Mz/cadvisor-exporter?orgId=1&from=now-6h&to=now&timezone=browser&var-host=$__all&var-container=$__all&var-DS_PROMETHEUS=PBFA97CFB590B2093)

Dashboard with resources metrics for docker containers

#### - [Node exporter](http://localhost:3000/d/rYdddlPWk/node-exporter-full?orgId=1&from=now-24h&to=now&timezone=browser&var-datasource=default&var-job=node-exporter&var-node=node-exporter:9100&var-diskdevices=%5Ba-z%5D%2B%7Cnvme%5B0-9%5D%2Bn%5B0-9%5D%2B%7Cmmcblk%5B0-9%5D%2B&refresh=1m)

Dashboard with resource metrics for the host instance 


#### - [Traefik dashboard](http://localhost:3000/d/O23g2BeWk/traefik-dashboard?orgId=1&from=now-5m&to=now&timezone=browser&var-service=&var-entrypoint=$__all&refresh=5m)

Dashboard with loadbalancer metrics

#### - [Canopy dashboard](http://localhost:3000/d/fejf7y7gcnwg0e/canopy-dashboard?orgId=1&from=now-1h&to=now&timezone=browser&var-instance=node1:9090&var-instance=node2:9090) 

Dashboard with canopy metrics for blocks, transactions, validators among other metrics


#### - [Instance monitoring alerts](http://localhost:3000/d/KljDeaZ4z/blockchain-node-instance-dashboard?orgId=1&from=now-15m&to=now&timezone=browser&var-DS_PROMETHEUS=default&var-job=node-exporter)

Dashboard with host container metrics 

[dashboard folder](./monitoring/grafana/dashboards)
[dashboard config](./monitoring/grafana/provisioning/dashboards/dashboard.yaml)
[datasources config](./monitoring/grafana/provisioning/datasources/automatic.yaml)


#### Prometheus

Configuration it's mainly described on the prometheus.yml configuration file

[prometheus.yml](./monitoring/prometheus/prometheus.yml)


#### Cadvisor

Used for server metrics, we use the vanilla config which is described in docker-compose.yaml

#### Node-exporter

Used for exporting node metrics, we use the vanilla config which is described in docker-compose.yaml

#### Blackbox

We use blackbox for testing and monitoring wallet/explorer endpoints. We'll be adding more tests for rpc and adminrcp soon

[blackbox.yml](./monitoring/blackbox/blackbox.yml)


#### Traefik 

As mentioned, we use traefik as loadbalancer for exposing canopy and monitoring software on two setups local and production with 2 nodes which can be accessed on the URLS described in the start of the document


Traefik will automatically create certs for all the URLS described on the # Runing section in this document  

##### Traefik key settings

[Traefik general config](./loadbalancer/traefik.yml) 

[Production services](./loadbalancer/services/prod.yaml)

[Local services](./loadbalancer/services/local.yaml)

[Middlewares config](./loadbalancer/services/middleware.yaml)


####  SSL resolver

We use acme as SSL certificate resolver with httpChallenge by default which can be used for production, our documentation also contains `cloudflare` and `namecheap` integration for dnsChallenge recommended for production grade usage

For more information please check  [traefik config](./loadbalancer/traefik.yml) on the section https-resolver, below you'll find details about the https-resolvers described in this file: 

*https-resolver*

It's the one used by default for production grade SSL, validation it's based on httpChallenge validation 


*cloudflare*

It's the recommended one (or any compatible https DNS resolver for your provider) since DNS resolver it's way more effective than httpChallenge

*namecheap*

Added for educational purposes

For more information about https-resolvers please refer to [traefik https-resolvers](https://doc.traefik.io/traefik/reference/install-configuration/tls/certificate-resolvers/overview/)


#### Basic AUTH

By default wallet endpoints are accessed using:

username: canopy
passwd: canopy 

 
For customizing the loadbalancer basic auth access for production purposes on wallet production endpoints, create a custom password using the following command:

``` bash
htpasswd -nb  canopy canopy
```

Which will print a username and a hashed password that you need to replace it on [middleware.yaml](./loadbalancer/services/middleware.yaml)

After you save this file, traefik will automatically reload and allow the new password to be used right away on your production environment


#### Loki

We use loki for logs which takes all the stdout from the containers and sends it to the loki container. more info on (docker-compose.yaml)[./docker-compose.yaml]

[Loki config](./monitoring/loki/config.yaml)


For ex.: to access loki logs on node1 after you executed the docker-compose up command you should see it [here](http://localhost:3000/explore?schemaVersion=1&panes=%7B%225v4%22:%7B%22datasource%22:%22beh1gkva12hvkd%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bcompose_service%3D%5C%22node2%5C%22%7D%20%7C%3D%20%60%60%22,%22queryType%22:%22range%22,%22datasource%22:%7B%22type%22:%22loki%22,%22uid%22:%22beh1gkva12hvkd%22%7D,%22editorMode%22:%22builder%22,%22direction%22:%22backward%22%7D%5D,%22range%22:%7B%22from%22:%22now-1h%22,%22to%22:%22now%22%7D%7D%7D&orgId=1)
