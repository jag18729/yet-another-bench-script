#!/bin/bash

# Server Setup Script for Network Performance Testing
# Run this on your Zorin VM (Parallels) to set up test servers

SCRIPT_VERSION="v1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source common functions if available
if [ -f "$PROJECT_ROOT/lib/common_functions.sh" ]; then
    source "$PROJECT_ROOT/lib/common_functions.sh"
fi

echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e '#        Network Test Server Setup Script            #'
echo -e '#                   '$SCRIPT_VERSION'                  #'
echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if running with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Please run this script with sudo${NC}"
        exit 1
    fi
}

# Function to get VM IP address
get_ip_address() {
    # Get the primary network interface IP
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1
}

# Function to check and install dependencies
install_dependencies() {
    echo -e "${YELLOW}Checking and installing required packages...${NC}"
    
    # Update package list
    echo -e "Updating package list..."
    apt-get update -qq
    
    # Core packages required
    packages=(
        "iperf3"
        "openssh-server"
        "dnsmasq"
        "nginx"
        "rsync"
        "python3"
        "python3-pip"
        "net-tools"
        "ufw"
        "bc"
        "jq"
        "curl"
        "wget"
        "dnsutils"
        "traceroute"
        "mtr"
        "netcat"
        "git"
        "build-essential"
    )
    
    # Python packages required
    python_packages=(
        "matplotlib"
        "numpy"
        "pandas"
    )
    
    echo -e "\n${YELLOW}Installing system packages...${NC}"
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package"; then
            echo -e "Installing $package..."
            apt-get install -y "$package" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ $package installed${NC}"
            else
                echo -e "${RED}✗ Failed to install $package${NC}"
                # Try alternative package names
                case $package in
                    "dnsutils")
                        echo -e "  Trying bind9-dnsutils..."
                        apt-get install -y bind9-dnsutils >/dev/null 2>&1 && echo -e "${GREEN}✓ bind9-dnsutils installed${NC}"
                        ;;
                    "netcat")
                        echo -e "  Trying netcat-openbsd..."
                        apt-get install -y netcat-openbsd >/dev/null 2>&1 && echo -e "${GREEN}✓ netcat-openbsd installed${NC}"
                        ;;
                esac
            fi
        else
            echo -e "${GREEN}✓ $package already installed${NC}"
        fi
    done
    
    # Install Python packages
    echo -e "\n${YELLOW}Installing Python packages...${NC}"
    for package in "${python_packages[@]}"; do
        if ! python3 -c "import $package" 2>/dev/null; then
            echo -e "Installing Python package: $package..."
            pip3 install "$package" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ $package installed${NC}"
            else
                echo -e "${RED}✗ Failed to install $package${NC}"
            fi
        else
            echo -e "${GREEN}✓ Python $package already installed${NC}"
        fi
    done
    
    # Verify critical commands are available
    echo -e "\n${YELLOW}Verifying installed tools...${NC}"
    commands=(
        "iperf3:Network throughput testing"
        "dig:DNS testing"
        "traceroute:Network path analysis"
        "nc:Port connectivity testing"
        "jq:JSON processing"
        "bc:Calculations"
        "python3:Script execution"
    )
    
    for cmd_desc in "${commands[@]}"; do
        cmd="${cmd_desc%%:*}"
        desc="${cmd_desc#*:}"
        if command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $cmd - $desc${NC}"
        else
            echo -e "${RED}✗ $cmd - $desc (not found)${NC}"
        fi
    done
}

# Function to setup iperf3 server
setup_iperf3() {
    echo -e "\n${YELLOW}Setting up iperf3 server...${NC}"
    
    # Create systemd service for iperf3
    cat > /etc/systemd/system/iperf3-server.service <<EOF
[Unit]
Description=iperf3 Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/iperf3 -s -p 5201
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start iperf3 service
    systemctl daemon-reload
    systemctl enable iperf3-server.service
    systemctl restart iperf3-server.service
    
    if systemctl is-active --quiet iperf3-server.service; then
        echo -e "${GREEN}✓ iperf3 server running on port 5201${NC}"
    else
        echo -e "${RED}✗ Failed to start iperf3 server${NC}"
    fi
}

# Function to setup SSH server
setup_ssh() {
    echo -e "\n${YELLOW}Configuring SSH server...${NC}"
    
    # Ensure SSH is enabled and running
    systemctl enable ssh
    systemctl start ssh
    
    # Create test directory for file transfers
    mkdir -p /home/$SUDO_USER/test_transfers
    chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/test_transfers
    chmod 755 /home/$SUDO_USER/test_transfers
    
    echo -e "${GREEN}✓ SSH server configured${NC}"
    echo -e "  Transfer test directory: /home/$SUDO_USER/test_transfers"
}

