#!/bin/bash

# Function to calculate the miner version along with GPU and CPU information (if available).
get_miner_version() {
    local ver="${custom_version}"

    # Append GPU information to 'ver' only if 'epoh_runner' is defined.
    if [ -n "${epoh_runner}" ]; then
        ver="${ver}, ${epoh_runner}"
    fi

    # Check for "pplns cpu" or "pplns gpu" in the log and append accordingly.
    if grep -q "pplns cpu" "$log_name"; then
        ver="${ver}, PPLNS: CPU"
    elif grep -q "pplns gpu" "$log_name"; then
        ver="${ver}, PPLNS: GPU"
    fi

    # Append GPU information to 'ver' only if 'gpu_runner' is defined.
    if [ -n "${gpu_runner}" ]; then
        ver="${ver}, GPU:${gpu_runner}"
    fi

    # Append CPU information to 'ver' only if 'cpu_runner' is defined.
    if [ -n "${cpu_runner}" ]; then
        ver="${ver}, CPU:${cpu_runner}"
    fi

    echo "$ver"
}

# Function to calculate the uptime of the miner by determining the time elapsed since the last modification of the log file.
get_miner_uptime(){
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

# Function to get log time difference.
get_log_time_diff() {
    local a=0
    let a=$(date +%s)-$(stat --format='%Y' "$log_name")
    echo $a
}

# File paths and variables
log_basename="/var/log/miner/custom/custom"
log_name="$log_basename.log"
log_head_name="${log_basename}_head.log"
cpu_conf_name="/hive/miners/custom/qubminer/cpu/appsettings.json"
gpu_conf_name="/hive/miners/custom/qubminer/gpu/appsettings.json"

# Parsing the log file to retrieve version and runner information
custom_version=$(grep -Po "(?<=Starting Client ).*" "$log_name" | tail -n1)
gpu_runner=$(grep -Po "(?<=cuda version ).*(?= is)" "$log_name" | tail -n1 || grep -Po "(?<=hip version ).*(?= is)" "$log_name" | tail -n1)
cpu_runner=$(grep -Po "(?<=cpu version ).*(?= is)" "$log_name" | tail -n1)
epoh_runner=$(grep -Po "E:\d+" "$log_name" | tail -n1)

# Calculate the log time difference
diffTime=$(get_log_time_diff)
maxDelay=300

if [ "$diffTime" -lt "$maxDelay" ]; then
  ver=$(get_miner_version)
  hs_units="hs"
  algo="qubic"
  
  uptime=$(get_miner_uptime)
  [[ $uptime -lt 60 ]] && head -n 150 $log_name > $log_head_name

  # Calculating CPU and GPU count
  cpu_count=$(grep "threads are used" "$log_head_name" | tail -n 1 | awk '{print $4}')
  if [ -z "$cpu_count" ] && tail -n 1 "$log_head_name" | grep -q "Your Alias is .*-cpu"; then
    cpu_count=1
  else
    cpu_count=0
  fi

  gpu_count=$(grep -E "CUDA devices are used|ROCM devices are used" "$log_head_name" | tail -n 1 | awk '{print $4}')
  [[ -z $gpu_count ]] && gpu_count=0
  
  if [ $cpu_count -eq 0 ] || [ $gpu_count -eq 0 ]; then
    echo "..."
    grep -E "threads are used|CUDA devices are used|ROCM devices are used|Your Alias is .*-cpu" "$log_name" | tail -n 100 > $log_head_name

    cpu_count=$(grep "threads are used" "$log_head_name" | tail -n 1 | awk '{print $4}')
    if [ -z "$cpu_count" ] && tail -n 1 "$log_head_name" | grep -q "Your Alias is .*-cpu"; then
      cpu_count=1
    else
      cpu_count=0
    fi

    gpu_count=$(grep -E "CUDA devices are used|ROCM devices are used" "$log_head_name" | tail -n 1 | awk '{print $4}')
    [[ -z $gpu_count ]] && gpu_count=0
  fi
  
  cpu_temp=$(cpu-temp)
  [[ -z $cpu_temp ]] && cpu_temp=null
  
  echo ----------
  echo cpu_count: $cpu_count
  echo gpu_count: $gpu_count
  echo gpu_stats: $gpu_stats
  echo cpu_indexes_array: $cpu_indexes_array
  echo ----------

  if [[ $gpu_count -ge 0 ]]; then
    gpu_hs=$(grep "^GPU" "$log_name" | tail -n 50 | grep -oP "\d+ it/s" | tail -n 1 | awk '{print $1}')
    gpu_found=$(grep "^GPU" "$log_name" | tail -n 50 | awk -F" | " '{print $2}' | awk '{print $1}' | cut -d "/" -f1)
    gpu_submit=$(grep "^GPU" "$log_name" | tail -n 50 | awk -F" | " '{print $2}' | awk '{print $1}' | cut -d "/" -f2)
    gpu_temp=$(jq '.temp' <<< "$gpu_stats")
    gpu_fan=$(jq '.fan' <<< "$gpu_stats")
    gpu_bus=$(jq '.busids' <<< "$gpu_stats")
  	if [[ $cpu_indexes_array != '[]' ]]; then
  		gpu_temp=$(jq -c "del(.$cpu_indexes_array)" <<< "$gpu_temp") &&
  		gpu_fan=$(jq -c "del(.$cpu_indexes_array)" <<< "$gpu_fan") &&
  		gpu_bus=$(jq -c "del(.$cpu_indexes_array)" <<< "$gpu_bus")
    fi
    let gpu_hs_tot=0

    for (( i=0; i < ${gpu_count}; i++ )); do
      hs[$i]=$(grep "^GPU#$i" "$log_name" | tail -n 100 | grep -oP "\d+ it/s" | tail -n 1 | awk '{print $1}')
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
        [[ -z ${hs[$i]} ]] && hs[$i]=0
        let gpu_hs_tot=$gpu_hs_tot+${hs[$i]}
      done
    fi
    if [[ $gpu_hs_tot -eq 0 ]]; then
      for (( i=0; i < ${gpu_count}; i++ )); do
        hs[$i]=$(printf "%.1f\n" $((10 * $gpu_hs / $gpu_count))e-1)
      done
    fi
  fi
  if [[ $cpu_count -ge 0 ]]; then
    cpu_hs=$(grep "^CPU" "$log_name" | tail -n 50 | grep -oP "\d+ it/s" | tail -n 1 | awk '{print $1}')
    cpu_found=$(grep "^CPU" "$log_name" | tail -n 50 | awk -F" | " '{print $2}' | awk '{print $1}' | cut -d "/" -f1)
    cpu_submit=$(grep "^CPU" "$log_name" | tail -n 50 | awk -F" | " '{print $2}' | awk '{print $1}' | cut -d "/" -f2)
    hs[$gpu_count]=$(grep "^CPU" "$log_name" | tail -n 50 | grep -oP "\d+ it/s" | tail -n 1 | awk '{print $1}')
    temp[$gpu_count]="$cpu_temp"
    fan[$gpu_count]=""
    bus_numbers[$gpu_count]="null"
  fi
  
  [[ $gpu_hs = "" ]] && gpu_hs=0
  [[ $gpu_found = "" ]] && gpu_found=0
  [[ $gpu_submit = "" ]] && gpu_submit=0
  [[ $cpu_hs = "" ]] && cpu_hs=0
  [[ $cpu_found = "" ]] && cpu_found=0
  [[ $cpu_submit = "" ]] && cpu_submit=0
  
  let khs=$gpu_hs+$cpu_hs
  let ac=$gpu_found+$cpu_found
  let rj=$gpu_submit+$cpu_submit-$ac

  khs=$(echo $khs | awk '{print $1/1000}')

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

 echo khs:   $khs
 echo stats: $stats
 echo ----------
