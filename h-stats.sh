get_miner_uptime(){
  local a=0
  let a=`stat --format='%Y' $log_name`-`stat --format='%Y' $conf_name`
  echo $a
}

get_log_time_diff(){
  local a=0
  let a=`date +%s`-`stat --format='%Y' $log_name`
  echo $a
}


log_basename="/var/log/miner/custom/custom"
log_name="$log_basename.log"
log_head_name="${log_basename}_head.log"
conf_name="/hive/miners/custom/qubminer/appsettings.json"
custom_version=$(cat ${log_name} | grep -Po "(?<=(Starting Client )).*" | tail -n1)
runner=$(cat ${log_name} | grep -Po "(?<=(version )).*(?= is)" | tail -n1)


diffTime=$(get_log_time_diff)
maxDelay=250


if [ "$diffTime" -lt "$maxDelay" ]; then

  ver="${custom_version} r${runner}"
  hs_units="hs"
  algo="qubic"
  
  uptime=$(get_miner_uptime)
  [[ $uptime -lt 60 ]] && head -n 50 $log_name > $log_head_name
  
  cpu_count=`cat $log_head_name | tail -n 50 | grep "threads are used" | tail -n 1 | cut -d " " -f3`
  [[ $cpu_count = "" ]] && cpu_count=0
  gpu_count=`cat $log_head_name | tail -n 50 | grep "CUDA devices are used" | tail -n 1 | cut -d " " -f3`
  [[ $gpu_count = "" ]] && gpu_count=0
  
  if [ $cpu_count -eq 0 ] && [ $gpu_count -eq 0 ]; then
    echo ...
    cat $log_name | grep -E "threads are used|CUDA devices are used" | tail -n 10 > $log_head_name
    cpu_count=`cat $log_head_name | tail -n 50 | grep "threads are used" | tail -n 1 | cut -d " " -f3`
    [[ $cpu_count = "" ]] && cpu_count=0
    gpu_count=`cat $log_head_name | tail -n 50 | grep "CUDA devices are used" | tail -n 1 | cut -d " " -f3`
    [[ $gpu_count = "" ]] && gpu_count=0
  fi
  
  cpu_temp=`cpu-temp`
  [[ $cpu_temp = "" ]] && cpu_temp=null
  
  hs_tot=`cat $log_name | tail -n 50 | grep "Try " | tail -n 1 | cut -d " " -f11`
  [[ -z $hs_tot ]] && hs_tot=0
  khs=`cat $log_name | tail -n 50 | grep "Try " | tail -n 1 | cut -d " " -f14 | awk '{print $1/1000}'`
  ac=`cat $log_name | tail -n 50 | grep "Try " | tail -n 1 | cut -d " " -f5 | cut -d "/" -f1`
  rj=0
  
  echo ----------
  echo cpu_count: $cpu_count
  echo gpu_count: $gpu_count
  echo gpu_stats: $gpu_stats
  echo cpu_indexes_array: $cpu_indexes_array
  echo ----------
  
  if [[ $gpu_count -eq 0 ]]; then
    # CPU
    hs[0]=`cat $log_name | tail -n 50 | grep "Try " | tail -n 1 | cut -d " " -f11`
    temp[0]=$cpu_temp
    fan[0]=""
    bus_numbers[0]="null"
  else
    # GPUs
    gpu_temp=$(jq '.temp' <<< $gpu_stats)
    gpu_fan=$(jq '.fan' <<< $gpu_stats)
    gpu_bus=$(jq '.busids' <<< $gpu_stats)
  	if [[ $cpu_indexes_array != '[]' ]]; then
  		gpu_temp=$(jq -c "del(.$cpu_indexes_array)" <<< $gpu_temp) &&
  		gpu_fan=$(jq -c "del(.$cpu_indexes_array)" <<< $gpu_fan) &&
  		gpu_bus=$(jq -c "del(.$cpu_indexes_array)" <<< $gpu_bus)
    fi
    
    let gpu_hs_tot=0
    for (( i=0; i < ${gpu_count}; i++ )); do
      hs[$i]=`cat $log_name | tail -n 50 | grep "GPU#$i" | grep "iters/sec" | tail -n 1 | cut -d ":" -f6 | cut -d " " -f2`
      [[ -z ${hs[$i]} ]] && hs[$i]=0
      let gpu_hs_tot=$gpu_hs_tot+${hs[$i]}
      temp[$i]=$(jq .[$i] <<< $gpu_temp)
      fan[$i]=$(jq .[$i] <<< $gpu_fan)
      busid=$(jq .[$i] <<< $gpu_bus)
      bus_numbers[$i]=`echo $busid | cut -d ":" -f1 | cut -c2- | awk -F: '{ printf "%d\n",("0x"$1) }'`
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
        hs[$i]=`printf "%.1f\n" $((10 * $hs_tot / $gpu_count))e-1`
      done
    fi
  fi

  stats=$(jq -nc \
            --arg khs "$khs" \
            --arg hs_units "$hs_units" \
            --argjson hs "`echo ${hs[@]} | tr " " "\n" | jq -cs '.'`" \
            --argjson temp "`echo ${temp[@]} | tr " " "\n" | jq -cs '.'`" \
            --argjson fan "`echo ${fan[@]} | tr " " "\n" | jq -cs '.'`" \
            --arg uptime "$uptime" \
            --arg ver "$ver" \
            --arg ac "$ac" --arg rj "$rj" \
            --arg algo "$algo" \
            --argjson bus_numbers "`echo ${bus_numbers[@]} | tr " " "\n" | jq -cs '.'`" \
            '{$hs, $hs_units, $temp, $fan, $uptime, $ver, ar: [$ac, $rj], $algo, $bus_numbers}')

else
  stats=""
  khs=0
fi

 echo khs:   $khs
 echo stats: $stats
 echo ----------
