#!/bin/bash

# Colors
plain='\033[0m'
red='\e[31m'
yellow='\e[33m'
green='\e[92m'
blue='\e[94m'
cyan='\e[96m'
magenta='\e[95m'
dnstt_color='\e[35m'

# Configuration
USER_DB="/root/usuarios.db"
BACKUP_DIR="/root/ssh_backups"
BANNER_FILE="/etc/ssh/gcp_404"
SSH_CONFIG="/etc/ssh/sshd_config"
UDP_CONFIG="/etc/ssh/sshd_udp"
DNSTT_DIR="/etc/dnstt"
DNSTT_SERVICE="/etc/systemd/system/dnstt-server.service"

# Check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain} Run as root!${plain}" && exit 1

# Create SSH user
create_user() {
    local username="$1"
    local password="$2"
    local limit="$3"
    local days="$4"
    local protocol="$5"
    local message="$6"
    local token="$7"

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
    sed -i 's/#\?AllowTcpForwarding .*/AllowTcpForwarding yes/' $SSH_CONFIG
    sed -i 's/#\?PasswordAuthentication .*/PasswordAuthentication yes/' $SSH_CONFIG
    sed -i "s|#\?Banner .*|Banner $BANNER_FILE|" $SSH_CONFIG
    systemctl restart sshd

    # Set banner
    echo -e "$message" > "$BANNER_FILE"

    # Create user
    local expiry_date=$(date -d "+$days days" +%Y-%m-%d)
    local pass_hash=$(openssl passwd -1 "$password")
    useradd -e "$expiry_date" -m -s /bin/bash -p "$pass_hash" "$username"
    
    # Add to database
    echo "$username $limit $protocol" >> "$USER_DB"
    
    # Display info
    local ip=$(curl -s ifconfig.me)
    echo -e "${green}SSH Account Created:${plain}"
    echo -e "IP: $ip"
    echo -e "Username: $username"
    echo -e "Password: $password"
    echo -e "Expiry: $(date -d "$expiry_date" +%d/%m/%Y)"
    echo -e "Concurrent: $limit"
    echo -e "Protocol: $protocol"
    
    # If DNSTT user, show connection info
    if [[ "$protocol" == "dnstt" ]]; then
        echo -e "${dnstt_color}DNSTT Connection:${plain}"
        echo -e "Domain: $(grep '^domain=' $DNSTT_DIR/config 2>/dev/null | cut -d= -f2)"
        echo -e "Secret Key: $(grep '^key=' $DNSTT_DIR/config 2>/dev/null | cut -d= -f2)"
    fi
}

# Install DNSTT server
install_dnstt() {
    local domain="$1"
    local key="$2"
    local port="$3"
    
    echo -e "${dnstt_color}Installing DNSTT server...${plain}"
    
    # Install dependencies
    apt-get update
    apt-get install -y git build-essential cmake libuv1-dev libssl-dev
    
    # Create DNSTT directory
    mkdir -p $DNSTT_DIR
    
    # Clone and build DNSTT
    cd $DNSTT_DIR
    git clone https://github.com/alexbers/mtprotoproxy.git
    cd mtprotoproxy
    cmake .
    make -j$(nproc)
    
    # Create config
    cat > $DNSTT_DIR/config <<EOF
domain=$domain
key=$key
port=$port
EOF
    
    # Create systemd service
    cat > $DNSTT_SERVICE <<EOF
[Unit]
Description=DNSTT Server
After=network.target

[Service]
User=root
WorkingDirectory=$DNSTT_DIR/mtprotoproxy
ExecStart=$DNSTT_DIR/mtprotoproxy/mtprotoproxy -c $DNSTT_DIR/config
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable dnstt-server
    systemctl start dnstt-server
    
    echo -e "${green}DNSTT server installed and running!${plain}"
    echo -e "${dnstt_color}Domain:${plain} $domain"
    echo -e "${dnstt_color}Secret Key:${plain} $key"
    echo -e "${dnstt_color}Local Port:${plain} $port"
}

# Create DNSTT user
create_dnstt_user() {
    local server_ip="$1"
    local domain="$2"
    local key="$3"
    
    echo -e "${dnstt_color}Creating DNSTT user configuration...${plain}"
    
    # Create client config
    mkdir -p /etc/dnstt-client
    cat > /etc/dnstt-client/config <<EOF
server=$server_ip
domain=$domain
key=$key
local_port=443
EOF
    
    # Create client service
    cat > /etc/systemd/system/dnstt-client.service <<EOF
[Unit]
Description=DNSTT Client
After=network.target

[Service]
User=root
WorkingDirectory=/etc/dnstt-client
ExecStart=$DNSTT_DIR/mtprotoproxy/client -c /etc/dnstt-client/config
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start client
    systemctl daemon-reload
    systemctl enable dnstt-client
    systemctl start dnstt-client
    
    echo -e "${green}DNSTT client configured!${plain}"
    echo -e "${dnstt_color}Server IP:${plain} $server_ip"
    echo -e "${dnstt_color}Domain:${plain} $domain"
    echo -e "${dnstt_color}Secret Key:${plain} $key"
    echo -e "${dnstt_color}Connect to localhost:443 for SSH${plain}"
}

# List users
list_users() {
    echo -e "${yellow}=== SSH Users ===${plain}"
    printf "%-15s %-15s %-10s %-10s %-15s\n" "Username" "Expiry" "Limit" "Protocol" "Status"
    echo "------------------------------------------------------------"
    
    while read -r line; do
        local user=$(echo "$line" | awk '{print $1}')
        local limit=$(echo "$line" | awk '{print $2}')
        local protocol=$(echo "$line" | awk '{print $3}')
        local expiry=$(chage -l "$user" | grep "Account expires" | cut -d: -f2 | sed 's/^ *//')
        
        if [[ "$expiry" == "never" ]]; then
            expiry="Never"
            status="${green}Active${plain}"
        elif [[ $(date -d "$expiry" +%s) -lt $(date +%s) ]]; then
            status="${red}Expired${plain}"
        else
            status="${green}Active${plain}"
        fi
        
        printf "%-15s %-15s %-10s %-10s %-15s\n" "$user" "$expiry" "$limit" "$protocol" "$status"
    done < "$USER_DB"
}

# Main execution
case "$1" in
    --create)
        create_user "$2" "$3" "$4" "$5" "$6" "$7" "$8"
        ;;
    --install-dnstt)
        install_dnstt "$2" "$3" "$4"
        ;;
    --create-dnstt-user)
        create_dnstt_user "$2" "$3" "$4"
        ;;
    --delete)
        delete_user "$2"
        ;;
    --list)
        list_users
        ;;
    --backup)
        backup_users
        ;;
    --restore)
        restore_users "$2"
        ;;
    --sessions)
        active_sessions
        ;;
    *)
        echo "Usage: $0 [option]"
        echo "Options:"
        echo "  --create [user] [pass] [limit] [days] [protocol] [message] [token]  Create SSH user"
        echo "  --install-dnstt [domain] [key] [port]                              Install DNSTT server"
        echo "  --create-dnstt-user [server_ip] [domain] [key]                     Create DNSTT client"
        echo "  --delete [user]                                                    Delete user"
        echo "  --list                                                             List all users"
        echo "  --backup                                                           Backup user database"
        echo "  --restore [file]                                                   Restore from backup"
        echo "  --sessions                                                         Show active sessions"
        exit 1
        ;;
esac
