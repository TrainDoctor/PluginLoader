#!/bin/sh

[ "$UID" -eq 0 ] || exec sudo "$0" "$@"

# echo "Installing Steam Deck Plugin Loader pre-release..."

USER_DIR="$(getent passwd $SUDO_USER | cut -d: -f6)"
HOMEBREW_FOLDER="${USER_DIR}/homebrew"

# Create folder structure
rm -rf ${HOMEBREW_FOLDER}/services
sudo -u $SUDO_USER mkdir -p "${HOMEBREW_FOLDER}/services"
sudo -u $SUDO_USER mkdir -p "${HOMEBREW_FOLDER}/plugins"

# Download latest release and install it
RELEASE=$(curl -s 'https://api.github.com/repos/SteamDeckHomebrew/decky-loader/releases' | jq -r "first(.[] | select(.prerelease == "false"))")
if [[ "$RELEASE" == "" ]]; then 
    echo "ERROR, RELEASE NOT FOUND" && exit -1 
fi

read VERSION DOWNLOADURL < <(echo $(jq -r '.tag_name, .assets[].browser_download_url' <<< ${RELEASE}))

printf "URL= $DOWNLOADURL\n"

printf "Installing version %s...\n" "${VERSION}"
curl -L $DOWNLOADURL --output ${HOMEBREW_FOLDER}/services/PluginLoader
chmod +x ${HOMEBREW_FOLDER}/services/PluginLoader
echo $VERSION > ${HOMEBREW_FOLDER}/services/.loader.version

# stop and disable old user service (super legacy)
systemctl --user stop plugin_loader 2> /dev/null
systemctl --user disable plugin_loader 2> /dev/null

# stop, disable and remove previous service
systemctl stop plugin_loader 2> /dev/null
systemctl disable plugin_loader 2> /dev/null
rm -f /etc/systemd/system/plugin_loader.service
rm -f /etc/systemd/system/plugin_loader_uninstaller.service

# add systemd service for decky-loader
cat > /etc/systemd/system/plugin_loader.service <<- EOM
[Unit]
Description="Decky Loader Service"
[Service]
Type=simple
User=root
Restart=always
ExecStart=${HOMEBREW_FOLDER}/services/PluginLoader
WorkingDirectory=${HOMEBREW_FOLDER}/services
Environment=PLUGIN_PATH=${HOMEBREW_FOLDER}/plugins
Environment=LOG_LEVEL=DEBUG
[Install]
WantedBy=multi-user.target
EOM

# add systemd oneshot service for uninstalling decky-loader
cat > /etc/systemd/system/plugin_loader_uninstall.service <<- EOM
[Unit]
Description="Decky Loader Uninstaller"
[Service]
Type=oneshot
User=root
ExecStart=${HOMEBREW_FOLDER}/.uninstall.sh
WorkingDirectory=${HOMEBREW_FOLDER}
[Install]
WantedBy=multi-user.target
EOM

rm -f /etc/systemd/system/plugin_loader_uninstaller.service

# add uninstaller script
cat > ${HOMEBREW_FOLDER}/.uninstall.sh <<- EOM
[ "$UID" -eq 0 ] || exec sudo "$0" "$@"

# echo "Uninstalling decky-loader"

USER_DIR="$(getent passwd $SUDO_USER | cut -d: -f6)"
HOMEBREW_FOLDER="${USER_DIR}/homebrew"
EOM

systemctl daemon-reload
systemctl enable plugin_loader
systemctl start plugin_loader
