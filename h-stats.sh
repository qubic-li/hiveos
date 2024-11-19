#!/bin/bash

# Set the log file path
log_basename="/var/log/miner/custom/custom"
log_name="$log_basename.log"
log_head_name="${log_basename}_head.log"

# Update the configuration file path
conf_name="/hive/miners/custom/qubminer/appsettings.json"

# Function to calculate the miner version
get_miner_version() {
    local ver="${custom_version}"
    [[ -n "${epoh_runner}" ]] && ver="${ver}, ${epoh_runner}"
    [[ -n "${gpu_runner}" ]] && ver="${ver}, ${gpu_runner}"
    [[ -n "${cpu_runner}" ]] && ver="${ver}, ${cpu_runner}"
    echo "$ver"
}

# Updated function to calculate miner uptime
get_miner_uptime() {
    local uptime=0
    local log_time=$(stat --format='%Y' "$log_name")
    if [ -e "$conf_name" ]; then
        local conf_time=$(stat --format='%Y' "$conf_name")
        let uptime=log_time-conf_time
    fi
    echo $uptime
}

# Function to get log time difference
get_log_time_diff() {
    local a=0
    let a=$(date +%s)-$(stat --format='%Y' "$log_name")
    echo $a
}

# Function to extract and validate hashrate
extract_and_validate_hashrate() {
    local line="$1"
    local hashrate=$(echo "$line" | grep -oP '\d+ avg it/s' | awk '{print $1}')
    
    if [[ $hashrate =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$hashrate > 0" | bc -l) )); then
        echo "$hashrate"
    else
        echo "0"
    fi
}

# Function to get last valid hashrate
get_last_valid_hashrate() {
    local device_type="$1"
    local last_lines=$(grep -E "\[${device_type}]" "$log_name" | tail -n 20)
    local last_hashrate=0
    
    while read -r line; do
        local current_hashrate=$(extract_and_validate_hashrate "$line")
        if (( $(echo "$current_hashrate > 0" | bc -l) )); then
            last_hashrate=$current_hashrate
            break
        fi
    done <<< "$last_lines"
    
    echo "$last_hashrate"
}

# Updated function to extract shares from a log line
extract_shares() {
    local line="$1"
    local shares=$(echo "$line" | grep -oP "(SHARES|SOLS): \K\d+/\d+ \(R:\d+\)")
    local accepted=$(echo "$shares" | cut -d'/' -f2 | cut -d' ' -f1)
    local rejected=$(echo "$shares" | grep -oP "R:\K\d+")
    echo "$accepted $rejected"
}

# Extract version and runner information
custom_version=$(grep -Po "(?<=Version ).*" "$log_name" | tail -n1)
gpu_runner=$(tac "$log_name" | grep -m1 -Po "(?<=Trainer: ).*?cuda.*?(?:\d+(?:\.\d+)*)(?= is (starting|running))")
cpu_runner=$(tac "$log_name" | grep -m1 -Po "(?<=Trainer: ).*?cpu.*?(?:\d+(?:\.\d+)*)(?= is (starting|running))")
epoh_runner=$(grep -Po "E:\d+" "$log_name" | tail -n1)

# Check if the log file is recent enough
diffTime=$(get_log_time_diff)
maxDelay=300

if [ "$diffTime" -lt "$maxDelay" ]; then
    ver=$(get_miner_version)
    hs_units="hs"
    algo="qubic"
    uptime=$(get_miner_uptime)
    [[ $uptime -lt 60 ]] && head -n 150 $log_name > $log_head_name

    # Update GPU count detection
    gpu_count=$(grep -oP "\[GPU\] Trainer: \K\d+" "$log_name" | tail -n 1)
    [[ -z $gpu_count ]] && gpu_count=0

    # New CPU detection method
    cpu_count=$(grep -cE "\[(AVX512|AVX2|GENERIC)\]" "$log_name")
    [[ $cpu_count -gt 0 ]] && cpu_count=1 || cpu_count=0

    # Get CPU temperature if CPU is used
    [[ $cpu_count -eq 1 ]] && cpu_temp=$(cpu-temp) || cpu_temp=null

    # Initialize arrays and counters
    declare -a hs temp fan bus_numbers
    let ac=0 rj=0

    # Extract CPU hashrate (avg it/s)
    cpu_hs=$(get_last_valid_hashrate "(AVX512|AVX2|GENERIC)")

    # Extract individual GPU hashrates from the log format
    gpu_hashrates=$(grep "\[GPU\] Trainer:" "$log_name" | grep -v "Switching ID" | grep -v "Found a share" | grep -v "Fine-tuning completed" | tail -n $gpu_count | grep -oP "GPU #\d+: \K\d+ it/s")

    # Process GPU data
    if [[ $gpu_count -gt 0 ]]; then
        # Extract GPU shares information
        gpu_shares=$(grep "\[CUDA\]" "$log_name" | grep -E "(SHARES|SOLS):" | tail -n 1)
        if [[ -n "$gpu_shares" ]]; then
            read gpu_accepted gpu_rejected <<< $(extract_shares "$gpu_shares")
            [[ -z "$gpu_accepted" ]] && gpu_accepted=0
            [[ -z "$gpu_rejected" ]] && gpu_rejected=0
            let ac=$ac+$gpu_accepted
            let rj=$rj+$gpu_rejected
        fi

        # Extract GPU temperature, fan, and bus information
        gpu_temp=$(jq '.temp' <<< "$gpu_stats")
        gpu_fan=$(jq '.fan' <<< "$gpu_stats")
        gpu_bus=$(jq '.busids' <<< "$gpu_stats")
        if [[ $cpu_indexes_array != '[]' ]]; then
            gpu_temp=$(jq -c "del(.$cpu_indexes_array)" <<< "$gpu_temp") &&
            gpu_fan=$(jq -c "del(.$cpu_indexes_array)" <<< "$gpu_fan") &&
            gpu_bus=$(jq -c "del(.$cpu_indexes_array)" <<< "$gpu_bus")
        fi

        # Process individual GPU data
        for (( i=0; i < ${gpu_count}; i++ )); do
            hs[$i]=$(echo "$gpu_hashrates" | sed -n "$((i+1))p" | awk '{print $1}')
            [[ -z ${hs[$i]} ]] && hs[$i]=0
            temp[$i]=$(jq .[$i] <<< "$gpu_temp")
            fan[$i]=$(jq .[$i] <<< "$gpu_fan")
            busid=$(jq .[$i] <<< "$gpu_bus")
            bus_numbers[$i]=$(echo $busid | cut -d ":" -f1 | cut -c2- | awk -F: '{ printf "%d\n",("0x"$1) }')
        done
    fi

    # Process CPU stats
    if [[ $cpu_count -eq 1 ]]; then
        # Extract CPU shares information
        cpu_shares=$(grep -E "\[(AVX512|AVX2|GENERIC)\]" "$log_name" | grep -E "(SHARES|SOLS):" | tail -n 1)
        if [[ -n "$cpu_shares" ]]; then
            read cpu_accepted cpu_rejected <<< $(extract_shares "$cpu_shares")
            [[ -z "$cpu_accepted" ]] && cpu_accepted=0
            [[ -z "$cpu_rejected" ]] && cpu_rejected=0
            let ac=$ac+$cpu_accepted
            let rj=$rj+$cpu_rejected
        fi
        
        # Add CPU data to arrays
        hs+=($cpu_hs)
        temp+=($cpu_temp)
        fan+=("")
        bus_numbers+=("null")
    fi

    # Adjust shares if both GPU and CPU are in use
    if [[ $gpu_count -gt 0 && $cpu_count -eq 1 ]]; then
        ac=$((ac / 2))
        rj=$((rj / 2))
    fi

    # Calculate total GPU hashrate
    gpu_total_hs=$(tail -n 20 "$log_name" | grep -oP '\[CUDA\].*?(\d+) avg it/s' | tail -n 1 | grep -oP '\d+(?= avg it/s)')
    gpu_total_hs=${gpu_total_hs:-0} 
    
    # Calculate total hashrate (GPU + CPU)
    total_hs=$(echo "$gpu_total_hs + $cpu_hs" | bc)

    # Calculate total hashrate in khs
    if (( $(echo "$total_hs > 0" | bc -l) )); then
        khs=$(echo "scale=6; $total_hs / 1000" | bc)
    else
        khs=0
    fi

    # Prepare stats JSON
    stats=$(jq -nc \
                --arg khs "$khs" \
                --arg hs_units "$hs_units" \
                --argjson hs "$(printf '%s\n' "${hs[@]}" | jq -cs '.')" \
                --argjson temp "$(printf '%s\n' "${temp[@]}" | jq -cs '.')" \
                --argjson fan "$(printf '%s\n' "${fan[@]}" | jq -cs '.')" \
                --arg uptime "$uptime" \
                --arg ver "$ver" \
                --arg ac "$ac" --arg rj "$rj" \
                --arg algo "$algo" \
                --argjson bus_numbers "$(printf '%s\n' "${bus_numbers[@]}" | jq -cs '.')" \
                '{$hs, $hs_units, $temp, $fan, $uptime, $ver, ar: [$ac, $rj], $algo, $bus_numbers}')
else
    stats=""
    khs=0
fi

# Output results
echo $khs
echo $stats
