process_user_config() {
    while IFS= read -r line; do
        [[ -z $line ]] && continue

        # Check if the line starts with nvtool and execute it using eval
        if [[ ${line:0:7} = "nvtool " ]]; then
            eval "$line"
        elif [[ ${line:0:10} = "AutoUpdate" ]]; then
            # Local file
            LOCAL_FILE="/hive/miners/custom/downloads/qubminer-latest.tar.gz"

			if [ -e $LOCAL_FILE ]; then

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
			fi
        else
            # Extract parameter and its value from the configuration line
            param=$(awk -F':' '{gsub(/\"/, ""); print $1}' <<< "$line")
            value=$(awk -F':' '{gsub(/^[[:space:]]*/, ""); print substr($0, length($1) + 2)}' <<< "$line")

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
                gsub("IDLESETTINGS", "idleSettings");
                gsub("ISPPS=", "\"isPps\": ");
                gsub("USELIVECONNECTION", "useLiveConnection");
                gsub("TRAINER", "trainer");
                print $0;
            }')

            # Check if modifications were made, if not, use the original parameter
            [[ "$param" != "$modified_param" ]] && param=$modified_param

            # Handle cpuOnly parameter with additional 'yes' and '"yes"' options
            if [[ "$param" == "cpuOnly" ]]; then
                if [[ "$value" == "\"true\"" || "$value" == "true" || "$value" == "\"yes\"" || "$value" == "yes" ]]; then
                    Settings=$(jq --arg value "true" '.cpuOnly = $value' <<< "$Settings")
                    SettingsGpu=$(jq --arg value "true" '.cpuOnly = $value' <<< "$SettingsGpu")
                else
                    echo "Invalid value for cpuOnly: $value. It must be '\"true\"', 'true', '\"yes\"', or 'yes'. Skipping this entry."
                fi
                continue
            fi

            # General processing for other parameters
            if [[ ! -z "$value" ]]; then
                if [[ "$param" == "overwrites" || "$param" == "trainer" ]]; then
                    Settings=$(jq -s '.[0] * .[1]' <<< "$Settings {$line}")
                    SettingsGpu=$(jq -s '.[0] * .[1]' <<< "$SettingsGpu {$line}")
                elif [[ "$param" == "idleSettings" ]]; then
                    gpuOnly=$(jq -r '.gpuOnly // empty' <<< "$value")
                    if [[ "$gpuOnly" == "true" ]]; then
                        value=$(jq 'del(.gpuOnly)' <<< "$value")
                        SettingsGpu=$(jq --argjson idleSettings "$value" '.idleSettings = $idleSettings' <<< "$SettingsGpu")
                    else
                        Settings=$(jq --argjson idleSettings "$value" '.idleSettings = $idleSettings' <<< "$Settings")
                    fi
                elif [[ "$param" == "accessToken" ]]; then
                    value=$(echo "$value" | sed 's/^"//;s/"$//')
                    Settings=$(jq --arg value "$value" '.accessToken = $value' <<< "$Settings")
                    SettingsGpu=$(jq --arg value "$value" '.accessToken = $value' <<< "$SettingsGpu")
                elif [[ "$param" == "isPps" ]]; then
                    if [[ "$value" == "true" || "$value" == "false" ]]; then
                        Settings=$(jq --argjson value "$value" '.isPps = $value' <<< "$Settings")
                        SettingsGpu=$(jq --argjson value "$value" '.isPps = $value' <<< "$SettingsGpu")
                    else
                        echo "Invalid value for isPps: $value. It must be 'true' or 'false'. Skipping this entry."
                    fi
                elif [[ "$param" == "useLiveConnection" ]]; then
                    if [[ "$value" == "true" || "$value" == "false" ]]; then
                        Settings=$(jq --argjson value "$value" '.useLiveConnection = $value' <<< "$Settings")
                        SettingsGpu=$(jq --argjson value "$value" '.useLiveConnection = $value' <<< "$SettingsGpu")
                    else
                        echo "Invalid value for useLiveConnection: $value. It must be 'true' or 'false'. Skipping this entry."
                    fi
                else
                    if [[ "$param" == "trainer.cpuVersion" ]]; then
                        Settings=$(jq --arg value "$value" '.trainer.cpuVersion = $value' <<< "$Settings")
                    elif [[ "$param" == "trainer.gpuVersion" ]]; then
                        SettingsGpu=$(jq --arg value "$value" '.trainer.gpuVersion = $value' <<< "$SettingsGpu")
                    elif [[ "$value" == "null" ]]; then
                        Settings=$(jq --arg param "$param" '.[$param] = null' <<< "$Settings")
                        SettingsGpu=$(jq --arg param "$param" '.[$param] = null' <<< "$SettingsGpu")
                    elif [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        Settings=$(jq --arg param "$param" --argjson value "$value" '.[$param] = ($value | tonumber)' <<< "$Settings")
                        SettingsGpu=$(jq --arg param "$param" --argjson value "$value" '.[$param] = ($value | tonumber)' <<< "$SettingsGpu")
                    else
                        Settings=$(jq --arg param "$param" --arg value "$value" '.[$param] = $value' <<< "$Settings")
                        SettingsGpu=$(jq --arg param "$param" --arg value "$value" '.[$param] = $value' <<< "$SettingsGpu")
                    fi
                fi
            fi
        fi
    done <<< "$CUSTOM_USER_CONFIG"
}

