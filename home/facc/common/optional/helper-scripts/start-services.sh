
# start services
echo "Starting sonarr..."
sudo systemctl start sonarr.service
if [[ $(systemctl status sonarr.service) == *"Active: active (running)"* ]]; then
    echo " > Sonarr started successfully"
else
    echo " > Sonarr failed to start"
fi

echo "Starting bazarr..."
sudo systemctl start bazarr.service
if [[ $(systemctl status bazarr.service) == *"Active: active (running)"* ]]; then
    echo " > Bazarr started successfully"
else
    echo " > Bazarr failed to start"
fi

echo "Starting podman-jackett..."
sudo systemctl start podman-jackett.service
if [[ $(systemctl status podman-jackett.service) == *"Active: active (running)"* ]]; then
    echo " > Podman-jackett started successfully"
else
    echo " > Podman-jackett failed to start"
fi

echo "Starting podman-flaresolverr..."
if [[ $(systemctl status podman-flaresolverr.service) == *"Active: active (running)"* ]]; then
    echo " > Podman-flaresolverr started successfully"
else
    echo " > Podman-flaresolverr failed to start"
fi

echo "Starting onedrive..."
sudo systemctl start onedrive.service
if [[ $(systemctl status onedrive.service) == *"Active: active (running)"* ]]; then
    echo " > Onedrive started successfully"
else
    echo " > Onedrive failed to start"
fi