# Function to setup web server for download tests
setup_web_server() {
    echo -e "\n${YELLOW}Setting up web server for download tests...${NC}"
    
    # Create test files directory
    mkdir -p /var/www/html/speedtest
    
    # Generate test files of various sizes
    echo -e "Generating test files..."
    dd if=/dev/urandom of=/var/www/html/speedtest/10MB.bin bs=1M count=10 2>/dev/null
    dd if=/dev/urandom of=/var/www/html/speedtest/100MB.bin bs=1M count=100 2>/dev/null
    dd if=/dev/urandom of=/var/www/html/speedtest/1GB.bin bs=1M count=1024 2>/dev/null
    
    # Set permissions
    chmod 644 /var/www/html/speedtest/*
    
    # Configure nginx
    cat > /etc/nginx/sites-available/speedtest <<EOF
server {
    listen 80;
    server_name _;
    
    location /speedtest/ {
        root /var/www/html;
        autoindex on;
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/speedtest /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Restart nginx
    systemctl restart nginx
    
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ Web server running on port 80${NC}"
        echo -e "  Test files available at:"
        echo -e "    http://$(get_ip_address)/speedtest/10MB.bin"
        echo -e "    http://$(get_ip_address)/speedtest/100MB.bin"
        echo -e "    http://$(get_ip_address)/speedtest/1GB.bin"
    else
        echo -e "${RED}✗ Failed to start web server${NC}"
    fi
}

# Function to setup DNS server
setup_dns() {
    echo -e "\n${YELLOW}Setting up DNS server for testing...${NC}"
    
    # Backup original config
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
    
    # Configure dnsmasq for testing
    cat > /etc/dnsmasq.conf <<EOF
# DNS test server configuration
port=53
no-dhcp-interface=
bind-interfaces
listen-address=$(get_ip_address)
cache-size=1000

# Forward to public DNS servers
server=8.8.8.8
server=8.8.4.4
server=1.1.1.1

# Local test domains
address=/test.local/$(get_ip_address)
address=/speedtest.local/$(get_ip_address)
EOF
    
    # Restart dnsmasq
    systemctl restart dnsmasq
    
    if systemctl is-active --quiet dnsmasq; then
        echo -e "${GREEN}✓ DNS server running on port 53${NC}"
    else
        echo -e "${RED}✗ Failed to start DNS server${NC}"
    fi
}

# Function to configure firewall
configure_firewall() {
    echo -e "\n${YELLOW}Configuring firewall...${NC}"
    
    # Enable UFW
    ufw --force enable >/dev/null 2>&1
    
    # Allow required ports
    ufw allow 22/tcp comment 'SSH' >/dev/null 2>&1
    ufw allow 80/tcp comment 'HTTP' >/dev/null 2>&1
    ufw allow 53 comment 'DNS' >/dev/null 2>&1
    ufw allow 5201/tcp comment 'iperf3' >/dev/null 2>&1
    
    echo -e "${GREEN}✓ Firewall configured${NC}"
}

# Function to create client configuration file
create_client_config() {
    local vm_ip=$(get_ip_address)
    local config_file="/home/$SUDO_USER/client_config.conf"
    
    echo -e "\n${YELLOW}Creating client configuration file...${NC}"
    
    cat > "$config_file" <<EOF
# Network Performance Test Configuration
# Generated by server setup script

# Server IP address
SERVER_IP=$vm_ip

# Network test configuration
DESTINATION_IP=$vm_ip
IPERF_SERVER=$vm_ip

# DNS test configuration
DNS_SERVER=$vm_ip

# Data transfer test configuration
REMOTE_HOST=$vm_ip
REMOTE_USER=$SUDO_USER
REMOTE_PATH=/home/$SUDO_USER/test_transfers

# Download URLs
DOWNLOAD_URL=http://$vm_ip/speedtest/100MB.bin

# Test file URLs
TEST_FILE_10MB=http://$vm_ip/speedtest/10MB.bin
TEST_FILE_100MB=http://$vm_ip/speedtest/100MB.bin
TEST_FILE_1GB=http://$vm_ip/speedtest/1GB.bin
EOF
    
    chown $SUDO_USER:$SUDO_USER "$config_file"
    
    echo -e "${GREEN}✓ Client configuration saved to: $config_file${NC}"
    echo -e "  Copy this file to your Mac client"
}

# Function to display summary
display_summary() {
    local vm_ip=$(get_ip_address)
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Server Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "\nServer IP Address: ${YELLOW}$vm_ip${NC}"
    echo -e "\nServices Running:"
    echo -e "  • iperf3 server on port 5201"
    echo -e "  • SSH server on port 22"
    echo -e "  • Web server on port 80"
    echo -e "  • DNS server on port 53"
    echo -e "\nTest Resources:"
    echo -e "  • Download files: http://$vm_ip/speedtest/"
    echo -e "  • SSH transfers: $SUDO_USER@$vm_ip:/home/$SUDO_USER/test_transfers"
    echo -e "\nNext Steps:"
    echo -e "  1. Copy ${YELLOW}/home/$SUDO_USER/client_config.conf${NC} to your Mac"
    echo -e "  2. On your Mac, run: ${YELLOW}./scripts/setup/client/setup_client.sh${NC}"
    echo -e "  3. Use the config file for testing: ${YELLOW}./scripts/core/performance_test_suite.sh -c configs/client_config.conf${NC}"
}

# Main execution
main() {
    echo "This script will set up network test servers on your Zorin VM"
    echo "It will install and configure: iperf3, SSH, nginx, and dnsmasq"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    check_sudo
    install_dependencies
    setup_iperf3
    setup_ssh
    setup_web_server
    setup_dns
    configure_firewall
    create_client_config
    display_summary
}

# Run main function
main