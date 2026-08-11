> [!CAUTION]
> **This repository is no longer maintained and will not receive any further updates. Please refer to the new deployment setup [Canopy Node](https://github.com/canopy-network/node) instead.**

# Overview


This repo is home to various deployments flavor for canopy focusing mainly on providing a proper local development enviroment and a secure but flexible staging/production environments as well

Checkout [our official node running docs](https://canopy-network.gitbook.io/docs/node-runner/setup) for production builds


### Validator configuration

For configuring your own validator on canopy mainnet chainID 1 and 2 you need to create your keystore.json and validator_key.json.

This command will ask for your password and username and will create the previous files and store it on `canopy_data/node1/`  which is the datadir that we use for our deployment tooling


```bash
chmod +x setup.sh
./setup.sh
```


### Deployment options

#### Overview

This section includes a list of deployments options with links to their specific documentation and description of usage

 
#### Simple stack

Provide a simple [docker-compose.yaml]([url](https://github.com/canopy-network/deployments/blob/master/simple-stack/docker-compose.yaml)) configuration for providing canopy network nodes chainID: 1 and chainID: 2

```bash
cd  ./simple-stack
cp .env.template .env
sudo make up
```

For more information please refer to [Simple stack README.md](./simple-stack/README.md)

#### Monitoring stack

Provides a stack with prometheus, loki, grafana, cadvisor, node-exporter, and traefik as loadbalancer useful for a production grade deployments and flexible for local and test environments as well


For more information please refer to [Monitoring stack README.md](./monitoring-stack/README.md)


#### docker_image 

It contains the [Dockerfile]([url](https://github.com/canopy-network/deployments/tree/master/docker_image)) and entrypoint.sh used by all the stacks in order to have a centralized way of building the canopy image


#### Canopy config files


Provides datadirs and config files for the nodes used in this stack, respectively [node1](../canopy_data/node1/config.json) and [node2](../canopy_data/node2/config.json)
