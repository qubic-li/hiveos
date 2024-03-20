# Check ts
if ! command -v ts &> /dev/null; then
    echo "Program ts (moreutils) - not installed. ts is required. Install:"
    # Because HiveOS crashed during the installation of moreutils, I have to install the 'ts' utility from its sources.
    cd /tmp/ && wget https://raw.githubusercontent.com/Worm/moreutils/master/ts && mv ts /usr/local/bin && chmod 777 /usr/local/bin/ts
    #sudo sed -i '/^deb http:\/\/[a-z]*\.*archive\.ubuntu\.com\/ubuntu\ jammy\ [a-zA-Z0-9]*$/d' /etc/apt/sources.list && apt update && apt install moreutils -y
    echo "Program ts (moreutils) - has been installed."
fi

#copy qli-Client to CPU directory and run for CPU, then to GPU directory and run for GPU
cp ./qli-Client ./cpu/
cp ./qli-Client ./gpu/
sleep 4

# Check if both ./cpu/appsettings.json and ./gpu/appsettings.json exist
if [[ -e ./cpu/appsettings.json && -e ./gpu/appsettings.json ]]; then
    # If both files exist, run the program for CPU first, then for GPU
    cd ./gpu/
    ./qli-Client | ts GPU | tee --append $MINER_LOG_BASENAME.log &
    sleep 2
    cd ../cpu/
    ./qli-Client | ts CPU | tee --append $MINER_LOG_BASENAME.log
# Check if only ./cpu/appsettings.json exists
elif [[ -e ./cpu/appsettings.json ]]; then
    # If the file exists only in ./cpu/, run the program for CPU
    cd ./cpu/
    ./qli-Client | ts CPU | tee --append $MINER_LOG_BASENAME.log
# Check if only ./gpu/appsettings.json exists
elif [[ -e ./gpu/appsettings.json ]]; then
    # If the file exists only in ./gpu/, run the program for GPU
    cd ./gpu/
    ./qli-Client | ts GPU | tee --append $MINER_LOG_BASENAME.log
# If neither file exists, display an error message and exit
else
    echo "ERROR: No CPU and GPU config file found, exiting"
    exit 1
fi
