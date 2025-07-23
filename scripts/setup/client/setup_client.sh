#!/bin/bash

# Client Setup Script for Network Performance Testing
# Run this on your Mac to prepare for testing against the Zorin VM server

SCRIPT_VERSION="v1.0.0"

echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e '#        Network Test Client Setup Script            #'
echo -e '#                   '$SCRIPT_VERSION'                  #'
echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e

# Colors for output (macOS compatible)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check for Homebrew
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Homebrew not found. Installing...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        echo -e "${GREEN}✓ Homebrew already installed${NC}"
    fi
}

# Function to check and install dependencies
install_dependencies() {
    echo -e "\n${YELLOW}Checking and installing required tools...${NC}"
    
    # Tools to install via Homebrew
    brew_tools=(
        "iperf3:Network throughput testing"
        "wget:HTTP download testing"
        "curl:HTTP transfer testing"
        "rsync:File synchronization testing"
        "jq:JSON processing"
        "gnu-sed:Text processing"
        "coreutils:GNU core utilities"
        "python@3.11:Python runtime"
        "bc:Calculator for scripts"
        "netcat:Network connectivity testing"
        "mtr:Network diagnostic tool"
        "parallel:Parallel execution"
    )
    
    # First, update Homebrew
    echo -e "Updating Homebrew..."
    brew update >/dev/null 2>&1
    
    echo -e "\n${YELLOW}Installing Homebrew packages...${NC}"
    for tool_desc in "${brew_tools[@]}"; do
        tool="${tool_desc%%:*}"
        desc="${tool_desc#*:}"
        
        if brew list "$tool" &> /dev/null; then
            echo -e "${GREEN}✓ $tool already installed - $desc${NC}"
        else
            echo -e "Installing $tool - $desc..."
            brew install "$tool" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ $tool installed${NC}"
            else
                echo -e "${RED}✗ Failed to install $tool${NC}"
                # Try alternative names
                case $tool in
                    "parallel")
                        echo -e "  Note: GNU parallel may require: brew install --HEAD parallel"
                        ;;
                esac
            fi
        fi
    done
    
    # Python packages to install
    python_packages=(
        "matplotlib:Visualization library"
        "numpy:Numerical computing"
        "pandas:Data analysis"
        "requests:HTTP library"
    )
    
    # Install Python packages
    echo -e "\n${YELLOW}Installing Python packages...${NC}"
    
    # Ensure pip is up to date
    python3 -m pip install --upgrade pip >/dev/null 2>&1
    
    for package_desc in "${python_packages[@]}"; do
        package="${package_desc%%:*}"
        desc="${package_desc#*:}"
        
        if python3 -c "import $package" 2>/dev/null; then
            echo -e "${GREEN}✓ Python $package already installed - $desc${NC}"
        else
            echo -e "Installing Python $package - $desc..."
            pip3 install "$package" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Python $package installed${NC}"
            else
                echo -e "${RED}✗ Failed to install Python $package${NC}"
            fi
        fi
    done
    
    # Verify all required commands are available
    echo -e "\n${YELLOW}Verifying installed tools...${NC}"
    required_commands=(
        "iperf3:Network throughput testing"
        "ping:Basic connectivity testing"
        "dig:DNS query testing"
        "traceroute:Network path analysis"
        "nc:Port connectivity testing"
        "jq:JSON processing"
        "bc:Mathematical calculations"
        "python3:Python scripts"
        "gsed:GNU sed (from gnu-sed)"
        "gdate:GNU date (from coreutils)"
    )
    
    missing_tools=0
    for cmd_desc in "${required_commands[@]}"; do
        cmd="${cmd_desc%%:*}"
        desc="${cmd_desc#*:}"
        if command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $cmd - $desc${NC}"
        else
            echo -e "${RED}✗ $cmd - $desc (not found)${NC}"
            ((missing_tools++))
        fi
    done
    
    # Check for optional tools
    echo -e "\n${YELLOW}Checking optional tools...${NC}"
    optional_commands=(
        "mtr:Enhanced traceroute"
        "parallel:Parallel execution"
        "dnsperf:Advanced DNS testing"
        "aria2c:Parallel downloads"
    )
    
    for cmd_desc in "${optional_commands[@]}"; do
        cmd="${cmd_desc%%:*}"
        desc="${cmd_desc#*:}"
        if command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $cmd - $desc (available)${NC}"
        else
            echo -e "${YELLOW}○ $cmd - $desc (not installed, optional)${NC}"
        fi
    done
    
    if [ $missing_tools -gt 0 ]; then
        echo -e "\n${RED}Warning: Some required tools are missing${NC}"
        echo -e "The test suite may not function properly"
        return 1
    else
        echo -e "\n${GREEN}All required tools are installed!${NC}"
        return 0
    fi
}

