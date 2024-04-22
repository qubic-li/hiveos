# Qubic HiveOs Miner
This is the integration of the main client from qubic.li to HiveOs.

![Qubminer](/img/Header.png)

Use URL in HiveOs flight sheet:
<br>
https://github.com/qubic-li/hiveos/releases/download/v1.9.5/qubminer-1.9.5.tar.gz

- [Qubic HiveOs Miner](#qubic-hiveos-miner)
  - [Qubic Resources](#qubic-resources)
  - [:warning: HiveOs Mandatory Installation Instructions](#warning-hiveos-mandatory-installation-instructions)
  - [Flight Sheet Configuration](#flight-sheet-configuration)
    - [GPU+CPU (Dual) mining:](#gpucpu-dual-mining)
    - [GPU mining:](#gpu-mining)
    - [CPU mining:](#cpu-mining)
  - [:wrench: Hive Os Settings](#wrench-hive-os-settings)
    - [Miner Configuration](#miner-configuration)
    - [Recommended GPU overclocks :](#recommended-gpu-overclocks-)
    - [Extra config arguments Box (options):](#extra-config-arguments-box-options)



## Qubic Resources

- [Qubic Website](https://web.qubic.li/)
- [Qubic Web Wallet](https://wallet.qubic.li/)
- [Qubic Mining Pool](https://app.qubic.li/public/)
- [Official Qubic Client](https://github.com/qubic-li/client?tab=readme-ov-file#download)

## :warning: HiveOs Mandatory Installation Instructions
- The CPU where you run the Client must support AVX2 or AVX512 CPU instructions
`cat /proc/cpuinfo | grep avx2`(check if `avx2` is in the result)
- To run the Qubic miner, you need the beta version of HiveOS.
`/hive/sbin/hive-replace --beta --yes`
- Cuda 12+ drivers (525+) 
- Cuda 12 for 1000 series must be 535+
`nvidia-driver-update 535.146.02` (or newer)
- RAM >= 16Go improves CPU it/s
- Higher RAM frequencies improves CPU it/s
- Do not overload your CPUs with threads, instead, aim to find the sweetpoint

<br>

> [!NOTE]
> The defualt configuration is vor NVIDIA. To enable AMD GPU you need to add `"trainer": {"gpu":true,"gpuVersion": "AMD"}` to Extra config arguments. 


> [!IMPORTANT]
> AMD Version was tested with hiveos version `6.1.0-hiveos` and AMD drivers `5.7.3`. Please take this as minimum requirenments.
> AMD Version is currently only allowed in `qubic.li CPU/GPU Mining (Fixed Reward 85%)`



## Flight Sheet Configuration
The startup script takes values from the flight sheet to complete the default configuration (`appsettings_global.json`).

Each time the miner starts, the `appsettings.json` file is recreated


> [!IMPORTANT]
> For CPU you have to define which Version should be used. The `cpuVersion` propery can be used. Please refer to https://github.com/qubic-li/client/?tab=readme-ov-file#qli-trainer-options for a list of available versions. You can also find there all other available options.

### GPU+CPU (Dual) mining:
![Flight Sheet Dual](/img/FlightSheetDual.png)
<br>
Extra config arguments exemple:
```
nvtool --setcoreoffset 200 --setclocks 1600 --setmem 7000 --setmemoffset 2000
"accessToken":"YOUROWNTOKEN"
"amountOfThreads":4
"trainer": {"cpuVersion": "GENERIC"}
```

**Sample Configuration for AMD GPU's**
```
"amountOfThreads":4
"trainer": {"gpu":true,"gpuVersion": "AMD", "cpuVersion": "GENERIC"}
"accessToken":"YOUROWNTOKEN"
```

### GPU mining:
![Flight Sheet GPU](/img/FlightSheetGPU.png)
<br>
Extra config arguments exemple:
```
nvtool --setcoreoffset 200 --setclocks 1600 --setmem 7000 --setmemoffset 2000
"accessToken":"YOUROWNTOKEN"
```

**Sample Configuration for AMD GPU's**
```
"trainer": {"gpu":true,"gpuVersion": "AMD"}
"accessToken":"YOUROWNTOKEN"
```

### CPU mining:
![Flight Sheet CPU](/img/FlightSheetCPU.png)
<br>
Extra config arguments exemple:
```
"cpuOnly":"yes"
"amountOfThreads":24
"accessToken":"YOUROWNTOKEN"
"trainer": {"cpu":true,"cpuVersion": "GENERIC"}
```

## :wrench: Hive Os Settings

### Miner Configuration

- **Miner name:** Automatically filled with the installation URL.
- **Installation URL:** `https://github.com/qubic-li/hiveos/releases/download/v1.9.5/qubminer-1.9.5.tar.gz`
- **Hash algorithm:** Not used, leave as `----`.
- **Wallet and worker template:** Worker name. Value of `"alias"` in `appsettings.json`.
- **Pool URL:** Value of `"baseUrl"` in `appsettings.json`. Use `https://mine.qubic.li/` for the pool `app.qubic.li`.
- **Pass:** Not used.
- **Extra config arguments:** Each line is merged into `appsettings.json`.

### Recommended GPU overclocks :  
**Medium**  
3000 series ```nvtool --setcoreoffset 250 --setclocks 1500 --setmem 5001```  
4000 series ```nvtool --setcoreoffset 250 --setclocks 2400 --setmem 5001```  
**High**  
3000 series ```nvtool --setcoreoffset 200 --setclocks 1600 --setmem 7000 --setmemoffset 2000```  
4000 series ```nvtool --setcoreoffset 200 --setclocks 2900 --setmem 7000 --setmemoffset 2000```  


### Extra config arguments Box (options):

| Setting | Description                                                                                                                                                                                                                                  |
| ---- |----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ```"accessToken":``` | This is you personal JWT Token which you can obtain from the Control Panel at qubic.li                                                                                                                                                       |
| ```"payoutId":``` | This is the ID you want to get token payout for your found solutions.                                                                                                                                                                        |
| ```"hugePages":nnnn``` | Depending on your environment you might want to enable huge pages. This can increase your iterations per second. The trainer will tell you what is the optimal setting when it detects a wrong value. The number depends on the number of threads: nb_threads * 52 (e.g., 16 * 52 = 832). If trainer is unstable please remove. |
|  ```"overwrites": {"AVX512": false}``` | Disable AVX512 and enforce AVX2 (AVX Intel CPU not working)                                                                                                                                                                                  |
| ```"overwrites": {"SKYLAKE": true}```  | Enforce SKYLAKE (AVX Intel CPU not working)                                                                                                                                                                                                  |
| ```"trainer": {"gpu": true, "gpVersion": "AMD"}```  | Enforce AMD                                                                                                                                                                                                  |
<br>
