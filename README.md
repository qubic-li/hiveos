# qubic.li - HiveOs Miner
This is the integration of the main client from qubic.li into HiveOS.

![Qubminer](/img/Header.png)

- [Qubic HiveOs Miner](#qubicli---hiveos-miner)
  - [Qubic Resources](#-qubic-resources)
  - [HiveOs Mandatory Installation Instructions](#warning-hiveos-mandatory-installation-instructions)
  - [✈️ Flight Sheet Configuration:](#️-flight-sheet-configuration)
    - [GPU+CPU (Dual) mining](#-gpucpu-dual-mining)
    - [GPU mining](#-gpu-mining)
    - [CPU mining](#-cpu-mining)
- 🔧 [Hive Os Settings](#-hive-os-settings)
    - [Miner Configuration](#miner-configuration)
    - [Recommended GPU Overclocks](#recommended-gpu-overclocks)
    - [Extra Config Arguments Box (Options)](#️-extra-config-arguments-box-options)
    - [Advanced Settings](#-advanced-settings)



## 📚 Qubic Resources

- [Official Qubic.li Client](https://github.com/qubic-li/client?tab=readme-ov-file#download)
- [Qubic Website](https://web.qubic.li/)
- [Qubic Web Wallet](https://wallet.qubic.org/)
- [Qubic Mining Pool](https://app.qubic.li/public/)

## :warning: HiveOs Mandatory Installation Instructions
- The CPU running the Client must support **AVX2** or **AVX512** instructions.
```sh
cat /proc/cpuinfo | grep avx2
```
(If `avx2` appears in the results, use the AVX2 configuration.)
- **16GB** or more RAM is recommended to enhance CPU performance.
- **Higher RAM frequencies** contribute to better CPU performance.
- **Avoid overloading** your CPU with threads; instead, aim to find the optimal balance.

- To run the Qubic miner, you need the latest stable version of HiveOS.
```sh
hive-replace --stable --yes
```

<br/>

### **⚙️ NVIDIA GPU Requirements:**
> [!NOTE]
> To update your NVIDIA GPU driver on HiveOS, please run the following command:
```sh
nvidia-driver-update
```
- **NVIDIA 3000 Series:** Driver version **535+** or newer.
- **NVIDIA 4000 Series:** Driver version **550+**.

<!--

### **⚙️ AMD GPU Requirements:**
> [!NOTE]
> AMD support may not be available all the time; availability depends on the epoch.

- Install version 5.7.3 driver using the command:
```sh
amd-ocl-install 5.7 5.7
```
- Install the libamdhip64 library. 
Run the following commands:
```sh
cd /opt/rocm/lib && wget https://github.com/Gddrig/Qubic_Hiveos/releases/download/0.4.1/libamdhip64.so.zip && unzip libamdhip64.so.zip && chmod +rwx /opt/rocm/lib/* && rm libamdhip64.so.zip && cd / && ldconfig
```

-->
<br>

## ✈️ Flight Sheet Configuration

- **Miner name:** Automatically filled with the installation URL.
- **Installation URL:** `https://github.com/qubic-li/hiveos/releases/download/latest/qubminer-latest.tar.gz`
- **Hash algorithm:** Not used, leave as `----`.
- **Wallet and worker template:** Enter your `worker name`. 
- **Pool URL:** Use `https://mine.qubic.li/` for the pool `app.qubic.li`.
- **Pass:** Not used.
  
> [!NOTE]
> Remove the `nvtool` line if you prefer to use the HiveOS dashboard for overclocking.

### 🔨 GPU+CPU (Dual) mining:
![Flight Sheet Dual](/img/FlightSheetDual.png)
<br>
**Extra Config Arguments Example for AVX512:**
```
nvtool --setcoreoffset 200 --setclocks 1600 --setmem 7000 --setmemoffset 2000
"trainer":{"cpu":true,"gpu":true}
"accessToken":"YOUROWNTOKEN"
AutoUpdate
```
**Extra Config Arguments Example for AVX2:**
```
nvtool --setcoreoffset 200 --setclocks 1600 --setmem 7000 --setmemoffset 2000
"trainer":{"cpu":true,"gpu":true,"cpuVersion":"AVX2"}
"amountOfThreads":24
AutoUpdate
```

<!--

**Sample Configuration for AMD GPU's**
```
"trainer": {"gpu":true,"gpuVersion": "AMD"}
"amountOfThreads":24
"accessToken":"YOUROWNTOKEN"
AutoUpdate
```
-->

### 🔨 GPU mining:
![Flight Sheet GPU](/img/FlightSheetGPU.png)
<br>
**Extra Config Arguments Example:**
```
nvtool --setcoreoffset 200 --setclocks 1600 --setmem 7000 --setmemoffset 2000
"trainer": {"gpu":true}
"accessToken":"YOUROWNTOKEN"
AutoUpdate
```
<!--


**Sample Configuration for AMD GPU's**
```
"trainer": {"gpu":true,"gpuVersion": "AMD"}
"accessToken":"YOUROWNTOKEN"
AutoUpdate
```

-->
### 🔨 CPU mining:
![Flight Sheet CPU](/img/FlightSheetCPU.png)
<br>
**Extra Config Arguments Example for AVX512:**
```
"cpuOnly":true
"trainer":{"cpu":true}
"accessToken":"YOUROWNTOKEN"
AutoUpdate
```
**Extra Config Arguments Example for AVX2:**
```
"cpuOnly":true
"trainer":{"cpu":true,"cpuVersion":"AVX2"}
"amountOfThreads":24
"accessToken":"YOUROWNTOKEN"
AutoUpdate
```

## 🔧 Hive Os Settings
> [!NOTE]
> The startup script pulls values from the flight sheet to configure the default settings (appsettings_global.json). Each time the miner starts, the appsettings.json file is recreated.

### Miner Configuration

- **Wallet and worker template:** Value of `"alias"` in `appsettings.json`.
- **Pool URL:** Value of `"baseUrl"` in `appsettings.json`.
- **Extra config arguments:** Each line is merged into `appsettings.json`.

### Recommended GPU Overclocks:  
**Medium:**  
3000 series ```nvtool --setcoreoffset 250 --setclocks 1500 --setmem 5001```  
4000 series ```nvtool --setcoreoffset 250 --setclocks 2400 --setmem 5001```  
**High:**  
3000 series ```nvtool --setcoreoffset 200 --setclocks 1600 --setmem 7000 --setmemoffset 2000```  
4000 series ```nvtool --setcoreoffset 200 --setclocks 2700 --setmem 7000 --setmemoffset 2000```  


### ⚙️ Extra Config Arguments Box (Options):

| Setting | Default Value |Description                                                                                                                                                                                                                                  |
| ---- |------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ```"accessToken":``` | JWT Token | This is your personal Token, which you can obtain from the Control Panel at qubic.li. |
| ```"payoutId":``` | `null` | This is the ID you want to get token payout for your found solutions. |
| ```pps:```  | `true` | Set this to `false` to disable `PPS` (Pay Per Share) mode. When enabled, you'll receive a fixed reward for each valid share you submit, regardless of whether a solution is found.|
| ```"useLiveConnection":```  | `true` or `talse` | Set this to `true` to enhance backend performance, enabling instant ID switching and idling. Note: This requires a constant internet connection.
| ```"hugePages":nnnn``` |  | Consider enabling huge pages to potentially increase iterations per second. The trainer will suggest the optimal setting based on threads * 138 (e.g., 16 threads = 2208). If the trainer becomes unstable, disable huge pages. |
|  ```"trainer":{"cpuThreads":32}``` | `All available -1` | How many threads should be used for the AI Training.	|
| ```"trainer":{"cpuVersion":"AVX512"}```  | | Set this to AVX512 to enforce the use of AVX512 instructions. |
| ```"trainer":{"cpuVersion":"AVX2"}```  | | Use this setting to force the AVX2 runner on CPUs that do not support AVX512. |
| ```"trainer":{"cpuVersion":"GENERIC"}```  | | If neither AVX2 or AVX512 CPU instructions are supported, use the GENERIC runner. |
| ```"idleSettings"```  | | Set the command to target the program you want to run, and set the argument for the specific action the program needs to perform.|
| ```AutoUpdate```  | | Enable automatic version check and installation for the miner after startup.|
<br>

## 🧪 Advanced Settings:
### Idle Time Feature
> [!NOTE]
> Starting September 4th, Qubic will introduce idle time every 677 ticks after 676 ticks of mining. During this idle period, you can configure your miner to run any application. The client will handle opening and closing the app. Below is a simple example for any program and miner.

**Extra Config Arguments Example for CPU:**
```json
"idleSettings":{"command":"ping","arguments":"google.com"}
```
**Extra Config Arguments Example for GPU:**
```json
"idleSettings":{"gpuOnly":true,"command":"ping","arguments":"google.com"}
```



