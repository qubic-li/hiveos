#!/bin/bash

log_name="/path/to/your/logfile.log"

# Define a function to calculate the miner version along with GPU and CPU information (if available).
get_miner_version() {
    local ver="${custom_version}"

    # Append Epoch information to 'ver' only if 'epoh_runner' is defined.
    if [ -n "${epoh_runner}" ]; then
        ver="${ver}, ${epoh_runner}"
    fi

    # Append GPU runner information if defined, without "GPU:" prefix
    if [ -n "${gpu_runner}" ]; then
        ver="${ver}, ${gpu_runner}"
    fi

    # Append CPU runner information if defined, without "CPU:" prefix
    if [ -n "${cpu_runner}" ]; then
        ver="${ver}, ${cpu_runner}"
    fi

    echo "$ver"
}

# This function calculates the uptime of the miner by determining the time elapsed since the last modification of the log file.
get_miner_uptime() {
    local uptime=0
    local log_time=$(stat --format='%Y' "$log_name")

    # Check if the CPU configuration file exists. If it does, get its last modification time.
    if [ -e "$cpu_conf_name" ]; then
        local conf_time=$(stat --format='%Y' "$cpu_conf_name")
        let uptime=log_time-conf_time

    # If CPU config file doesn't exist, check if GPU config file exists. If it does, get its last modification time.
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

log_basename="/var/log/miner/custom/custom"
log_name="$log_basename.log"
log_head_name="${log_basename}_head.log"
cpu_conf_name="/hive/miners/custom/qubminer/cpu/appsettings.json"
gpu_conf_name="/hive/miners/custom/qubminer/gpu/appsettings.json"

custom_version=$(grep -Po "(?<=Starting Client ).*" "$log_name" | tail -n1)

# New Runner Parsing: Extracting 'pplns cuda' and 'pplns cpu' from the log file
gpu_runner=$(grep -Po "(?<=Trainer: ).*(?= is starting)" "$log_name" | grep -i "cuda\|hip" | tail -n1)
cpu_runner=$(grep -Po "(?<=Trainer: ).*(?= is starting)" "$log_name" | grep -i "cpu" | tail -n1)

# Epoch Runner Parsing
epoh_runner=$(grep -Po "E:\d+" "$log_name" | tail -n1)

diffTime=$(get_log_time_diff)
maxDelay=300

if [ "$diffTime" -lt "$maxDelay" ]; then
    ver=$(get_miner_version)
    hs_units="hs"
    algo="qubic"
    
    uptime=$(get_miner_uptime)
    [[ $uptime -lt 60 ]] && head -n 150 $log_name > $log_head_name

    # Calculating CPU and GPU count
    cpu_count=$(grep "threads are used" "$log_head_name" | tail -n 1 | cut -d " " -f4)
    if [ -z "$cpu_count" ] && tail -n 1 "$log_head_name" | grep -q "Your Alias is .*-cpu"; then
        cpu_count=1
    else
        cpu_count=0
    fi

    gpu_count=$(grep -E "CUDA devices are used|ROCM devices are used" "$log_head_name" | tail -n 1 | cut -d " " -f4)
    [[ -z $gpu_count ]] && gpu_count=0

    if [ $cpu_count -eq 0 ] || [ $gpu_count -eq 0 ]; then
        echo "..."
        grep -E "threads are used|CUDA devices are used|ROCM devices are used|Your Alias is .*-cpu" "$log_name" | tail -n 100 > $log_head_name

        cpu_count=$(grep "threads are used" "$log_head_name" | tail -n 1 | cut -d " " -f4)
        if [ -z "$cpu_count" ] && tail -n 1 "$log_head_name" | grep -q "Your Alias is .*-cpu"; then
            cpu_count=1
        else
            cpu_count=0
        fi

        gpu_count=$(grep -E "CUDA devices are used|ROCM devices are used" "$log_head_name" | tail -n 1 | cut -d " " -f4)
        [[ -z $gpu_count ]] && gpu_count=0
    fi

    # Only gather CPU temperature if CPUs are being used
    if [[ $cpu_count -gt 0 ]]; then
        cpu_temp=$(cpu-temp)
        [[ -z $cpu_temp ]] && cpu_temp=null
    else
        cpu_temp=null
    fi

    echo ----------
    echo "CPU Count: $cpu_count"
    echo "GPU Count: $gpu_count"
    echo "Runner Info: $ver"
    echo ----------

    # Initialize total hashrate variables
    let gpu_hs_tot=0
    let cpu_hs_tot=0
    let ac=0
    let rj=0

    # Parse all GPU shares
    gpu_shares=$(grep "GPU" "$log_name" | grep "Shares:" | tail -n 1)
    gpu_found=$(echo "$gpu_shares" | awk -F'|' '{print $2}' | awk '{print $2}' | cut -d '/' -f1)
    gpu_submit=$(echo "$gpu_shares" | awk -F'|' '{print $2}' | awk '{print $2}' | cut -d '/' -f2)

    # Ensure parsed values are not empty
    [[ -z "$gpu_found" ]] && gpu_found=0
    [[ -z "$gpu_submit" ]] && gpu_submit=0

    let ac=$ac+$gpu_found
    let rj=$rj+$((gpu_submit-gpu_found))

    if [[ $gpu_count -gt 0 ]]; then
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
            echo "Hashrate for GPU#$i: ${hs[$i]}"
            [[ -z ${hs[$i]} ]] && hs[$i]=0
            let gpu_hs_tot=$gpu_hs_tot+${hs[$i]}
            temp[$i]=$(jq .[$i] <<< "$gpu_temp")
            fan[$i]=$(jq .[$i] <<< "$gpu_fan")
            busid=$(jq .[$i] <<< "$gpu_bus")
            bus_numbers[$i]=$(echo $busid | cut -d ":" -f1 | cut -c2- | awk -F: '{ printf "%d\n",("0x"$1) }')
        done

        if [[ $gpu_hs_tot -eq 0 ]]; then
            for (( i=0; i < ${gpu_count}; i++ )); do
                hs[$i]=$(grep -oP "GPU #$i: \K\d+(?= it/s)" "$log_name" | tail -n 1)
                echo "Fallback Hashrate for GPU#$i: ${hs[$i]}"
                [[ -z ${hs[$i]} ]] && hs[$i]=0
                let gpu_hs_tot=$gpu_hs_tot+${hs[$i]}
            done
        fi
    fi

    if [[ $cpu_count -gt 0 ]]; then
        # Extract CPU hashrate by searching for the second '|' and getting the it/s value
        cpu_hs=$(grep "^CPU" "$log_name" | tail -n 1 | awk -F'|' '{print $3}' | awk '{print $1}')
        echo "Extracted CPU Hashrate: $cpu_hs"
        [[ -z $cpu_hs ]] && cpu_hs=0
        let cpu_hs_tot=$cpu_hs_tot+$cpu_hs
        hs[$gpu_count]=$cpu_hs_tot
        temp[$gpu_count]="$cpu_temp"
        fan[$gpu_count]=""
        bus_numbers[$gpu_count]="null"

        # Parse CPU shares
        cpu_shares=$(grep "^CPU" "$log_name" | grep "Shares:" | tail -n 1)
        cpu_found=$(echo "$cpu_shares" | awk -F'|' '{print $2}' | awk '{print $2}' | cut -d '/' -f1)
        cpu_submit=$(echo "$cpu_shares" | awk -F'|' '{print $2}' | awk '{print $2}' | cut -d '/' -f2)

        # Ensure parsed values are not empty
        [[ -z "$cpu_found" ]] && cpu_found=0
        [[ -z "$cpu_submit" ]] && cpu_submit=0

        let ac=$ac+$cpu_found
        let rj=$rj+$((cpu_submit-cpu_found))
    fi

    # Aggregate GPU and CPU hashrates
    let khs=$gpu_hs_tot+$cpu_hs_tot
    khs=$(echo $khs | awk '{print $1/1000}')

    echo "Calculated Total Hashrate (khs): $khs"
    echo "Total Accepted Shares: $ac, Total Rejected Shares: $rj"

    stats=$(jq -nc \
                --arg khs "$khs" \
                --arg hs_units "$hs_units" \
                --argjson hs "$(echo ${hs[@]} | tr " " "\n" | jq -cs '.')" \
                --argjson temp "$(echo ${temp[@]} | tr " " "\n" | jq -cs '.')" \
                --argjson fan "$(echo ${fan[@]} | tr " " "\n" | jq -cs '.')" \
                --arg uptime "$uptime" \
                --arg ver "$ver" \
                --arg ac "$ac" --arg rj "$rj" \
                --arg algo "$algo" \
                --argjson bus_numbers "$(echo ${bus_numbers[@]} | tr " " "\n" | jq -cs '.')" \
                '{$hs, $hs_units, $temp, $fan, $uptime, $ver, ar: [$ac, $rj], $algo, $bus_numbers}')

else
    stats=""
    khs=0
fi

echo "khs: $khs"
echo "stats: $stats"
echo "----------"
