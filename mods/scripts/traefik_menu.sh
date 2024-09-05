#!/bin/bash

# ANSI color codes for styling output
CYAN="\033[0;36m"
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
NC="\033[0m"  # No color

# Configuration file path for storing DNS provider and domain details
CONFIG_FILE="/pg/config/dns_provider.cfg"

# Function to check if Traefik is deployed
check_traefik_status() {
    if docker ps --filter "name=traefik" --format '{{.Names}}' | grep -q 'traefik'; then
        traefik_status="${GREEN}[Deployed]${NC}"
    else
        traefik_status="${RED}[Not Deployed]${NC}"
    fi
}

# Function to load the DNS provider configuration
load_dns_provider() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        provider_display="${provider:-${RED}[Not-Set]${NC}}"
    else
        provider_display="${RED}[Not-Set]${NC}"
    fi
}


# Function to setup DNS provider
setup_dns_provider() {
    while true; do
        clear
        check_traefik_status
        load_dns_provider
        
        echo -e "${CYAN}PG: Traefik Interface ${traefik_status}${NC}"
        echo ""
        echo -e "[${CYAN}${BOLD}C${NC}] DNS Provider: ${provider_display}"
        echo -e "[${MAGENTA}${BOLD}E${NC}] E-Mail for LetsEncrypt"
        echo -e "[${BLUE}${BOLD}D${NC}] Deploy Traefik"
        echo -e "[${RED}${BOLD}Z${NC}] Exit"
        echo ""
        
        read -p "Enter your choice: " choice
        case $choice in
            [Cc])
                configure_provider
                ;;
            [Ee])
                set_email
                ;;
            [Dd])
                if [[ "$provider_display" == "${RED}[Not-Set]${NC}" ]]; then
                    echo -e "${RED}DNS Provider must be set before deploying Traefik.${NC}"
                    read -p "Press Enter to continue..."
                else
                    bash /pg/scripts/traefik_deploy.sh
                    echo ""
                    read -p "Press Enter to continue..."
                fi
                ;;
            [Zz])
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Function to configure DNS provider
configure_provider() {
    clear
    echo -e "${CYAN}Choose a DNS Provider:${NC}"
    echo -e "1) Cloudflare"
    echo -e "2) GoDaddy"
    read -p "Enter your choice (1 or 2): " provider_choice

    if [[ "$provider_choice" == "1" ]]; then
        provider="cloudflare"
        read -p "Enter your Cloudflare email: " cf_email
        read -p "Enter your Cloudflare API key: " cf_api_key
        echo "provider=cloudflare" > "$CONFIG_FILE"
        echo "email=$cf_email" >> "$CONFIG_FILE"
        echo "api_key=$cf_api_key" >> "$CONFIG_FILE"
    elif [[ "$provider_choice" == "2" ]]; then
        provider="godaddy"
        read -p "Enter your GoDaddy API key: " gd_api_key
        read -p "Enter your GoDaddy API secret: " gd_api_secret
        echo "provider=godaddy" > "$CONFIG_FILE"
        echo "api_key=$gd_api_key" >> "$CONFIG_FILE"
        echo "api_secret=$gd_api_secret" >> "$CONFIG_FILE"
    else
        echo -e "${RED}Invalid choice. Please try again.${NC}"
        configure_provider
        return
    fi

    read -p "Enter the domain name to use (e.g., example.com): " domain_name
    echo "domain_name=$domain_name" >> "$CONFIG_FILE"
    echo -e "${GREEN}DNS provider and domain have been configured successfully.${NC}"
    read -p "Press Enter to continue..."
}

# Function to set email for Let's Encrypt
set_email() {
    read -p "Enter your email for Let's Encrypt notifications: " letsencrypt_email
    echo "letsencrypt_email=$letsencrypt_email" >> "$CONFIG_FILE"
    echo -e "${GREEN}Email has been configured successfully.${NC}"
    read -p "Press Enter to continue..."
}

# Execute the setup function
setup_dns_provider