# Function to verify VM connectivity
verify_connectivity() {
    echo -e "\n${YELLOW}Verifying connectivity to VM server...${NC}"
    
    read -p "Enter your Zorin VM IP address: " VM_IP
    
    # Test basic connectivity
    echo -e "Testing connectivity to $VM_IP..."
    
    if ping -c 1 "$VM_IP" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ VM is reachable${NC}"
    else
        echo -e "${RED}✗ Cannot reach VM at $VM_IP${NC}"
        echo -e "Please check:"
        echo -e "  1. VM is running"
        echo -e "  2. VM network adapter is in Bridged mode"
        echo -e "  3. No firewall blocking connection"
        return 1
    fi
    
    # Test specific services
    echo -e "\nTesting services..."
    
    # Test iperf3
    if nc -z "$VM_IP" 5201 2>/dev/null; then
        echo -e "${GREEN}✓ iperf3 server accessible${NC}"
    else
        echo -e "${RED}✗ iperf3 server not accessible on port 5201${NC}"
    fi
    
    # Test SSH
    if nc -z "$VM_IP" 22 2>/dev/null; then
        echo -e "${GREEN}✓ SSH server accessible${NC}"
    else
        echo -e "${RED}✗ SSH server not accessible on port 22${NC}"
    fi
    
    # Test HTTP
    if nc -z "$VM_IP" 80 2>/dev/null; then
        echo -e "${GREEN}✓ Web server accessible${NC}"
    else
        echo -e "${RED}✗ Web server not accessible on port 80${NC}"
    fi
    
    # Test DNS
    if nc -z "$VM_IP" 53 2>/dev/null; then
        echo -e "${GREEN}✓ DNS server accessible${NC}"
    else
        echo -e "${RED}✗ DNS server not accessible on port 53${NC}"
    fi
    
    return 0
}

# Function to setup SSH key
setup_ssh_key() {
    echo -e "\n${YELLOW}Setting up SSH key for passwordless access...${NC}"
    
    read -p "Enter your VM username: " VM_USER
    
    # Check if SSH key exists
    if [ ! -f ~/.ssh/id_rsa ]; then
        echo -e "Generating SSH key..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" >/dev/null 2>&1
        echo -e "${GREEN}✓ SSH key generated${NC}"
    else
        echo -e "${GREEN}✓ SSH key already exists${NC}"
    fi
    
    # Copy SSH key to VM
    echo -e "Copying SSH key to VM (you'll be prompted for password)..."
    ssh-copy-id "$VM_USER@$VM_IP" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ SSH key copied successfully${NC}"
    else
        echo -e "${YELLOW}! Could not copy SSH key automatically${NC}"
        echo -e "  You may need to do this manually later"
    fi
}

