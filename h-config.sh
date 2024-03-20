# Function for processing user configuration
process_user_config() {
    while IFS= read -r line; do
        [[ -z $line ]] && continue
        # Check if the line starts with 'nvtool ' and execute it using eval
        if [[ ${line:0:7} = "nvtool " ]]; then
            eval "$line"
        else
            # Extract parameter and its value from the configuration line
            param=$(awk -F':' '{gsub(/\"/, ""); gsub(/[[:space:]]/, ""); print $1}' <<< "$line")
            value=$(awk -F':' '{gsub(/\"/, ""); gsub(/[[:space:]]/, ""); print substr($0, length($1) + 2)}' <<< "$line")

            # Convert parameter to uppercase
            param_high=$(echo "$param" | tr '[:lower:]' '[:upper:]')

            # Perform replacements in the parameter
            modified_param=$(echo "$param_high" | awk '{
                gsub("PAYOUTID", "payoutId");
                gsub("AMOUNTOFTHREADS", "amountOfThreads");
                gsub("ACCESSTOKEN", "accessToken");
                gsub("ALLOWHWINFOCOLLECT", "allowHwInfoCollect");
                gsub("HUGEPAGES", "hugePages");
                gsub("CPUONLY", "cpuOnly");
                gsub("ALIAS", "alias");
                gsub("OVERWRITES", "overwrites");
                print $0;
            }')

            # Check if modifications were made, if not, use original parameter
            [[ "$param" != "$modified_param" ]] && param=$modified_param

            # Check if value exists before updating Settings
            if [[ ! -z "$value" ]]; then
              if [[ "$param" == "overwrites" ]]; then
                    Settings=$(jq -s '.[0] * .[1]' <<< "$Settings {$line}")
                else
                    # Update settings with the extracted parameter and its value
                    if [[ "$value" == "null" ]]; then
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
Settings=$(jq -r '.Settings' "/hive/miners/custom/$CUSTOM_NAME/appsettings_global.json" | envsubst)

# Delete old settings
eval "rm -rf /hive/miners/custom/$CUSTOM_NAME/cpu/appsettings.json"
eval "rm -rf /hive/miners/custom/$CUSTOM_NAME/gpu/appsettings.json"

# Processing the template
if [[ ! -z $CUSTOM_TEMPLATE ]]; then
    Settings=$(jq --null-input --argjson Settings "$Settings" --arg alias "$CUSTOM_TEMPLATE" '$Settings + {$alias}')
fi

# Processing user configuration
[[ ! -z $CUSTOM_USER_CONFIG ]] && process_user_config

# Adding URL settings
[[ ! -z $CUSTOM_URL ]] && Settings=$(jq --null-input --argjson Settings "$Settings" --arg baseUrl "$CUSTOM_URL" '$Settings + {$baseUrl}')

# Check and modify Settings for hugePages parameter
if [[ $(jq '.hugePages' <<< "$Settings") != null ]]; then
    hugePages=$(jq -r '.hugePages' <<< "$Settings")
    if [[ ! -z $hugePages && $hugePages -gt 0 ]]; then
        eval "sysctl -w vm.nr_hugepages=$hugePages"
    fi
fi

# Additional check in the Settings for only CPU mining
if [[ $(jq '.cpuOnly == "yes"' <<< "$Settings") == false ]]; then
  SettingsGpu=$(jq '.alias |= . + "-gpu" | .amountOfThreads = 0 | del(.hugePages)' <<< "$Settings")
  echo "{\"Settings\":$SettingsGpu}" | jq . > "/hive/miners/custom/$CUSTOM_NAME/gpu/appsettings.json"
fi

# Additional check and modification in the Settings for CPU mining
if [[ $(jq '.cpuOnly == "yes" or .amountOfThreads != 0' <<< "$Settings") == true ]]; then
  Settings=$(jq '.alias |= . + "-cpu" | .allowHwInfoCollect = false | del(.overwrites.CUDA)' <<< "$Settings")
  echo "{\"Settings\":$Settings}" | jq . > "/hive/miners/custom/$CUSTOM_NAME/cpu/appsettings.json"
fi
