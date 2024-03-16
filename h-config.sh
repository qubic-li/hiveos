# Функция для обработки пользовательской конфигурации
process_user_config() {
    while IFS= read -r line; do
        [[ -z $line ]] && continue
        if [[ ${line:0:7} = "nvtool " ]]; then
            eval "$line"
        else
            Settings=$(jq -s '.[0] * .[1]' <<< "$Settings {$line}")
        fi
    done <<< "$CUSTOM_USER_CONFIG"
}

# Основная логика скрипта

# Обработка глобальных настроек
conf=$(cat "/hive/miners/custom/$CUSTOM_NAME/appsettings_global.json" | envsubst)
Settings=$(jq -r .Settings <<< "$conf")

# Обработка шаблона
if [[ ! -z $CUSTOM_TEMPLATE ]]; then
    if [[ ${#CUSTOM_TEMPLATE} -lt 60 ]]; then
        Settings=$(jq --null-input --argjson Settings "$Settings" --arg alias "$CUSTOM_TEMPLATE" '$Settings + {$alias}')
    elif [[ ${#CUSTOM_TEMPLATE} -eq 60 ]]; then
        Settings=$(jq --null-input --argjson Settings "$Settings" --arg payoutId "$CUSTOM_TEMPLATE" '$Settings + {$payoutId}')
    else
        wallet=${CUSTOM_TEMPLATE%.*}
        len=${#wallet}
        alias=${CUSTOM_TEMPLATE:len}
        alias=${alias#*.}
        Settings=$(jq --null-input --argjson Settings "$Settings" --arg alias "$alias" '$Settings + {$alias}')
        if [[ ${#wallet} -eq 60 ]]; then
            Settings=$(jq --null-input --argjson Settings "$Settings" --arg payoutId "$wallet" '$Settings + {$payoutId}')
        else
            Settings=$(jq --null-input --argjson Settings "$Settings" --arg accessToken "$wallet" '$Settings + {$accessToken}')
        fi
    fi
fi

# Обработка пользовательской конфигурации
[[ ! -z $CUSTOM_USER_CONFIG ]] && process_user_config

# Добавление настроек URL
[[ ! -z $CUSTOM_URL ]] && Settings=$(jq --null-input --argjson Settings "$Settings" --arg baseUrl "$CUSTOM_URL" '$Settings + {$baseUrl}')

# Формирование конечной конфигурации
conf=$(jq --null-input --argjson Settings "$Settings" '{$Settings}')
echo "$conf" | jq . > "$CUSTOM_CONFIG_FILENAME"
