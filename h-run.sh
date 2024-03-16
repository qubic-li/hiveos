[[ ! -e ./appsettings.json ]] && echo "No config file found, exiting" && exit 1

./qli-Client | tee --append $MINER_LOG_BASENAME.log

