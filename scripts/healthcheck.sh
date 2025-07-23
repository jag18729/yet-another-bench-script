#!/bin/bash

# YABS Health Check and Recovery Script
# Purpose: Monitor system health and auto-recover failed components

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YABS_DIR="/opt/yabs"
LOG_DIR="/var/log/yabs"
HEALTHCHECK_LOG="$LOG_DIR/healthcheck.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$HEALTHCHECK_LOG"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check and repair directory structure
check_directories() {
    log "Checking directory structure..."
    
    local dirs=(
        "$YABS_DIR"
        "$YABS_DIR/scripts"
        "$YABS_DIR/results"
        "$LOG_DIR"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log "Creating missing directory: $dir"
            mkdir -p "$dir"
        fi
    done
}

# Check and install missing dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    local deps=(
        "curl"
        "wget"
        "dig"
        "ping"
        "iperf3"
        "fio"
        "jq"
    )
    
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log "Missing dependencies: ${missing[*]}"
        
        # Attempt to install missing dependencies
        if command_exists apt-get; then
            log "Installing missing dependencies via apt-get..."
            apt-get update >/dev/null 2>&1
            apt-get install -y "${missing[@]}" >/dev/null 2>&1
        elif command_exists yum; then
            log "Installing missing dependencies via yum..."
            yum install -y "${missing[@]}" >/dev/null 2>&1
        elif command_exists brew; then
            log "Installing missing dependencies via brew..."
            for dep in "${missing[@]}"; do
                brew install "$dep" >/dev/null 2>&1
            done
        else
            log "WARNING: Package manager not found. Please install: ${missing[*]}"
        fi
    else
        log "All dependencies are installed"
    fi
}

# Check network connectivity
check_network() {
    log "Checking network connectivity..."
    
    # Test DNS resolution
    if ! dig +short google.com >/dev/null 2>&1; then
        log "WARNING: DNS resolution failed"
        # Try to restart network service
        if systemctl is-active NetworkManager >/dev/null 2>&1; then
            log "Restarting NetworkManager..."
            systemctl restart NetworkManager
        elif systemctl is-active systemd-networkd >/dev/null 2>&1; then
            log "Restarting systemd-networkd..."
            systemctl restart systemd-networkd
        fi
    fi
    
    # Test internet connectivity
    if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        log "WARNING: Internet connectivity check failed"
    else
        log "Network connectivity OK"
    fi
}

# Check disk space
check_disk_space() {
    log "Checking disk space..."
    
    local min_free_mb=500
    local free_space=$(df -m "$YABS_DIR" | awk 'NR==2 {print $4}')
    
    if [ "$free_space" -lt "$min_free_mb" ]; then
        log "WARNING: Low disk space: ${free_space}MB free"
        
        # Clean old results (older than 30 days)
        if [ -d "$YABS_DIR/results" ]; then
            log "Cleaning old results..."
            find "$YABS_DIR/results" -type f -mtime +30 -delete
        fi
        
        # Clean old logs (older than 30 days)
        if [ -d "$LOG_DIR" ]; then
            log "Cleaning old logs..."
            find "$LOG_DIR" -type f -name "*.log" -mtime +30 -delete
        fi
    else
        log "Disk space OK: ${free_space}MB free"
    fi
}

# Check systemd services
check_services() {
    log "Checking systemd services..."
    
    local services=(
        "yabs-monitor.timer"
        "yabs-healthcheck.timer"
    )
    
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            if ! systemctl is-active "$service" >/dev/null 2>&1; then
                log "Service $service is not active. Restarting..."
                systemctl restart "$service"
            else
                log "Service $service is active"
            fi
        else
            log "Service $service is not enabled"
        fi
    done
}

# Check and repair permissions
check_permissions() {
    log "Checking permissions..."
    
    # Ensure scripts are executable
    if [ -d "$YABS_DIR" ]; then
        find "$YABS_DIR" -name "*.sh" -type f -exec chmod +x {} \;
    fi
    
    # Ensure log directory is writable
    chmod 755 "$LOG_DIR"
}

# Main health check
main() {
    log "=== Starting YABS Health Check ==="
    
    check_directories
    check_dependencies
    check_network
    check_disk_space
    check_services
    check_permissions
    
    log "=== Health Check Complete ==="
    echo ""
}

# Run main function
main