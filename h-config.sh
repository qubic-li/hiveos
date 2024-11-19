#!/bin/bash

process_user_config() {
    while IFS= read -r line; do
        [[ -z $line ]] && continue

        # Check if the line starts with nvtool and execute it using eval
        if [[ ${line:0:7} = "nvtool " ]]; then
            eval "$line"
        elif [[ ${line:0:10} = "AutoUpdate" ]]; then
            # Local file
            LOCAL_FILE="/hive/miners/custom/downloads/qubminer-latest.tar.gz"

            # URL of the remote file and its hash
            REMOTE_FILE_URL="https://github.com/qubic-li/hiveos/releases/download/latest/qubminer-latest.tar.gz"
            REMOTE_HASH_URL="https://github.com/qubic-li/hiveos/releases/download/latest/qubminer-latest.hash"

            # Check the availability of the remote hash
            if curl --output /dev/null --silent --head --fail "$REMOTE_HASH_URL"; then
                # Download the remote hash
                REMOTE_HASH=$(curl -s -L "$REMOTE_HASH_URL")

                # Calculate the SHA256 hash of the local file
                LOCAL_HASH=$(sha256sum "$LOCAL_FILE" | awk '{print $1}')

                # Compare the hashes
                if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
                    echo "Hashes of local and remote ($REMOTE_FILE_URL) miners are different. Removing the local file of the miner and restarting the miner. In case you see the error multiple times, check the URL of the miner in the Flight Sheet."
                    # Remove old local miner and restart the miner
                    rm "$LOCAL_FILE"
                    echo "Miner restarting in 10 sec..."
                    screen -d -m miner restart
                fi
            fi
        else
            # Remove spaces only from the beginning of the line
            line=$(echo "$line" | sed 's/^[[:space:]]*//')

            # Extract parameter and its value from the configuration line
            param=$(awk -F':' '{gsub(/\"/, ""); print $1}' <<< "$line")
            value=$(awk -F':' '{gsub(/^[[:space:]]*/, ""); print substr($0, length($1) + 2)}' <<< "$line")

            # Convert parameter to lowercase for cpuOnly check
            param_low=$(echo "$param" | tr '[:upper:]' '[:lower:]')

            # Check for CPU only mode (case-insensitive)
            if [[ "$param_low" == "cpuonly" && ("$value" == "true" || "$value" == "\"true\"") ]]; then
                CPU_ONLY=true
                continue
            fi

            # Store amountOfThreads parameter for later processing
            if [[ "$param" == "amountOfThreads" ]]; then
                AMOUNT_OF_THREADS=$value
                continue
            fi

            # Store trainer configuration if present
            if [[ "$param" == "trainer" ]]; then
                TRAINER_CONFIG=$line
                continue
            fi

            # Convert parameter to uppercase for other processing
            param_high=$(echo "$param" | tr '[:lower:]' '[:upper:]')

            # Perform replacements in the parameter
            modified_param=$(echo "$param_high" | awk '{
                gsub("QUBICADDRESS", "qubicAddress");
                gsub("CPUTHREADS", "cpuThreads");
                gsub("ACCESSTOKEN", "accessToken");
                gsub("ALLOWHWINFOCOLLECT", "allowHwInfoCollect");
                gsub("HUGEPAGES", "hugePages");
                gsub("ALIAS", "alias");
                gsub("OVERWRITES", "overwrites");
                gsub("IDLESETTINGS", "Idling");
                gsub("PPS=", "\"pps\": ");
                gsub("USELIVECONNECTION", "useLiveConnection");
                gsub("TRAINER", "trainer");
                print $0;
            }')

            # Check if modifications were made, if not, use the original parameter
            [[ "$param" != "$modified_param" ]] && param=$modified_param

            # General processing for other parameters
            if [[ ! -z "$value" ]]; then
                if [[ "$param" == "overwrites" ]]; then
                    Settings=$(jq -s '.[0] * .[1]' <<< "$Settings {$line}")
                elif [[ "$param" == "Idling" ]]; then
                    Settings=$(jq --argjson Idling "$value" '
                        .Idling = $Idling | 
                        .Idling.preCommand = ($Idling.preCommand // null) |
                        .Idling.preCommandArguments = ($Idling.preCommandArguments // null) |
                        .Idling.command = ($Idling.command // null) |
                        .Idling.arguments = ($Idling.arguments // null) |
                        .Idling.postCommand = ($Idling.postCommand // null) |
                        .Idling.postCommandArguments = ($Idling.postCommandArguments // null)
                    ' <<< "$Settings")
                elif [[ "$param" == "accessToken" ]]; then
                    value=$(echo "$value" | sed 's/^"//;s/"$//')
                    Settings=$(jq --arg value "$value" '.accessToken = $value' <<< "$Settings")
                elif [[ "$param" == "pps" || "$param" == "useLiveConnection" ]]; then
                    if [[ "$value" == "true" || "$value" == "false" ]]; then
                        Settings=$(jq --argjson value "$value" '.[$param] = $value' <<< "$Settings")
                    else
                        echo "Invalid value for $param: $value. It must be 'true' or 'false'. Skipping this entry."
                    fi
                else
                    if [[ "$param" == "trainer.cpuThreads" ]]; then
                        Settings=$(jq --arg value "$value" '.trainer.cpuThreads = ($value | tonumber)' <<< "$Settings")
                    elif [[ "$param" == "trainer.gpu" ]]; then
                        Settings=$(jq --argjson value "$value" '.trainer.gpu = $value' <<< "$Settings")
                    elif [[ "$value" == "null" ]]; then
                        Settings=$(jq --arg param "$param" '.[$param] = null' <<< "$Settings")
                    elif [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        Settings=$(jq --arg param "$param" --argjson value "$value" '.[$param] = ($value | tonumber)' <<< "$Settings")
                    else
                        Settings=$(jq --arg param "$param" --arg value "$value" '.[$param] = $value' <<< "$Settings")
                    fi
                fi
            fi
        fi
    done <<< "$CUSTOM_USER_CONFIG"
}

# Main script logic

# Processing global settings
GlobalSettings=$(jq -r '.ClientSettings' "/hive/miners/custom/$CUSTOM_NAME/appsettings_global.json" | envsubst)

# Initialize Settings
Settings="$GlobalSettings"

# Delete old settings
eval "rm -rf /hive/miners/custom/$CUSTOM_NAME/appsettings.json"

# Processing the template (alias)
if [[ ! -z $CUSTOM_TEMPLATE ]]; then
    Settings=$(jq --arg alias "$CUSTOM_TEMPLATE" '.alias = $alias' <<< "$Settings")
fi

# Processing user configuration
[[ ! -z $CUSTOM_USER_CONFIG ]] && process_user_config

# Adding poolAddress settings
if [[ ! -z $CUSTOM_URL ]]; then
    Settings=$(jq --arg poolAddress "$CUSTOM_URL" '.poolAddress = $poolAddress' <<< "$Settings")
fi

# Check and modify Settings for hugePages parameter
if [[ $(jq '.hugePages' <<< "$Settings") != null ]]; then
    hugePages=$(jq -r '.hugePages' <<< "$Settings")
    if [[ ! -z $hugePages && $hugePages -gt 0 ]]; then
        eval "sysctl -w vm.nr_hugepages=$hugePages"
    fi
fi

# Store existing trainer settings that we want to preserve
if [[ ! -z "$TRAINER_CONFIG" ]]; then
    EXISTING_TRAINER=$(jq -r '.trainer' <<< "$Settings")
fi

# Configure trainer settings based on user input
Settings=$(jq 'del(.cpuOnly)' <<< "$Settings")

# Logic for CPU/GPU configuration while preserving existing trainer settings
if [[ "$CPU_ONLY" == "true" ]]; then
    if [[ ! -z "$AMOUNT_OF_THREADS" ]]; then
        # CPU only mode with specified threads
        Settings=$(jq --arg threads "$AMOUNT_OF_THREADS" '
            .trainer.cpu = true | 
            .trainer.gpu = false |
            .trainer.cpuThreads = ($threads | tonumber)
        ' <<< "$Settings")
    else
        # CPU only mode without threads specified
        Settings=$(jq '.trainer.cpu = true | .trainer.gpu = false' <<< "$Settings")
    fi
elif [[ ! -z "$AMOUNT_OF_THREADS" ]]; then
    # Both CPU and GPU, with specified threads
    Settings=$(jq --arg threads "$AMOUNT_OF_THREADS" '
        .trainer.cpu = true |
        .trainer.gpu = true |
        .trainer.cpuThreads = ($threads | tonumber)
    ' <<< "$Settings")
else
    # GPU only mode (default)
    Settings=$(jq '.trainer.cpu = false | .trainer.gpu = true' <<< "$Settings")
fi

# Apply trainer configuration if it exists
if [[ ! -z "$TRAINER_CONFIG" ]]; then
    Settings=$(jq -s '.[0] * .[1]' <<< "$Settings {$TRAINER_CONFIG}")
fi

# Create the final settings file
echo "{\"ClientSettings\":$Settings}" | jq . > "/hive/miners/custom/$CUSTOM_NAME/appsettings.json"

echo "Settings created successfully."