# Main script logic

# Processing global settings
Settings=$(jq -r '.Settings' "/hive/miners/custom/$CUSTOM_NAME/appsettings_global.json" | envsubst)

# Initialize GPU settings as well
SettingsGpu=$Settings

# Delete old settings
eval "rm -rf /hive/miners/custom/$CUSTOM_NAME/cpu/appsettings.json"
eval "rm -rf /hive/miners/custom/$CUSTOM_NAME/gpu/appsettings.json"

# Processing the template
if [[ ! -z $CUSTOM_TEMPLATE ]]; then
    Settings=$(jq --null-input --argjson Settings "$Settings" --arg alias "$CUSTOM_TEMPLATE" '$Settings + {$alias}')
    SettingsGpu=$(jq --null-input --argjson SettingsGpu "$SettingsGpu" --arg alias "$CUSTOM_TEMPLATE" '$SettingsGpu + {$alias}')
fi

# Processing user configuration
[[ ! -z $CUSTOM_USER_CONFIG ]] && process_user_config

# Adding URL settings
if [[ ! -z $CUSTOM_URL ]]; then
    Settings=$(jq --null-input --argjson Settings "$Settings" --arg baseUrl "$CUSTOM_URL" '$Settings + {$baseUrl}')
    SettingsGpu=$(jq --null-input --argjson SettingsGpu "$SettingsGpu" --arg baseUrl "$CUSTOM_URL" '$SettingsGpu + {$baseUrl}')
fi

# Check and modify Settings for hugePages parameter
if [[ $(jq '.hugePages' <<< "$Settings") != null ]]; then
    hugePages=$(jq -r '.hugePages' <<< "$Settings")
    if [[ ! -z $hugePages && $hugePages -gt 0 ]]; then
        eval "sysctl -w vm.nr_hugepages=$hugePages"
    fi
fi

# Additional check in the Settings for only CPU mining
if [[ $(jq '.cpuOnly == "true" or .amountOfThreads != 0' <<< "$Settings") == true ]]; then
    Settings=$(jq '.alias |= . + "-cpu" | .trainer.cpu = true | .trainer.gpu = false | .allowHwInfoCollect = false | del(.overwrites.CUDA)' <<< "$Settings")
    echo "{\"Settings\":$Settings}" | jq . > "/hive/miners/custom/$CUSTOM_NAME/cpu/appsettings.json"
fi

# Additional check and modification in the Settings for GPU mining
if [[ $(jq '.cpuOnly == "true"' <<< "$Settings") == false ]]; then
    SettingsGpu=$(jq '.alias |= . + "-gpu" | .trainer.cpu = false | .trainer.gpu = true | .amountOfThreads = 0 | del(.hugePages)' <<< "$SettingsGpu")
    echo "{\"Settings\":$SettingsGpu}" | jq . > "/hive/miners/custom/$CUSTOM_NAME/gpu/appsettings.json"
fi