# Function to create test configuration
create_test_config() {
    echo -e "\n${YELLOW}Creating test configuration...${NC}"
    
    # Check if client_config.conf was provided
    if [ -f "client_config.conf" ]; then
        echo -e "${GREEN}✓ Using existing client_config.conf${NC}"
    else
        # Create configuration file
        cat > client_config.conf <<EOF
# Network Performance Test Configuration
# For Mac client testing against Zorin VM server

# Server IP address
SERVER_IP=$VM_IP

# Network test configuration
DESTINATION_IP=$VM_IP
IPERF_SERVER=$VM_IP

# DNS test configuration
DNS_SERVER=$VM_IP

# Data transfer test configuration
REMOTE_HOST=$VM_IP
REMOTE_USER=$VM_USER
REMOTE_PATH=/home/$VM_USER/test_transfers

# Download URLs
DOWNLOAD_URL=http://$VM_IP/speedtest/100MB.bin

# Test file URLs
TEST_FILE_10MB=http://$VM_IP/speedtest/10MB.bin
TEST_FILE_100MB=http://$VM_IP/speedtest/100MB.bin
TEST_FILE_1GB=http://$VM_IP/speedtest/1GB.bin
EOF
        
        echo -e "${GREEN}✓ Configuration file created: client_config.conf${NC}"
    fi
}

# Function to test basic connectivity
run_basic_tests() {
    echo -e "\n${YELLOW}Running basic connectivity tests...${NC}"
    
    # Test ping
    echo -e "\n1. Ping test:"
    ping -c 5 "$VM_IP" | tail -2
    
    # Test iperf3
    echo -e "\n2. Quick iperf3 test (5 seconds):"
    iperf3 -c "$VM_IP" -t 5 -f m | grep -E "(sender|receiver)"
    
    # Test HTTP download
    echo -e "\n3. HTTP download test:"
    curl -o /dev/null -s -w "Download speed: %{speed_download} bytes/sec\n" "http://$VM_IP/speedtest/10MB.bin"
    
    # Test DNS
    echo -e "\n4. DNS query test:"
    dig @"$VM_IP" test.local +short
}

# Function to display next steps
display_next_steps() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Client Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "\nYour Mac is now ready to run performance tests against the Zorin VM"
    echo -e "\nConfiguration Summary:"
    echo -e "  • VM Server IP: ${YELLOW}$VM_IP${NC}"
    echo -e "  • VM Username: ${YELLOW}$VM_USER${NC}"
    echo -e "  • Config file: ${YELLOW}client_config.conf${NC}"
    echo -e "\nTo run tests:"
    echo -e "\n1. Full test suite:"
    echo -e "   ${YELLOW}./scripts/core/performance_test_suite.sh -p pre -c configs/client_config.conf${NC}"
    echo -e "\n2. Individual tests:"
    echo -e "   ${YELLOW}./network_performance_test.sh -t all -d $VM_IP -s $VM_IP -p pre${NC}"
    echo -e "   ${YELLOW}./dns_performance_test.sh -s $VM_IP -p pre${NC}"
    echo -e "   ${YELLOW}./data_transfer_test.sh -t all -h $VM_IP -u $VM_USER -r /home/$VM_USER/test_transfers -p pre${NC}"
    echo -e "\n3. After making network changes, run with '-p post' instead of '-p pre'"
    echo -e "\n4. Compare results:"
    echo -e "   ${YELLOW}python3 process_results.py test_results_* -r${NC}"
    echo -e "   ${YELLOW}python3 visualize_results.py test_results_* -s${NC}"
}

# Main execution
main() {
    echo "This script will set up your Mac as a client for network performance testing"
    echo "It will install required tools and configure connection to your Zorin VM"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    check_homebrew
    install_dependencies
    
    if verify_connectivity; then
        setup_ssh_key
        create_test_config
        
        echo ""
        read -p "Run basic connectivity tests? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_basic_tests
        fi
        
        display_next_steps
    else
        echo -e "\n${RED}Setup incomplete due to connectivity issues${NC}"
        echo -e "Please fix the connection issues and run this script again"
    fi
}

# Run main function
main