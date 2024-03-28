# stop services
echo "Stopping sonarr..."
sudo systemctl stop sonarr.service
if [[ $(systemctl status sonarr.service) == *"Active: inactive (dead)"* ]]; then
    echo " > Sonarr stopped successfully"
else
    echo " > Sonarr failed to stop"
fi

echo "Stopping bazarr..."
sudo systemctl stop bazarr.service
if [[ $(systemctl status bazarr.service) == *"Active: inactive (dead)"* ]]; then
    echo " > Bazarr stopped successfully"
else
    echo " > Bazarr failed to stop"
fi

echo "Stopping podman-jackett..."
sudo systemctl stop podman-jackett.service
if [[ $(systemctl status podman-jackett.service) == *"Active: inactive (dead)"* ]]; then
    echo " > Podman-jackett stopped successfully"
else
    echo " > Podman-jackett failed to stop"
fi

echo "Stopping podman-flaresolverr..."
sudo systemctl stop podman-flaresolverr.service
if [[ $(systemctl status podman-flaresolverr.service) == *"Active: inactive (dead)"* ]]; then
    echo " > Podman-flaresolverr stopped successfully"
else
    echo " > Podman-flaresolverr failed to stop"
fi

echo "Stopping onedrive..."
sudo systemctl stop onedrive.service
if [[ $(systemctl status onedrive.service) == *"Active: inactive (dead)"* ]]; then
    echo " > Onedrive stopped successfully"
else
    echo " > Onedrive failed to stop"
fi