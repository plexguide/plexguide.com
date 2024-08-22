#!/bin/bash

##### Media Path: /pg/media
##### Port Number: 32400
##### Time Zone: America/New_York
##### AppData Path: /pg/appdata/plex

#### Token
token_command() {
    echo "This is the Token command execution."
    read -p "Press Enter to continue..."
}

#### Example
example_command() {
    echo "This is the Example command execution."
    read -p "Press Enter to continue..."
}

# Specify the app name and config file path
app_name=$1
config_path="/pg/config/${app_name}.cfg"

# Source the configuration file to get the appdata_path and app_name
if [[ -f "$config_path" ]]; then
    source "$config_path"
else
    echo "Error: Configuration file not found at $config_path."
    exit 1
fi

# Run the Plex Docker container with the specified settings
docker run -d \
  --name="${app_name}" \
  --network=host \
  -e PLEX_CLAIM="$CLAIM_KEY" \
  -e TZ="${time_zone}" \
  -v "${appdata_path}":/config \
  -v "${media_path}":/media \
  -v /etc/localtime:/etc/localtime:ro \
  -v realdebrid:/torrents \
  --restart unless-stopped \
  plexinc/pms-docker:plexpass

# Verify the Docker container is running
docker ps | grep "$app_name"
