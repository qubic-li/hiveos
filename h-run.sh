#!/bin/bash

# Check ts
if ! command -v ts &> /dev/null; then
    echo "Program ts (moreutils) - not installed. ts is required. Installing..."
    cd /tmp/ && wget https://raw.githubusercontent.com/Worm/moreutils/master/ts && mv ts /usr/local/bin && chmod 777 /usr/local/bin/ts
    echo "Program ts (moreutils) - has been installed."
fi

# Load miner environment passthrough (GATEWAY, POOL_*, ...) if h-config.sh wrote one.
# qli-Client inherits this environment and passes it down to the miner it spawns.
if [[ -e ./qubminer.env ]]; then
    echo "Loading miner environment from ./qubminer.env"
    set -a
    source ./qubminer.env
    set +a
fi

# Check if appsettings.json exists
if [[ -e ./appsettings.json ]]; then
    echo "Running miner"
    ./qli-Client | ts | tee --append $MINER_LOG_BASENAME.log
else
    echo "ERROR: No appsettings.json file found, exiting"
    exit 1
fi
