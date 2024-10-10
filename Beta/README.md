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
- **Pool URL:** Use `wss://wps.qubic.li/ws` for the pool `https://pool.qubic.li/`.
- **Pass:** Not used.

### 🔨 GPU+CPU (Dual) mining:
![Flight Sheet Dual](/img/FlightSheetDual.png)
<br>
**Extra Config Arguments Example for AVX512:**
```
"trainer":{"cpu":true,"gpu":true}
"accessToken":"YOUROWNTOKEN"
AutoUpdate
```
**Extra Config Arguments Example for AVX2:**
```
"trainer":{"cpu":true,"gpu":true,"cpuVersion":"AVX2"}
"accessToken":"YOUROWNTOKEN"
AutoUpdate
```

<!--

**Sample Configuration for AMD GPU's**
```
"trainer":{"gpu":true,"gpuVersion": "AMD"}
"accessToken":"YOUROWNTOKEN"
AutoUpdate
```
-->

### 🔨 GPU mining:
![Flight Sheet GPU](/img/FlightSheetGPU.png)
<br>
**Extra Config Arguments Example:**
```
"trainer":{"gpu":true}
"accessToken":"YOUROWNTOKEN"
AutoUpdate
```
<!--


**Sample Configuration for AMD GPU's**
```
"trainer":{"gpu":true,"gpuVersion": "AMD"}
"accessToken":"YOUROWNTOKEN"
AutoUpdate
```

-->
### 🔨 CPU mining:
![Flight Sheet CPU](/img/FlightSheetCPU.png)
<br>
**Extra Config Arguments Example for AVX512:**
```
"trainer":{"cpu":true}
"accessToken":"YOUROWNTOKEN"
AutoUpdate
```
**Extra Config Arguments Example for AVX2:**
```
"trainer":{"cpu":true,"cpuVersion":"AVX2"}
"accessToken":"YOUROWNTOKEN"
AutoUpdate
```

## 🔧 Hive Os Settings
> [!NOTE]
> The startup script pulls values from the flight sheet to configure the default settings (appsettings_global.json). Each time the miner starts, the appsettings.json file is recreated.

### Miner Configuration

- **Wallet and worker template:** Value of `"alias"` in `appsettings.json`.
- **Pool URL:** Value of `"poolAddress"` in `appsettings.json`.
- **Extra config arguments:** Each line is merged into `appsettings.json`.

### Recommended GPU Overclocks:  

3000 series ```nvtool --setcoreoffset 200 --setclocks 1600 --setmem 5001 --setmemoffset 2100```  
4000 series ```nvtool --setcoreoffset 200 --setclocks 2650 --setmem 7001 --setmemoffset 2300```  

### ⚙️ Extra Config Arguments Box (Options):

| Setting | Default Value |Description                                                                                                                                                                                                                                  |
| ---- |------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ```"accessToken":``` | JWT Token | This is your personal Token, which you can obtain from the Control Panel at qubic.li. |
| ```"qubicAddress":``` | `null` | This is the ID you want to get token payout for your found solutions. |
| ```pps:```  | `true` | Set this to `false` to disable `PPS` (Pay Per Share) mode. When enabled, you'll receive a fixed reward for each valid share you submit, regardless of whether a solution is found.|
|  ```"trainer":{"cpuThreads":32}``` | `All available -1` | How many threads should be used for the AI Training.	|
| ```"trainer":{"cpu":true,"cpuVersion":"AVX512"}```  | | Set this to AVX512 to enforce the use of AVX512 instructions. |
| ```"trainer":{"cpu":true,"cpuVersion":"AVX2"}```  | | Use this setting to force the AVX2 runner on CPUs that do not support AVX512. |
| ```"trainer":{"cpu":true,"cpuVersion":"GENERIC"}```  | | If neither AVX2 or AVX512 CPU instructions are supported, use the GENERIC runner. |
| ```"Idling"```  | | Set the command to target the program you want to run, and set the argument for the specific action the program needs to perform.|
| ```AutoUpdate```  | | Enable automatic version check and installation for the miner after startup.|
<br>

## 🧪 Advanced Settings:
### Idle Time Feature
> [!NOTE]
> During the Qubic idling phase, you can run another program or miner.

**Extra Config Arguments Example:**
```json
"idleSettings":{"preCommand":"ping","preCommandArguments":"-c 2 google.com","command":"ping","arguments":"google.com","postCommand":"ping","postCommandArguments":"-c 2 google.com"}
```
<br>

|  Setting 		|  Description 	|
|---	|---	|
|  command 	|  The command/program to execute.	|
|  arguments 	|  The arguments that should be passed to the command/program.	|
|  preCommand 	|  A command/program to start once the idling period begins.	|
|  preCommandArguments 	|  The arguments that should be passed to the preCommand/program.	|
|  postCommand 	|  A command/program to start once the idling period stops.	|
|  postCommandArguments 	|  The arguments that should be passed to the postCommand/program.	|
