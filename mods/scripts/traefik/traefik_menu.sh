#!/bin/bash

# ANSI color codes for styling output
CYAN="\033[0;36m"
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
BOLD="\033[1m"
NC="\033[0m"  # No color

# Configuration file path for storing DNS provider and domain details
CONFIG_FILE="/pg/config/dns_provider.cfg"

# Function to check if Traefik is deployed
check_traefik_status() {
    if docker ps --filter "name=traefik" --format '{{.Names}}' | grep -q 'traefik'; then
        traefik_status="${GREEN}${BOLD}[Deployed]${NC}"
    else
        traefik_status="${RED}${BOLD}[Not Deployed]${NC}"
    fi
}

# Function to check if the Let's Encrypt email is set
check_email_status() {
    if grep -q "^letsencrypt_email=" "$CONFIG_FILE"; then
        letsencrypt_email=$(grep "^letsencrypt_email=" "$CONFIG_FILE" | cut -d'=' -f2)
        if [[ -z "$letsencrypt_email" || "$letsencrypt_email" == "notset" ]]; then
            email_status="${RED}${BOLD}Not Set${NC}"
        else
            email_status="${GREEN}${BOLD}Set${NC}"
        fi
    else
        email_status="${RED}${BOLD}Not Set${NC}"
    fi
}

# Function to test Cloudflare credentials
test_cloudflare_credentials() {
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
      -H "Authorization: Bearer $api_key" \
      -H "Content-Type: application/json")

    if echo "$response" | grep -q "valid and active"; then
        return 0  # Valid credentials
    else
        return 1  # Invalid credentials
    fi
}

# Function to validate email format
validate_email() {
    local email="$1"
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0  # Email is valid
    else
        return 1  # Email is invalid
    fi
}

# Function to handle Traefik stop and removal warning with PINs
warn_traefik_removal() {
    echo ""
    echo -e "${RED}Warning: Changing the Cloudflare credentials will stop and remove Traefik.${NC}"
    echo ""

    # Generate two random 4-digit PINs
    proceed_pin=$(shuf -i 1000-9999 -n 1)
    cancel_pin=$(shuf -i 1000-9999 -n 1)

    # Display the PINs to the user
    echo -e "If you want to proceed and remove Traefik, enter: ${RED}${proceed_pin}${NC}"
    echo -e "If you do NOT want to proceed, enter: ${GREEN}${cancel_pin}${NC}"
    echo ""

    # Read user input for PIN
    read -p "Enter your choice (PIN): " user_pin

    # Check user's choice
    if [[ "$user_pin" == "$proceed_pin" ]]; then
        echo -e "${RED}Stopping and removing Traefik...${NC}"
        docker stop traefik >/dev/null 2>&1
        docker rm traefik >/dev/null 2>&1
        return 0  # Proceed with changing credentials
    elif [[ "$user_pin" == "$cancel_pin" ]]; then
        echo -e "${GREEN}Operation canceled. Traefik will not be stopped or removed.${NC}"
        return 1  # Do not proceed
    else
        echo -e "${RED}Invalid PIN entered. Operation aborted.${NC}"
        return 1  # Invalid entry, cancel operation
    fi
}

# Function to setup DNS provider
setup_dns_provider() {
    while true; do
        clear
        check_traefik_status
        check_email_status
        
        echo -e "${CYAN}${BOLD}PG: CloudFlare Traefik Interface ${traefik_status}${NC}"
        echo ""
        echo -e "[${CYAN}${BOLD}C${NC}] CF Information"
        echo -e "[${MAGENTA}${BOLD}E${NC}] Notification E-Mail Address (${email_status})"
        
        # Show the Deploy Traefik option only if email is set
        if [[ "$email_status" == "${GREEN}${BOLD}Set${NC}" ]]; then
            echo -e "[${BLUE}${BOLD}D${NC}] Deploy Traefik"
        fi
        
        echo -e "[${RED}${BOLD}Z${NC}] Exit"
        echo ""
        
        read -p "Select an Option > " choice
        case $choice in
            [Cc])
                if docker ps --filter "name=traefik" --format '{{.Names}}' | grep -q 'traefik'; then
                    warn_traefik_removal
                    if [[ $? -eq 1 ]]; then
                        continue  # Skip changing credentials if the user canceled
                    fi
                fi
                configure_provider
                ;;
            [Ee])
                set_email
                ;;
            [Dd])
                if [[ "$email_status" == "${GREEN}${BOLD}Set${NC}" ]]; then
                    bash /pg/scripts/traefik/traefik_deploy.sh
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

# Function to configure DNS provider (Cloudflare only)
configure_provider() {
    echo ""
    echo -e "${CYAN}Configuring Cloudflare DNS Provider${NC}"
    provider="cloudflare"
    
    # Prompt for Cloudflare email and API key
    read -p "Enter your Cloudflare email: " cf_email
    read -p "Enter your Cloudflare API key: " api_key

    # Trim any leading/trailing whitespace from the API key
    api_key=$(echo "$api_key" | xargs)

    # Test the credentials before saving
    echo -e "${YELLOW}Testing Cloudflare credentials...${NC}"
    if test_cloudflare_credentials; then
        read -p "Enter the domain name to use (e.g., example.com): " domain_name
        echo "provider=cloudflare" > "$CONFIG_FILE"
        echo "email=$cf_email" >> "$CONFIG_FILE"
        echo "api_key=$api_key" >> "$CONFIG_FILE"
        echo "domain_name=$domain_name" >> "$CONFIG_FILE"
        echo ""
        echo -e "${GREEN}Cloudflare DNS provider and domain have been configured successfully.${NC}"
    else
        # Blank out all information in the config file if credentials are invalid
        echo "" > "$CONFIG_FILE"
        echo ""
        echo -e "${RED}CloudFlare Information is Incorrect and/or the API Key may not have the proper permissions.${NC}"
        echo ""
    fi

    read -p "Press [ENTER] to continue..."
}

# Function to set email for Let's Encrypt
set_email() {
    while true; do
        read -p "Enter your email for Let's Encrypt notifications: " letsencrypt_email

        # Validate email format
        if validate_email "$letsencrypt_email"; then
            echo "letsencrypt_email=$letsencrypt_email" >> "$CONFIG_FILE"
            echo -e "${GREEN}Email has been configured successfully.${NC}"
            read -p "Press Enter to continue..."
            break
        else
            echo -e "${RED}Invalid email format. Please enter a valid email (e.g., user@example.com).${NC}"
        fi
    done
}

# Execute the setup function
setup_dns_provider
