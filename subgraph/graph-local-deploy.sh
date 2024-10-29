#!/bin/bash

set -e


# Function to restore original addresses
restore_addresses() {
    yq e -i ".dataSources[0].source.address = \"0x5e771e1417100000000000000000000000000001\"" subgraph.yaml
    yq e -i ".dataSources[1].source.address = \"0x5e771e1417100000000000000000000000000003\"" subgraph.yaml
    echo "Original addresses restored."
}

trap restore_addresses EXIT

# Read the new addresses from deployed_addresses.json
REGISTRY_ADDRESS=$(jq -r '."ContractsModule#StarterKitERC20Registry"' ../ignition/deployments/chain-31337/deployed_addresses.json)
DEX_FACTORY_ADDRESS=$(jq -r '."ContractsModule#StarterKitERC20DexFactory"' ../ignition/deployments/chain-31337/deployed_addresses.json)

# Update the addresses in subgraph.yaml
yq e -i ".dataSources[0].source.address = \"$REGISTRY_ADDRESS\"" subgraph.yaml
yq e -i ".dataSources[1].source.address = \"$DEX_FACTORY_ADDRESS\"" subgraph.yaml

npx graph codegen
npx graph create --node http://localhost:8020 starterkit
npx graph deploy --version-label v1.0.$(date +%s) --node http://localhost:8020 --ipfs https://ipfs.network.thegraph.com starterkit subgraph.yaml

echo 'Check it out on http://localhost:8000/subgraphs/name/starterkit/'
