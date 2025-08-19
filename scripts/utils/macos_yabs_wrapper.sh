#!/bin/bash

# macOS wrapper for YABS Extended
# Runs YABS Extended with macOS-specific adjustments

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Check if yabs_extended.sh exists
if [ -f "${PROJECT_ROOT}/yabs_extended.sh" ]; then
    # Set environment to indicate macOS
    export YABS_MACOS=1
    
    # Run yabs_extended.sh which should handle macOS compatibility
    bash "${PROJECT_ROOT}/yabs_extended.sh"
else
    # Fallback to basic macOS system info
    echo "# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #"
    echo "#              Yet-Another-Bench-Script              #"
    echo "#              (macOS Basic Mode)                    #"
    echo "# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #"
    echo
    
    # Get basic system info that works on macOS
    echo "Basic System Information:"
    echo "---------------------------------"
    echo "Uptime     : $(uptime | sed 's/.*up //' | sed 's/,.*//')"
    echo "Processor  : $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")"
    echo "CPU cores  : $(sysctl -n hw.ncpu 2>/dev/null || echo "Unknown")"
    echo "CPU threads: $(sysctl -n hw.logicalcpu 2>/dev/null || echo "Unknown")"
    echo "RAM        : $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 )) MB"
    echo "Swap       : $(sysctl -n vm.swapusage 2>/dev/null | awk '{print $3}' || echo "Unknown")"
    echo "Disk       : $(df -h / | awk 'NR==2 {print $2 " total, " $3 " used (" $5 ")"}')"
    echo "Kernel     : $(uname -r)"
    echo "OS         : $(sw_vers -productName) $(sw_vers -productVersion)"
    echo "Load       : $(uptime | awk -F'load average:' '{print $2}')"
    echo
    
    # Network info
    echo "Network Information:"
    echo "---------------------------------"
    
    # Get public IP info
    IP_INFO=$(curl -s https://ipinfo.io/json 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "Public IP  : $(echo "$IP_INFO" | grep -o '"ip":"[^"]*' | cut -d'"' -f4)"
        echo "ISP        : $(echo "$IP_INFO" | grep -o '"org":"[^"]*' | cut -d'"' -f4)"
        echo "Location   : $(echo "$IP_INFO" | grep -o '"city":"[^"]*' | cut -d'"' -f4), $(echo "$IP_INFO" | grep -o '"region":"[^"]*' | cut -d'"' -f4)"
        echo "Country    : $(echo "$IP_INFO" | grep -o '"country":"[^"]*' | cut -d'"' -f4)"
    fi
    echo
    
    # Run basic speed test with curl if available
    echo "Basic Speed Test:"
    echo "---------------------------------"
    if command -v curl >/dev/null 2>&1; then
        echo "Testing download speed..."
        SPEED=$(curl -o /dev/null -w '%{speed_download}' -s https://speed.cloudflare.com/__down?bytes=10000000 2>/dev/null)
        if [ $? -eq 0 ]; then
            SPEED_MB=$(echo "scale=2; $SPEED / 1024 / 1024" | bc)
            echo "Download Speed: ${SPEED_MB} MB/s"
        fi
    fi
    
    echo
    echo "Note: Full YABS Extended script not found."
    echo "For complete testing, ensure yabs_extended.sh is in the project root."
fi