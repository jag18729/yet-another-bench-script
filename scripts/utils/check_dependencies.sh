#!/bin/bash

# Dependency Check Script for Network Performance Testing Suite
# Validates all required tools and libraries are installed

SCRIPT_VERSION="v1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
source "$PROJECT_ROOT/lib/common_functions.sh"

echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e '#          Dependency Check Script                   #'
echo -e '#                   '$SCRIPT_VERSION'                  #'
echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macOS"
        INSTALL_CMD="brew install"
        PYTHON_INSTALL="pip3 install"
    elif [[ -f /etc/debian_version ]]; then
        OS="Debian/Ubuntu"
        INSTALL_CMD="sudo apt-get install -y"
        PYTHON_INSTALL="pip3 install"
    elif [[ -f /etc/redhat-release ]]; then
        OS="RedHat/CentOS"
        INSTALL_CMD="sudo yum install -y"
        PYTHON_INSTALL="pip3 install"
    else
        OS="Unknown"
        INSTALL_CMD="unknown"
    fi
    
    echo -e "${BLUE}Detected OS: $OS${NC}"
    echo ""
}

# Check system commands
check_system_commands() {
    echo -e "${YELLOW}Checking system commands...${NC}"
    
    commands=(
        "bash:Shell interpreter:bash"
        "ping:Network connectivity:iputils-ping"
        "dig:DNS queries:dnsutils|bind-utils"
        "traceroute:Network path:traceroute"
        "nc:Network connections:netcat|netcat-openbsd"
        "ssh:Secure shell:openssh-client"
        "scp:Secure copy:openssh-client"
        "rsync:File sync:rsync"
        "curl:HTTP client:curl"
        "wget:HTTP download:wget"
        "bc:Calculator:bc"
        "jq:JSON processor:jq"
        "awk:Text processing:gawk|mawk"
        "sed:Stream editor:sed"
        "grep:Pattern matching:grep"
    )
    
    missing=0
    for cmd_info in "${commands[@]}"; do
        IFS=':' read -r cmd desc pkg <<< "$cmd_info"
        
        if command -v "$cmd" >/dev/null 2>&1; then
            version=$(get_version "$cmd")
            echo -e "${GREEN}✓ $cmd${NC} - $desc ${version}"
        else
            echo -e "${RED}✗ $cmd${NC} - $desc"
            echo -e "  Install: ${INSTALL_CMD} ${pkg}"
            ((missing++))
        fi
    done
    
    return $missing
}

# Check network testing tools
check_network_tools() {
    echo -e "\n${YELLOW}Checking network testing tools...${NC}"
    
    tools=(
        "iperf3:Throughput testing:iperf3"
        "mtr:Network diagnostic:mtr"
        "nmap:Port scanning:nmap"
        "tcpdump:Packet capture:tcpdump"
    )
    
    missing=0
    for tool_info in "${tools[@]}"; do
        IFS=':' read -r tool desc pkg <<< "$tool_info"
        
        if command -v "$tool" >/dev/null 2>&1; then
            version=$(get_version "$tool")
            echo -e "${GREEN}✓ $tool${NC} - $desc ${version}"
        else
            echo -e "${YELLOW}○ $tool${NC} - $desc (optional)"
            echo -e "  Install: ${INSTALL_CMD} ${pkg}"
            ((missing++))
        fi
    done
    
    # Check for DNS performance tools
    if command -v dnsperf >/dev/null 2>&1; then
        echo -e "${GREEN}✓ dnsperf${NC} - DNS performance testing"
    else
        echo -e "${YELLOW}○ dnsperf${NC} - DNS performance testing (optional)"
        echo -e "  Install: Build from source at https://www.dns-oarc.net/tools/dnsperf"
    fi
    
    return 0
}

# Check Python and packages
check_python() {
    echo -e "\n${YELLOW}Checking Python environment...${NC}"
    
    # Check Python 3
    if command -v python3 >/dev/null 2>&1; then
        py_version=$(python3 --version 2>&1 | awk '{print $2}')
        echo -e "${GREEN}✓ Python 3${NC} - Version $py_version"
        
        # Check pip
        if python3 -m pip --version >/dev/null 2>&1; then
            pip_version=$(python3 -m pip --version | awk '{print $2}')
            echo -e "${GREEN}✓ pip${NC} - Version $pip_version"
        else
            echo -e "${RED}✗ pip${NC} - Python package installer"
            echo -e "  Install: python3 -m ensurepip"
        fi
        
        # Check Python packages
        echo -e "\n${YELLOW}Checking Python packages...${NC}"
        packages=(
            "matplotlib:Plotting library:matplotlib"
            "numpy:Numerical computing:numpy"
            "pandas:Data analysis:pandas"
            "requests:HTTP library:requests"
        )
        
        missing_pkgs=0
        for pkg_info in "${packages[@]}"; do
            IFS=':' read -r pkg desc pip_name <<< "$pkg_info"
            
            if python3 -c "import $pkg" 2>/dev/null; then
                version=$(python3 -c "import $pkg; print($pkg.__version__)" 2>/dev/null || echo "")
                echo -e "${GREEN}✓ $pkg${NC} - $desc ${version}"
            else
                echo -e "${RED}✗ $pkg${NC} - $desc"
                echo -e "  Install: ${PYTHON_INSTALL} ${pip_name}"
                ((missing_pkgs++))
            fi
        done
        
        return $missing_pkgs
    else
        echo -e "${RED}✗ Python 3${NC} - Not found"
        echo -e "  Install: ${INSTALL_CMD} python3 python3-pip"
        return 1
    fi
}

