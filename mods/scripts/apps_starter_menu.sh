#!/bin/bash

# ANSI color codes for green, red, blue, and orange
GREEN="\033[0;32m"
RED="\033[0;31m"
BLUE="\033[0;34m"
ORANGE="\033[0;33m"
NC="\033[0m" # No color

# Function to count running Docker containers, excluding cf_tunnel
count_docker_apps() {
    docker ps --format '{{.Names}}' | grep -v 'cf_tunnel' | wc -l
}

# Load the App Store version from the config file
load_app_store_version() {
    if [ -f /pg/config/appstore_version.cfg ]; then
        source /pg/config/appstore_version.cfg
    else
        appstore_version="Alpha"
    fi
}

# Function to display the App Store version with appropriate color
display_app_store_version() {
    if [ "$appstore_version" == "Alpha" ]; then
        echo -e "A) App Store Version: [${RED}$appstore_version${NC}]"
    else
        echo -e "A) App Store Version: [${GREEN}$appstore_version${NC}]"
    fi
}

# Main menu function
main_menu() {
  while true; do
    clear

    # Get the number of running Docker apps, excluding cf_tunnel
    APP_COUNT=$(count_docker_apps)

    # Load the App Store version
    load_app_store_version

    echo -e "${BLUE}PG: Docker Apps${NC}"
    echo ""  # Blank line for separation
    # Display the main menu options
    echo -e "V) Apps [${ORANGE}View${NC}] [ $APP_COUNT ]"
    echo -e "D) Apps [${GREEN}Deploy${NC}]"
    display_app_store_version  # Display App Store Version with appropriate color
    echo "Z) Exit"
    echo ""  # Space between options and input prompt

    # Prompt the user for input
    read -p "Enter your choice: " choice

    case $choice in
      V|v)
        bash /pg/scripts/running.sh
        ;;
      D|d)
        bash /pg/scripts/deployment.sh
        ;;
      A|a)
        bash /pg/scripts/apps_version.sh
        ;;
      Z|z)
        exit 0
        ;;
      *)
        echo ""
        ;;
    esac
  done
}

# Call the main menu function
main_menu