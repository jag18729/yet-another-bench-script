#!/bin/bash

# YABS Environment Setup Script
# Purpose: Automated setup of YABS extended testing environment with all dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source common functions if available
if [ -f "$PROJECT_ROOT/lib/common_functions.sh" ]; then
    source "$PROJECT_ROOT/lib/common_functions.sh"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/yabs"
LOG_DIR="/var/log/yabs"
SYSTEMD_DIR="/etc/systemd/system"
GITHUB_REPO="https://github.com/masonr/yet-another-bench-script"

# Logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        OS_ID=$ID
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    log "Detected OS: $OS $VER"
}

# Install dependencies based on OS
install_dependencies() {
    log "Installing dependencies..."
    
    local common_deps=(
        "curl"
        "wget"
        "git"
        "jq"
        "bc"
        "dnsutils"
        "net-tools"
        "iputils-ping"
        "traceroute"
        "iperf3"
        "fio"
        "python3"
        "python3-pip"
    )
    
    case "$OS_ID" in
        ubuntu|debian)
            apt-get update
            apt-get install -y "${common_deps[@]}" python3-matplotlib
            ;;
        centos|rhel|fedora)
            yum install -y epel-release
            yum install -y "${common_deps[@]}" python3-matplotlib
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm "${common_deps[@]}" python-matplotlib
            ;;
        darwin)
            # macOS
            if ! command -v brew >/dev/null 2>&1; then
                error "Homebrew is required on macOS. Please install from https://brew.sh"
            fi
            log "Installing dependencies via Homebrew..."
            # Install available brew packages
            brew install curl wget git jq bc coreutils
            brew install --cask wireshark  # for network tools
            brew install iperf3 fio
            # Python packages via brew
            brew install python@3.11 python-matplotlib
            ;;
        *)
            warning "Unsupported OS. Please install dependencies manually."
            ;;
    esac
    
    # Install Python dependencies
    if [[ "$OS_ID" != "darwin" ]]; then
        pip3 install --quiet matplotlib pandas numpy
    else
        log "Python packages installed via Homebrew on macOS"
    fi
}

# Create directory structure
create_directories() {
    log "Creating directory structure..."
    
    mkdir -p "$INSTALL_DIR"/{scripts,results,bin}
    mkdir -p "$LOG_DIR"
    
    # Set permissions
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$LOG_DIR"
}

# Download and install YABS
install_yabs() {
    log "Installing YABS..."
    
    cd "$INSTALL_DIR"
    
    # Download original YABS
    if [ ! -f "yabs.sh" ]; then
        curl -sL https://yabs.sh -o yabs.sh
        chmod +x yabs.sh
    fi
    
    # Copy our extended scripts
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ -f "$script_dir/yabs_extended.sh" ]; then
        cp "$script_dir/yabs_extended.sh" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/yabs_extended.sh"
    fi
    
    # Copy core test scripts
    if [ -d "$script_dir/scripts/core" ]; then
        mkdir -p "$INSTALL_DIR/scripts/core"
        cp -r "$script_dir/scripts/core/"* "$INSTALL_DIR/scripts/core/"
        chmod +x "$INSTALL_DIR/scripts/core/"*.sh
    fi
    
    # Copy helper scripts
    if [ -d "$script_dir/scripts" ]; then
        cp -r "$script_dir/scripts"/* "$INSTALL_DIR/scripts/"
        chmod +x "$INSTALL_DIR/scripts"/*.sh
    fi
    
    # Copy Python analysis scripts
    for script in process_results.py visualize_results.py; do
        if [ -f "$script_dir/$script" ]; then
            cp "$script_dir/$script" "$INSTALL_DIR/scripts/"
            chmod +x "$INSTALL_DIR/scripts/$script"
        fi
    done
}

# Install systemd services
install_systemd_services() {
    log "Installing systemd services..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ -d "$script_dir/systemd" ]; then
        # Copy service files
        cp "$script_dir/systemd"/*.service "$SYSTEMD_DIR/"
        cp "$script_dir/systemd"/*.timer "$SYSTEMD_DIR/"
        
        # Update paths in service files
        sed -i "s|/opt/yabs|$INSTALL_DIR|g" "$SYSTEMD_DIR"/yabs-*.service
        sed -i "s|/var/log/yabs|$LOG_DIR|g" "$SYSTEMD_DIR"/yabs-*.service
        
        # Reload systemd
        systemctl daemon-reload
        
        # Enable services
        systemctl enable yabs-monitor.timer
        systemctl enable yabs-healthcheck.timer
        
        log "Systemd services installed and enabled"
    else
        warning "Systemd service files not found"
    fi
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    # Check if firewall is active
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            # Allow iperf3 default port
            ufw allow 5201/tcp comment "iperf3"
            ufw allow 5201/udp comment "iperf3"
            log "UFW rules added for iperf3"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if systemctl is-active firewalld >/dev/null 2>&1; then
            firewall-cmd --permanent --add-port=5201/tcp
            firewall-cmd --permanent --add-port=5201/udp
            firewall-cmd --reload
            log "Firewalld rules added for iperf3"
        fi
    fi
}

# Create configuration file
create_config() {
    log "Creating configuration file..."
    
    cat > "$INSTALL_DIR/yabs.conf" <<EOF
# YABS Extended Configuration File
# Generated on $(date)

# Installation directory
YABS_DIR="$INSTALL_DIR"

# Log directory
LOG_DIR="$LOG_DIR"

# Test configuration
DEFAULT_PING_COUNT=20
DEFAULT_DNS_QUERIES=20
TRACEROUTE_MAX_HOPS=30

# Test targets
PING_TARGETS="8.8.8.8 1.1.1.1 9.9.9.9"
DNS_SERVERS="8.8.8.8 1.1.1.1 9.9.9.9"
TRACE_TARGETS="8.8.8.8 google.com"

# Notification settings (optional)
#SLACK_WEBHOOK=""
#EMAIL_RECIPIENT=""

# Data retention (days)
LOG_RETENTION_DAYS=30
RESULTS_RETENTION_DAYS=90
EOF
    
    chmod 644 "$INSTALL_DIR/yabs.conf"
}

# Test installation
test_installation() {
    log "Testing installation..."
    
    cd "$INSTALL_DIR"
    
    # Quick test
    if ./yabs_extended.sh -Y -N -p test_install; then
        log "Installation test passed"
    else
        warning "Installation test failed - please check logs"
    fi
}

# Print summary
print_summary() {
    echo ""
    echo -e "${BLUE}=== YABS Extended Installation Complete ===${NC}"
    echo ""
    echo "Installation directory: $INSTALL_DIR"
    echo "Log directory: $LOG_DIR"
    echo "Configuration: $INSTALL_DIR/yabs.conf"
    echo ""
    echo "Systemd services:"
    echo "  - yabs-monitor.timer (runs every 6 hours)"
    echo "  - yabs-healthcheck.timer (runs every 15 minutes)"
    echo ""
    echo "Commands:"
    echo "  - Run manual test: $INSTALL_DIR/yabs_extended.sh"
    echo "  - View logs: journalctl -u yabs-monitor"
    echo "  - Check status: systemctl status yabs-monitor.timer"
    echo ""
    echo -e "${GREEN}Setup complete!${NC}"
}

# Main installation
main() {
    echo -e "${BLUE}=== YABS Extended Environment Setup ===${NC}"
    echo ""
    
    check_root
    detect_os
    install_dependencies
    create_directories
    install_yabs
    install_systemd_services
    configure_firewall
    create_config
    test_installation
    print_summary
}

# Run main
main "$@"