# Check disk space
check_disk_space() {
    echo -e "\n${YELLOW}Checking disk space...${NC}"
    
    # Get available space in MB
    if [[ "$OSTYPE" == "darwin"* ]]; then
        available=$(df -m . | awk 'NR==2 {print $4}')
    else
        available=$(df -BM . | awk 'NR==2 {print $4}' | sed 's/M//')
    fi
    
    if [ "$available" -gt 2048 ]; then
        echo -e "${GREEN}✓ Disk space${NC} - ${available}MB available (>2GB required)"
    else
        echo -e "${RED}✗ Disk space${NC} - ${available}MB available (<2GB)"
        echo -e "  At least 2GB recommended for test files and results"
    fi
}

# Check permissions
check_permissions() {
    echo -e "\n${YELLOW}Checking permissions...${NC}"
    
    # Check if scripts are executable
    scripts=(
        "$PROJECT_ROOT/yabs.sh"
        "$PROJECT_ROOT/scripts/core/network_performance_test.sh"
        "$PROJECT_ROOT/scripts/core/dns_performance_test.sh"
        "$PROJECT_ROOT/scripts/core/data_transfer_test.sh"
        "$PROJECT_ROOT/scripts/core/performance_test_suite.sh"
        "$PROJECT_ROOT/scripts/setup/server/setup_server.sh"
        "$PROJECT_ROOT/scripts/setup/client/setup_client.sh"
    )
    
    missing_exec=0
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                echo -e "${GREEN}✓ $(basename "$script")${NC} - Executable"
            else
                echo -e "${YELLOW}! $script${NC} - Not executable"
                echo -e "  Fix: chmod +x $script"
                ((missing_exec++))
            fi
        else
            echo -e "${YELLOW}? $script${NC} - Not found in current directory"
        fi
    done
    
    if [ $missing_exec -gt 0 ]; then
        echo -e "\n  Fix all: ${YELLOW}chmod +x *.sh${NC}"
    fi
}

# Get version info for commands
get_version() {
    local cmd=$1
    case $cmd in
        iperf3)
            iperf3 --version 2>&1 | head -1 | awk '{print $2}' | tr -d ','
            ;;
        python3)
            python3 --version 2>&1 | awk '{print $2}'
            ;;
        *)
            echo ""
            ;;
    esac
}

# Generate installation script
generate_install_script() {
    echo -e "\n${YELLOW}Generating installation commands...${NC}"
    
    local install_file="install_dependencies.sh"
    
    cat > "$install_file" <<EOF
#!/bin/bash
# Auto-generated dependency installation script

echo "Installing dependencies for $OS..."

EOF
    
    if [[ "$OS" == "macOS" ]]; then
        cat >> "$install_file" <<'EOF'
# Install Homebrew if not present
if ! command -v brew >/dev/null 2>&1; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Update Homebrew
brew update

# Install tools
brew install iperf3 wget curl rsync jq bc gnu-sed coreutils netcat mtr parallel

# Install Python packages
pip3 install matplotlib numpy pandas requests

EOF
    elif [[ "$OS" == "Debian/Ubuntu" ]]; then
        cat >> "$install_file" <<'EOF'
# Update package list
sudo apt-get update

# Install tools
sudo apt-get install -y \
    iperf3 openssh-client openssh-server \
    dnsutils traceroute mtr netcat \
    curl wget rsync bc jq \
    python3 python3-pip \
    nginx dnsmasq ufw \
    build-essential git

# Install Python packages
pip3 install matplotlib numpy pandas requests

EOF
    fi
    
    chmod +x "$install_file"
    echo -e "${GREEN}Created: $install_file${NC}"
}

# Main summary
print_summary() {
    echo -e "\n${BLUE}==== DEPENDENCY CHECK SUMMARY ====${NC}"
    
    local total_issues=0
    
    # Check each category
    check_system_commands
    sys_missing=$?
    total_issues=$((total_issues + sys_missing))
    
    check_network_tools
    
    check_python
    py_missing=$?
    total_issues=$((total_issues + py_missing))
    
    check_disk_space
    check_permissions
    
    echo -e "\n${BLUE}==== FINAL STATUS ====${NC}"
    
    if [ $total_issues -eq 0 ]; then
        echo -e "${GREEN}✓ All required dependencies are installed!${NC}"
        echo -e "  You're ready to run the performance tests."
    else
        echo -e "${RED}✗ Missing $total_issues required dependencies${NC}"
        echo -e "  Run the generated install script or install manually."
        generate_install_script
    fi
    
    echo -e "\n${BLUE}Quick Start:${NC}"
    echo -e "1. Server setup: ${YELLOW}sudo ./scripts/setup/server/setup_server.sh${NC}"
    echo -e "2. Client setup: ${YELLOW}./scripts/setup/client/setup_client.sh${NC}"
    echo -e "3. Run tests:    ${YELLOW}./scripts/core/performance_test_suite.sh -p pre${NC}"
}

# Main execution
main() {
    detect_os
    print_summary
}

# Run main
main