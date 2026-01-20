#!/bin/bash
# Script to generate syncoor.*.*.yaml files for dispatchoor

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Networks
NETWORKS=("hoodi" "sepolia" "mainnet")

# Execution Layer clients
EL_CLIENTS=("besu" "erigon" "geth" "nethermind" "reth")

# Consensus Layer clients per network
declare -A NETWORK_CL_CLIENTS
NETWORK_CL_CLIENTS["hoodi"]="lighthouse teku prysm nimbus lodestar grandine"
NETWORK_CL_CLIENTS["sepolia"]="lighthouse teku prysm nimbus lodestar grandine"
NETWORK_CL_CLIENTS["mainnet"]="lighthouse teku prysm nimbus lodestar grandine"

# EL client container images
declare -A EL_IMAGES
EL_IMAGES["besu"]="hyperledger/besu:latest"
EL_IMAGES["erigon"]="erigontech/erigon:latest"
EL_IMAGES["geth"]="ethereum/client-go:stable"
EL_IMAGES["nethermind"]="nethermind/nethermind:latest"
EL_IMAGES["reth"]="ghcr.io/paradigmxyz/reth:latest"

# CL client container images
declare -A CL_IMAGES
CL_IMAGES["lighthouse"]="sigp/lighthouse:latest"
CL_IMAGES["teku"]="consensys/teku:latest"
CL_IMAGES["prysm"]="gcr.io/offchainlabs/prysm/beacon-chain:stable"
CL_IMAGES["nimbus"]="statusim/nimbus-eth2:multiarch-latest"
CL_IMAGES["lodestar"]="chainsafe/lodestar:latest"
CL_IMAGES["grandine"]="sifrai/grandine:stable"

# Timeouts per network and EL client (hours * 60 = minutes)
declare -A TIMEOUTS
TIMEOUTS["hoodi:besu"]=$((3*60))
TIMEOUTS["hoodi:erigon"]=$((4*60))
TIMEOUTS["hoodi:geth"]=$((3*60))
TIMEOUTS["hoodi:nethermind"]=$((23*60))
TIMEOUTS["hoodi:reth"]=$((18*60))

TIMEOUTS["sepolia:besu"]=$((15*60))
TIMEOUTS["sepolia:erigon"]=$((15*60))
TIMEOUTS["sepolia:geth"]=$((15*60))
TIMEOUTS["sepolia:nethermind"]=$((13*60))
TIMEOUTS["sepolia:reth"]=$((30*60))

TIMEOUTS["mainnet:besu"]=$((24*60))
TIMEOUTS["mainnet:erigon"]=$((20*60))
TIMEOUTS["mainnet:geth"]=$((12*60))
TIMEOUTS["mainnet:nethermind"]=$((6*60))
TIMEOUTS["mainnet:reth"]=$((48*60))

# Mainnet checkpoint sync URL
MAINNET_CHECKPOINT_URL="https://mainnet-checkpoint-sync.attestant.io"

# Capitalize first letter
capitalize() {
    echo "$(tr '[:lower:]' '[:upper:]' <<< ${1:0:1})${1:1}"
}

# Generate a single YAML entry for an EL/CL pair
generate_entry() {
    local network="$1"
    local el_client="$2"
    local cl_client="$3"
    local is_first="$4"

    local timeout="${TIMEOUTS[$network:$el_client]}"
    local el_image="${EL_IMAGES[$el_client]}"
    local cl_image="${CL_IMAGES[$cl_client]}"
    local network_cap=$(capitalize "$network")

    # Add blank line between entries (except before first)
    if [ "$is_first" != "true" ]; then
        echo ""
    fi

    echo "- id: sync-test-${network}-${el_client}-${cl_client}"
    echo "  name: Sync Test (${network_cap}) - ${el_client}/${cl_client}"
    echo "  owner: ethpandaops"
    echo "  repo: syncoor-tests"
    echo "  workflow_id: syncoor.yaml"
    echo "  ref: master"
    echo "  labels:"
    echo "    network: ${network}"
    echo "    el-client: ${el_client}"
    echo "    cl-client: ${cl_client}"
    echo "  inputs:"

    # Mainnet has runs-on
    if [ "$network" = "mainnet" ]; then
        echo "    runs-on: '{\"group\": \"synctest\", \"labels\": \"Disk4TB\"}'"
    fi

    echo "    run-timeout-minutes: \"${timeout}\""
    echo "    el-client: '\"${el_client}\"'"
    echo "    cl-client: '\"${cl_client}\"'"

    # Generate config based on network
    if [ "$network" = "mainnet" ]; then
        cat << EOF
    config: >-
      {
        "network": "${network}",
        "consensus": {
          "syncType": "checkpoint",
          "nodeType": "fullnode",
          "checkpointSyncURL": "${MAINNET_CHECKPOINT_URL}",
          "images": {
            "${cl_client}": "${cl_image}"
          }
        },
        "execution": {
          "images": {
            "${el_client}": "${el_image}"
          }
        }
      }
EOF
    else
        cat << EOF
    config: >-
      {
        "network": "${network}",
        "consensus": {
          "syncType": "checkpoint",
          "nodeType": "fullnode",
          "images": {
            "${cl_client}": "${cl_image}"
          }
        },
        "execution": {
          "images": {
            "${el_client}": "${el_image}"
          }
        }
      }
EOF
    fi
}

# Generate file comment
generate_comment() {
    local network="$1"
    local el_client="$2"
    local el_cap=$(capitalize "$el_client")
    local network_cap=$(capitalize "$network")

    if [ "$network" = "mainnet" ]; then
        echo "# ${el_cap} with Lighthouse for ${network_cap} network"
    else
        echo "# ${el_cap} combinations for ${network_cap} network"
    fi
}

# Generate a complete YAML file
generate_file() {
    local network="$1"
    local el_client="$2"
    local output_file="${SCRIPT_DIR}/syncoor.${network}.${el_client}.yaml"
    local cl_clients="${NETWORK_CL_CLIENTS[$network]}"

    echo "Generating ${output_file}..."

    {
        generate_comment "$network" "$el_client"

        local is_first="true"
        for cl_client in $cl_clients; do
            generate_entry "$network" "$el_client" "$cl_client" "$is_first"
            is_first="false"
        done
    } > "$output_file"
}

# Main
main() {
    echo "Generating syncoor YAML files..."

    for network in "${NETWORKS[@]}"; do
        for el_client in "${EL_CLIENTS[@]}"; do
            generate_file "$network" "$el_client"
        done
    done

    echo "Done! Generated $(( ${#NETWORKS[@]} * ${#EL_CLIENTS[@]} )) files."
}

main "$@"
