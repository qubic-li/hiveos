#!/bin/bash

# Set the log file path
log_name="/path/to/your/logfile.log"

# Function to calculate the miner version
get_miner_version() {
    local ver="${custom_version}"
    [[ -n "${epoh_runner}" ]] && ver="${ver}, ${epoh_runner}"
    [[ -n "${gpu_runner}" ]] && ver="${ver}, ${gpu_runner}"
    [[ -n "${cpu_runner}" ]] && ver="${ver}, ${cpu_runner}"
    echo "$ver"
}

# Function to calculate miner uptime
get_miner_uptime() {
    local uptime=0
    local log_time=$(stat --format='%Y' "$log_name")
    if [ -e "$cpu_conf_name" ]; then
        local conf_time=$(stat --format='%Y' "$cpu_conf_name")
        let uptime=log_time-conf_time
    elif [ -e "$gpu_conf_name" ]; then
        local conf_time=$(stat --format='%Y' "$gpu_conf_name")
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

# Set file paths
log_basename="/var/log/miner/custom/custom"
log_name="$log_basename.log"
log_head_name="${log_basename}_head.log"
cpu_conf_name="/hive/miners/custom/qubminer/cpu/appsettings.json"
gpu_conf_name="/hive/miners/custom/qubminer/gpu/appsettings.json"

# Extract version and runner information
custom_version=$(grep -Po "(?<=Version ).*" "$log_name" | tail -n1)
gpu_runner=$(grep -Po "(?<=Trainer: ).*(?= is starting)" "$log_name" | grep -i "cuda\|hip" | tail -n1)
cpu_runner=$(grep -Po "(?<=Trainer: ).*(?= is starting)" "$log_name" | grep -i "cpu" | tail -n1)
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

    # Detect CPU and GPU usage
    cpu_count=$(grep "threads are used" "$log_name" | tail -n 1 | cut -d " " -f4)
    [[ -z "$cpu_count" ]] && grep -q "Your Alias is .*-cpu" "$log_name" && cpu_count=1
    [[ -z "$cpu_count" ]] && cpu_count=0

    gpu_count=$(grep -E "CUDA devices are used|ROCM devices are used" "$log_name" | tail -n 1 | cut -d " " -f4)
    [[ -z $gpu_count ]] && gpu_count=0

    # Fallback detection if no CPU or GPU found
    if [ $cpu_count -eq 0 ] && [ $gpu_count -eq 0 ]; then
        grep -q "CPU" "$log_name" && cpu_count=1
        grep -q "GPU" "$log_name" && gpu_count=1
    fi

    # Get CPU temperature if CPU is used
    [[ $cpu_count -gt 0 ]] && cpu_temp=$(cpu-temp) || cpu_temp=null

    # Initialize arrays and counters
    declare -a hs temp fan bus_numbers
    let gpu_hs_tot=0 cpu_hs_tot=0 ac=0 rj=0

    # Extract total GPU hashrate using the same logic as CPU (last line only)
    gpu_hs=$(grep "^GPU" "$log_name" | tail -n 1 | awk -F'|' '{print $4}' | awk '{print $1}')
    [[ -z $gpu_hs ]] && gpu_hs=0
    let gpu_hs_tot=$gpu_hs

    # Process individual GPU data
    if [[ $gpu_count -gt 0 ]]; then
        # Extract GPU shares information
        gpu_shares=$(grep "GPU" "$log_name" | grep -E "Shares:|SOL:" | tail -n 1)
        gpu_found=$(echo "$gpu_shares" | awk -F'|' '{print $2}' | awk '{print $2}' | cut -d '/' -f1)
        gpu_submit=$(echo "$gpu_shares" | awk -F'|' '{print $2}' | awk '{print $2}' | cut -d '/' -f2)
        [[ -z "$gpu_found" ]] && gpu_found=0
        [[ -z "$gpu_submit" ]] && gpu_submit=0
        let ac=$ac+$gpu_found
        let rj=$rj+$((gpu_submit-gpu_found))

        # Extract GPU temperature, fan, and bus information
        gpu_temp=$(jq '.temp' <<< "$gpu_stats")
        gpu_fan=$(jq '.fan' <<< "$gpu_stats")
        gpu_bus=$(jq '.busids' <<< "$gpu_stats")
        if [[ $cpu_indexes_array != '[]' ]]; then
            gpu_temp=$(jq -c "del(.$cpu_indexes_array)" <<< "$gpu_temp") &&
            gpu_fan=$(jq -c "del(.$cpu_indexes_array)" <<< "$gpu_fan") &&
            gpu_bus=$(jq -c "del(.$cpu_indexes_array)" <<< "$gpu_bus")
        fi

        for (( i=0; i < ${gpu_count}; i++ )); do
            hs[$i]=$(grep -oP "GPU #$i: \K\d+(?= it/s)" "$log_name" | tail -n 1)
            [[ -z ${hs[$i]} ]] && hs[$i]=0
            temp[$i]=$(jq .[$i] <<< "$gpu_temp")
            fan[$i]=$(jq .[$i] <<< "$gpu_fan")
            busid=$(jq .[$i] <<< "$gpu_bus")
            bus_numbers[$i]=$(echo $busid | cut -d ":" -f1 | cut -c2- | awk -F: '{ printf "%d\n",("0x"$1) }')
        done
    fi

    # Process CPU stats
    if [[ $cpu_count -gt 0 ]]; then
        # Extract CPU shares information
        cpu_shares=$(grep "^CPU" "$log_name" | grep -E "Shares:|SOL:" | tail -n 1)
        cpu_found=$(echo "$cpu_shares" | awk -F'|' '{print $2}' | awk '{print $2}' | cut -d '/' -f1)
        cpu_submit=$(echo "$cpu_shares" | awk -F'|' '{print $2}' | awk '{print $2}' | cut -d '/' -f2)
        [[ -z "$cpu_found" ]] && cpu_found=0
        [[ -z "$cpu_submit" ]] && cpu_submit=0
        let ac=$ac+$cpu_found
        let rj=$rj+$((cpu_submit-cpu_found))

        # Extract CPU hashrate using the last line only
        cpu_hs=$(grep "^CPU" "$log_name" | tail -n 1 | awk -F'|' '{print $4}' | awk '{print $1}')
        [[ -z $cpu_hs ]] && cpu_hs=0
        let cpu_hs_tot=$cpu_hs
        
        # Add CPU data to arrays
        hs+=($cpu_hs_tot)
        temp+=($cpu_temp)
        fan+=("")
        bus_numbers+=("null")
    fi

    # Calculate total hashrate
    let khs=$gpu_hs_tot+$cpu_hs_tot
    khs=$(echo $khs | awk '{print $1/1000}')

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
