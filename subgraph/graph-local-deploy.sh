#!/bin/bash

set -e


# Function to restore original addresses
restore_addresses() {
    yq e -i ".dataSources[0].source.address = \"0x5e771e1417100000000000000000000000000001\"" subgraph.yaml
    echo "Original addresses restored."
}

# Read the new addresses from deployed_addresses.json
REGISTRY_ADDRESS=$(jq -r '."StarterKitModule#StarterKitERC20Registry"' ../ignition/deployments/chain-31337/deployed_addresses.json)

# Update the addresses in subgraph.yaml
yq e -i ".dataSources[0].source.address = \"$REGISTRY_ADDRESS\"" subgraph.yaml

npx graph create --node http://localhost:8020 starterkit
npx graph deploy --version-label v1.0.$(date +%s) --node http://localhost:8020 --ipfs https://ipfs.network.thegraph.com starterkit subgraph.yaml

echo 'Check it out on http://localhost:8000/subgraphs/name/starterkit/'
