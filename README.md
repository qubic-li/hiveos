# Qubic HiveOs Miner (WIP)

Detailed Instructions on how to use Qubic Client for HiveOs is work in progress.

## :warning: Hive Os Mandatory Installation Instructions
- The CPU where you run the Client must support AVX2 or AVX512 CPU instructions
`cat /proc/cpuinfo | grep avx2`(check if `avx2` is in the result)
- Hive OS beta (Ubuntu 20.04) 
`/hive/sbin/hive-replace --list`  (choice 2/ yes to apply -- better to start this fresh install if you'r stuck)
- GLIBC >=2.34
```apt update && apt upgrade -y && echo "deb http://archive.ubuntu.com/ubuntu jammy main" >> /etc/apt/sources.list && apt update && apt install tmux -y && apt install libc6 -y``` (answer yes to any question)
- Cuda 12+ drivers (525+) 
- Cuda 12 for 1000 series must be 535+
`nvidia-driver-update 535.146.02` (or newer)
- RAM >= 16Go improves CPU it/s
- Higher RAM frequencies improves CPU it/s
- Do not overload your CPUs with threads, instead, aim to find the sweetpoint

*Only NVIDIA GPU compatible*
<br>

## :wrench: Hive Os Settings

- Recommended GPU overclocks :  
**Medium**  
3000 series ```nvtool --setcoreoffset 250 --setclocks 1500 --setmem 5001```  
4000 series ```nvtool --setcoreoffset 250 --setclocks 2400 --setmem 5001```  
**High**  
3000 series ```nvtool --setcoreoffset 200 --setclocks 1600 --setmem 7000 --setmemoffset 2000```  
4000 series ```nvtool --setcoreoffset 200 --setclocks 2900 --setmem 7000 --setmemoffset 2000```  
<br>
