#!/bin/bash

# Colors
plain='\033[0m'
red='\e[31m'
yellow='\e[33m'
green='\e[92m'
blue='\e[94m'
cyan='\e[96m'

# Configuration
USER_DB="/root/usuarios.db"
BACKUP_DIR="/root/ssh_backups"
BANNER_FILE="/etc/ssh/gcp_404"

# Check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain} Run as root!${plain}" && exit 1

# Create SSH user
create_user() {
    local username="$1"
    local password="$2"
    local limit="$3"
    local days="$4"
    local message="$5"
    local token="$6"

    # Token validation (5 minute window)
    local current_time=$(date +%s)
    if [[ -z "$token" || $((current_time - token)) -gt 300 ]]; then
        echo -e "${red}Error: Invalid or expired token${plain}"
        exit 1
    fi

    # Password validation
    if [[ ${#password} -lt 3 ]]; then
        echo -e "${red}Error: Password too short (min 3 chars)${plain}"
        exit 1
    fi

    # Configure SSH
    sed -i 's/#\?AllowTcpForwarding .*/AllowTcpForwarding yes/' /etc/ssh/sshd_config
    sed -i 's/#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i "s|#\?Banner .*|Banner $BANNER_FILE|" /etc/ssh/sshd_config
    systemctl restart sshd

    # Set banner
    echo -e "$message" > "$BANNER_FILE"

    # Create user
    local expiry_date=$(date -d "+$days days" +%Y-%m-%d)
    local pass_hash=$(openssl passwd -1 "$password")
    useradd -e "$expiry_date" -m -s /bin/bash -p "$pass_hash" "$username"
    
    # Add to database
    echo "$username $limit" >> "$USER_DB"
    
    # Display info
    local ip=$(curl -s ifconfig.me)
    echo -e "${green}SSH Account Created:${plain}"
    echo -e "IP: $ip"
    echo -e "Username: $username"
    echo -e "Password: $password"
    echo -e "Expiry: $(date -d "$expiry_date" +%d/%m/%Y)"
    echo -e "Concurrent: $limit"
}

# Delete user
delete_user() {
    local username="$1"
    
    if grep -q "^$username " "$USER_DB"; then
        userdel -r "$username" 2>/dev/null
        sed -i "/^$username /d" "$USER_DB"
        echo -e "${green}Deleted user: $username${plain}"
    else
        echo -e "${red}User not found: $username${plain}"
    fi
}

# List users
list_users() {
    echo -e "${yellow}=== SSH Users ===${plain}"
    printf "%-15s %-15s %-10s %-15s\n" "Username" "Expiry" "Limit" "Status"
    echo "--------------------------------------------------"
    
    while read -r line; do
        local user=$(echo "$line" | awk '{print $1}')
        local limit=$(echo "$line" | awk '{print $2}')
        local expiry=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | sed 's/^ *//')
        
        if [[ "$expiry" == "never" ]]; then
            expiry="Never"
            status="${green}Active${plain}"
        elif [[ $(date -d "$expiry" +%s) -lt $(date +%s) ]]; then
            status="${red}Expired${plain}"
        else
            status="${green}Active${plain}"
        fi
        
        printf "%-15s %-15s %-10s %-15s\n" "$user" "$expiry" "$limit" "$status"
    done < "$USER_DB"
}

# Main execution
case "$1" in
    --create)
        create_user "$2" "$3" "$4" "$5" "$6" "$7"
        ;;
    --delete)
        delete_user "$2"
        ;;
    --list)
        list_users
        ;;
    *)
        echo "Usage: $0 [option]"
        echo "Options:"
        echo "  --create [user] [pass] [limit] [days] [message] [token]  Create SSH user"
        echo "  --delete [user]                                          Delete user"
        echo "  --list                                                   List all users"
        exit 1
        ;;
esac
