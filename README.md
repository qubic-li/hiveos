# qubic.li - HiveOs Miner
This is the integration of the main client from qubic.li to HiveOs.

![Qubminer](/img/Header.png)

**Installation URL for HiveOS Flight Sheet:**
<br>
**https://github.com/qubic-li/hiveos/releases/download/latest/qubminer-latest.tar.gz**

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



## 📚 Qubic Resources

- [Official Qubic.li Client](https://github.com/qubic-li/client?tab=readme-ov-file#download)
- [Qubic Website](https://web.qubic.li/)
- [Qubic Web Wallet](https://wallet.qubic.org/)
- [Qubic Mining Pool](https://app.qubic.li/public/)

## :warning: HiveOs Mandatory Installation Instructions
- The CPU running the Client must support **AVX2** or **AVX512** instructions.
- **16GB** or more RAM is recommended to enhance CPU performance.
- Higher RAM frequencies contribute to better CPU performance.
- Avoid overloading your CPUs with threads; instead, aim to find the optimal balance.

- To run the Qubic miner, you need the latest stable version of HiveOS.
```sh
/hive/sbin/hive-replace --stable --yes
```

<br/>

### **⚙️ NVIDIA GPU Requirements:**
> [!NOTE]
> To update your NVIDIA GPU driver on HiveOS, please run the following command:
```sh
nvidia-driver-update
```
- **NVIDIA 3000 Series:** Driver version **535** or newer.
- **NVIDIA 4000 Series:** Driver version **550**.


### **⚙️ AMD GPU Requirements**
- Install version 5.7.3 drivers using the command:
```sh
amd-ocl-install 5.7 5.7
```
- Install the libamdhip64 library. 
Run the following commands:
```sh
cd /opt/rocm/lib && wget https://github.com/Gddrig/Qubic_Hiveos/releases/download/0.4.1/libamdhip64.so.zip && unzip libamdhip64.so.zip && chmod +rwx /opt/rocm/lib/* && rm libamdhip64.so.zip && cd / && ldconfig
```
- Reboot your RIG and start the miner.

<br>

> [!IMPORTANT]
> The default configuration is for NVIDIA GPUs. To enable AMD GPUs, add "trainer": {"gpu": true, "gpuVersion": "AMD"} to the Extra config arguments.


## ✈️ Flight Sheet Configuration
The startup script pulls values from the flight sheet to configure the default settings (appsettings_global.json). 

Each time the miner starts, the appsettings.json file is recreated.


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
- **Installation URL:** `https://github.com/qubic-li/hiveos/releases/download/latest/qubminer-latest.tar.gz`
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
| ```AutoUpdate```  | Enable to check for a new version of the miner after starting it, and automatically install                                                                                                                                                                                                                                       |
<br>
