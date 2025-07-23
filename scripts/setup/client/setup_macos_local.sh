#!/bin/bash

# macOS Local Setup Script for YABS Extended
# Purpose: Set up YABS testing environment locally on macOS without sudo

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

# Local directories (no sudo needed)
INSTALL_DIR="$HOME/.yabs"
LOG_DIR="$HOME/.yabs/logs"
RESULTS_DIR="$HOME/.yabs/results"

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

# Check for Homebrew
check_homebrew() {
    log "Checking for Homebrew..."
    if ! command -v brew >/dev/null 2>&1; then
        error "Homebrew is required. Please install from https://brew.sh"
    fi
    log "Homebrew found"
}

# Install dependencies via Homebrew
install_dependencies() {
    log "Installing/updating dependencies via Homebrew..."
    
    # Update Homebrew
    brew update
    
    # Core utilities
    brew install curl wget git jq bc coreutils gnu-sed
    
    # Network tools
    brew install iperf3
    brew install --cask wireshark || true  # Optional, may require password
    
    # DNS tools
    brew install bind  # provides dig
    
    # Storage benchmark
    brew install fio
    
    # Python and packages
    brew install python@3.11
    
    log "Dependencies installed"
}

# Create local directory structure
create_directories() {
    log "Creating directory structure..."
    
    mkdir -p "$INSTALL_DIR"/{scripts,bin}
    mkdir -p "$LOG_DIR"
    mkdir -p "$RESULTS_DIR"
    
    log "Directories created at $INSTALL_DIR"
}

# Copy scripts
install_scripts() {
    log "Installing scripts..."
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Copy main scripts
    cp "$script_dir/yabs.sh" "$INSTALL_DIR/" 2>/dev/null || warning "yabs.sh not found"
    cp "$script_dir/yabs_extended.sh" "$INSTALL_DIR/"
    # Copy core test scripts
    mkdir -p "$INSTALL_DIR/scripts/core"
    cp -r "$script_dir/scripts/core/"* "$INSTALL_DIR/scripts/core/" 2>/dev/null || true
    
    # Copy helper scripts
    mkdir -p "$INSTALL_DIR/scripts"
    if [ -d "$script_dir/scripts" ]; then
        cp -r "$script_dir/scripts"/* "$INSTALL_DIR/scripts/" 2>/dev/null || true
    fi
    
    # Copy Python scripts
    for script in process_results.py visualize_results.py; do
        if [ -f "$script_dir/$script" ]; then
            cp "$script_dir/$script" "$INSTALL_DIR/scripts/"
        fi
    done
    
    # Make all scripts executable
    chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true
    chmod +x "$INSTALL_DIR/scripts"/*.sh 2>/dev/null || true
    
    log "Scripts installed"
}

# Create wrapper scripts for easy access
create_wrappers() {
    log "Creating wrapper scripts..."
    
    # Create yabs-test command
    cat > "$INSTALL_DIR/yabs-test" <<'EOF'
#!/bin/bash
# YABS Test Wrapper
YABS_DIR="$HOME/.yabs"
cd "$YABS_DIR"
./yabs_extended.sh "$@"
EOF
    chmod +x "$INSTALL_DIR/yabs-test"
    
    # Create yabs-network command
    cat > "$INSTALL_DIR/yabs-network" <<'EOF'
#!/bin/bash
# YABS Network Test Wrapper
YABS_DIR="$HOME/.yabs"
cd "$YABS_DIR"
./scripts/core/network_performance_test.sh -t ping -d 8.8.8.8 "$@"
EOF
    chmod +x "$INSTALL_DIR/yabs-network"
    
    log "Wrapper scripts created"
}

# Create configuration
create_config() {
    log "Creating configuration..."
    
    cat > "$INSTALL_DIR/yabs.conf" <<EOF
# YABS Extended Configuration for macOS
# Generated on $(date)

# Directories
YABS_DIR="$INSTALL_DIR"
LOG_DIR="$LOG_DIR"
RESULTS_DIR="$RESULTS_DIR"

# Test settings
DEFAULT_PING_COUNT=20
DEFAULT_DNS_QUERIES=20
TRACEROUTE_MAX_HOPS=30

# Test targets
PING_TARGETS="8.8.8.8 1.1.1.1 9.9.9.9"
DNS_SERVERS="8.8.8.8 1.1.1.1 9.9.9.9"
TRACE_TARGETS="8.8.8.8 google.com"

# macOS specific
TRACEROUTE_CMD="traceroute"  # or "traceroute6" for IPv6
EOF
    
    log "Configuration created"
}

# Add to PATH
setup_path() {
    log "Setting up PATH..."
    
    local shell_rc=""
    if [[ $SHELL == *"zsh"* ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ $SHELL == *"bash"* ]]; then
        shell_rc="$HOME/.bash_profile"
    fi
    
    if [ -n "$shell_rc" ] && [ -f "$shell_rc" ]; then
        if ! grep -q "YABS_DIR" "$shell_rc"; then
            echo "" >> "$shell_rc"
            echo "# YABS Extended" >> "$shell_rc"
            echo "export PATH=\"\$HOME/.yabs:\$PATH\"" >> "$shell_rc"
            log "Added YABS to PATH in $shell_rc"
            log "Run 'source $shell_rc' to update current session"
        else
            log "YABS already in PATH"
        fi
    fi
}

# Test installation
test_installation() {
    log "Testing installation..."
    
    cd "$INSTALL_DIR"
    
    # Quick network test
    if [ -x "./scripts/core/network_performance_test.sh" ] && ./scripts/core/network_performance_test.sh -t ping -d 8.8.8.8 -c 5 -p test >/dev/null 2>&1; then
        log "Installation test passed"
    else
        warning "Test failed - checking dependencies..."
        which ping || warning "ping not found"
        which dig || warning "dig not found"
        which iperf3 || warning "iperf3 not found"
    fi
}

# Print summary
print_summary() {
    echo ""
    echo -e "${BLUE}=== YABS Extended macOS Installation Complete ===${NC}"
    echo ""
    echo "Installation directory: $INSTALL_DIR"
    echo "Log directory: $LOG_DIR"
    echo "Results directory: $RESULTS_DIR"
    echo ""
    echo "Usage:"
    echo "  yabs-test              # Run all tests"
    echo "  yabs-test -Y           # Run network tests only"
    echo "  yabs-test -p pre       # Run pre-change tests"
    echo "  yabs-network test      # Run network tests only"
    echo ""
    echo "View results:"
    echo "  ls -la $RESULTS_DIR"
    echo ""
    echo "Remote testing to Zorin VM:"
    echo "  ssh zorin0 'cd /opt/yabs && ./yabs_extended.sh -p test'"
    echo ""
    if [[ $SHELL == *"zsh"* ]]; then
        echo -e "${YELLOW}Run 'source ~/.zshrc' to update PATH${NC}"
    elif [[ $SHELL == *"bash"* ]]; then
        echo -e "${YELLOW}Run 'source ~/.bash_profile' to update PATH${NC}"
    fi
    echo ""
    echo -e "${GREEN}Setup complete!${NC}"
}

# Main
main() {
    echo -e "${BLUE}=== YABS Extended macOS Local Setup ===${NC}"
    echo ""
    
    check_homebrew
    install_dependencies
    create_directories
    install_scripts
    create_wrappers
    create_config
    setup_path
    test_installation
    print_summary
}

# Run main
main "$@"