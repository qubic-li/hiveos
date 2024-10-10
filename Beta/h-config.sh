#!/bin/bash

process_user_config() {
    while IFS= read -r line; do
        [[ -z $line ]] && continue

        # Check if the line starts with nvtool and execute it using eval
        if [[ ${line:0:7} = "nvtool " ]]; then
            eval "$line"
        elif [[ ${line:0:10} = "AutoUpdate" ]]; then
            # Local file
            LOCAL_FILE="/hive/miners/custom/downloads/qubminer.beta-latest.tar.gz"

            # URL of the remote file and its hash
            REMOTE_FILE_URL="https://github.com/qubic-li/hiveos/releases/download/beta/qubminer.beta-latest.tar.gz"
            REMOTE_HASH_URL="https://github.com/qubic-li/hiveos/releases/download/beta/qubminer.beta-latest.hash"

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

            # Convert parameter to uppercase
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
                if [[ "$param" == "overwrites" || "$param" == "trainer" ]]; then
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

# Ensure trainer settings are properly set
Settings=$(jq '
    if .trainer == null then .trainer = {} else . end |
    if .trainer.cpu == null then .trainer.cpu = false else . end |
    if .trainer.gpu == null then .trainer.gpu = false else . end |
    if .trainer.cpu == false and .trainer.gpu == false then .trainer.cpu = true else . end |
    if .trainer.cpu == true and .trainer.cpuThreads == null then .trainer.cpuThreads = 0 else . end
' <<< "$Settings")

# Create the final settings file
echo "{\"ClientSettings\":$Settings}" | jq . > "/hive/miners/custom/$CUSTOM_NAME/appsettings.json"

echo "Settings created successfully."