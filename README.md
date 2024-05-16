# Qubic HiveOs Miner
This is the integration of the main client from qubic.li to HiveOs.

![Qubminer](/img/Header.png)

Use URL in HiveOs flight sheet:
<br>
https://github.com/qubic-li/hiveos/releases/download/v1.9.7/qubminer-1.9.7.tar.gz

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
- The CPU where you run the Client must support AVX2 or AVX512 CPU instructions.
```sh
cat /proc/cpuinfo | grep avx2
```
(check if `avx2` is in the result)
- RAM should be >= 16GB to improve CPU performance.
- Higher RAM frequencies improve CPU performance.
- Do not overload your CPUs with threads; instead, aim to find the sweet spot.

- To run the Qubic miner, you need the beta version of HiveOS. Run:
```sh
/hive/sbin/hive-replace --beta --yes
```
- You need GLIBC version 2.34 or higher. During the installation process, select "Yes" and press Enter.
Run the following commands:
```sh
apt update && echo "deb http://cz.archive.ubuntu.com/ubuntu jammy main" >> /etc/apt/sources.list && apt update && apt install unzip g++ gcc g++-11 -y && apt install libc6 -y && sed -i '/deb http:\/\/cz\.archive\.ubuntu\.com\/ubuntu jammy main/d' /etc/apt/sources.list && apt update
```

**For NVIDIA cards:**
- Cuda 12+ drivers (525+) 
- Cuda 12 for 1000 series must be 535+ (or newer)
```sh
nvidia-driver-update 535.146.02
```
- For 4000 series use version 550+
```sh
nvidia-driver-update 550.54.14
```

**For AMD cards:**
- Install version 5.7.3 drivers using the command:
```sh
amd-ocl-install 5.7 5.7
```
- Install the libamdhip64 library. 
Run the following commands:
```sh
cd /opt/rocm/lib && wget https://github.com/Gddrig/Qubic_Hiveos/releases/download/0.4.1/libamdhip64.so.zip && unzip libamdhip64.so.zip && chmod +rwx /opt/rocm/lib/* && rm libamdhip64.so.zip && cd / && ldconfig
```
- Reboot your RIG
- If you encounter the error: `Looks like the trainer isn't working properly: ( check your config and he requirements.`
you need to change your subscription plan to "Fixed Reward 85%"

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
- **Installation URL:** `https://github.com/qubic-li/hiveos/releases/download/v1.9.7/qubminer-1.9.7.tar.gz`
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
