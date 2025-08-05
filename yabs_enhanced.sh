#!/bin/bash

# Yet Another Bench Script - Enhanced Edition by Mason Rowe (Enhanced for macOS)
# Initial Oct 2019; Last update Jun 2024; Enhanced Jan 2025

# Disclaimer: This project is a work in progress. Any errors or suggestions should be
#             relayed to me via the GitHub project page linked below.
#
# Purpose:    The purpose of this script is to quickly gauge the performance of a Linux/macOS-
#             based server by benchmarking network performance via iperf3, CPU and
#             overall system performance via Geekbench 4/5/6, and random disk
#             performance via fio. The script is designed to not require any dependencies
#             - either compiled or installed - nor admin privileges to run.

YABS_VERSION="v2025-01-15-enhanced"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
ORANGE='\033[0;33m'
BLACK='\033[0;30m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Unicode symbols
CHECK_MARK="✓"
CROSS_MARK="✗"
ARROW="→"
BULLET="•"
STAR="★"
WARNING="⚠"
INFO="ℹ"
ROCKET="🚀"
GEAR="⚙"
CHART="📊"
CLOCK="🕐"
PACKAGE="📦"

# Spinner animation frames
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_PID=""

# Progress bar characters
PROGRESS_FILLED="▓"
PROGRESS_EMPTY="░"

# Function to start spinner
start_spinner() {
    local msg="$1"
    (
        while true; do
            for frame in "${SPINNER_FRAMES[@]}"; do
                echo -ne "\r${CYAN}${frame}${NC} ${msg}"
                sleep 0.1
            done
        done
    ) &
    SPINNER_PID=$!
}

# Function to stop spinner
stop_spinner() {
    if [[ ! -z "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
        echo -ne "\r\033[K"
    fi
}

# Function to print colored header
print_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}              ${BOLD}${CYAN}Yet-Another-Bench-Script${NC} ${ROCKET}                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                     ${DIM}$YABS_VERSION${NC}                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${DIM}https://github.com/masonr/yet-another-bench-script${NC}            ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
}

# Function to display Apple logo ASCII art
print_apple_logo() {
    echo -e "${GREEN}                 ###                  ${NC}"
    echo -e "${GREEN}               ####                   ${NC}"
    echo -e "${GREEN}               ###                    ${NC}"
    echo -e "${GREEN}       #######    #######             ${NC}"
    echo -e "${GREEN}     ######################           ${NC}"
    echo -e "${GREEN}    #####################             ${NC}"
    echo -e "${GREEN}    ####################              ${NC}"
    echo -e "${GREEN}    ####################              ${NC}"
    echo -e "${GREEN}    #####################             ${NC}"
    echo -e "${GREEN}     ######################           ${NC}"
    echo -e "${GREEN}      ####################            ${NC}"
    echo -e "${YELLOW}         ####     #####               ${NC}"
}

# Function to display Linux penguin ASCII art
print_linux_logo() {
    echo -e "${BOLD}${BLACK}       .-.                    ${NC}"
    echo -e "${BOLD}${BLACK}      (o o)                   ${NC}"
    echo -e "${BOLD}${BLACK}      | O \\                   ${NC}"
    echo -e "${BOLD}${BLACK}     /  \\  \\                  ${NC}"
    echo -e "${BOLD}${BLACK}    /____\\__\\                 ${NC}"
    echo -e "${BOLD}${BLACK}   (______)____)               ${NC}"
    echo -e "${YELLOW}    |  | |  |                 ${NC}"
    echo -e "${YELLOW}    |__| |__|                 ${NC}"
    echo -e "${YELLOW}   /    \\    \\                ${NC}"
}

# format_size
# Purpose: Formats raw disk and memory sizes from kibibytes (KiB) to largest unit
# Parameters:
#          1. RAW - the raw memory size (RAM/Swap) in kibibytes
# Returns:
#          Formatted memory size in KiB, MiB, GiB, or TiB
function format_size {
	RAW=$1 # mem size in KiB
	RESULT=$RAW
	local DENOM=1
	local UNIT="KiB"

	# ensure the raw value is a number, otherwise return blank
	re='^[0-9]+$'
	if ! [[ $RAW =~ $re ]] ; then
		echo "" 
		return 0
	fi

	if [ "$RAW" -ge 1073741824 ]; then
		DENOM=1073741824
		UNIT="TiB"
	elif [ "$RAW" -ge 1048576 ]; then
		DENOM=1048576
		UNIT="GiB"
	elif [ "$RAW" -ge 1024 ]; then
		DENOM=1024
		UNIT="MiB"
	fi

	# divide the raw result to get the corresponding formatted result (based on determined unit)
	RESULT=$(awk -v a="$RESULT" -v b="$DENOM" 'BEGIN { print a / b }')
	# if the result is a decimal, show two places after the decimal
	if [[ $RESULT == *"."* ]]; then
		RESULT=$(echo "$RESULT" | awk -F. '{ printf "%d.%02d", $1, substr($2, 1, 2) }')
	fi

	echo "$RESULT $UNIT"
}

# Function to get WiFi signal information on macOS
function get_wifi_signal_macos() {
	local output=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport -I 2>/dev/null) 
	local airport=$(echo $output | grep 'AirPort' | awk -F': ' '{print $2}')

	if [ "$airport" = "Off" ]; then
		echo "${YELLOW}WiFi Off${NC}"
	else
		local ssid=$(echo $output | grep ' SSID' | awk -F': ' '{print $2}')
		local speed=$(echo $output | grep 'lastTxRate' | awk -F': ' '{print $2}')
		local signal=$(echo $output | grep 'agrCtlRSSI' | awk -F': ' '{print $2}')
		
		if [[ -n "$ssid" && -n "$speed" ]]; then
			local color="${YELLOW}"
			[[ $speed -gt 100 ]] && color="${GREEN}"
			[[ $speed -lt 50 ]] && color="${RED}"
			
			local signal_info=""
			if [[ -n "$signal" ]]; then
				signal_info=" (${signal}dBm)"
			fi
			
			echo "${color}${ssid} ${speed}Mbps${signal_info}${NC}"
		else
			echo "${YELLOW}Connected${NC}"
		fi
	fi
}

# Enhanced system information gathering for macOS
function gather_system_info_macos() {
	# CPU information - enhanced for Apple Silicon
	CPU_PROC=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
	
	# For Apple Silicon, get more detailed chip info
	if [[ "$CPU_PROC" == *"Apple"* ]]; then
		# Get chip model from system_profiler
		CHIP_INFO=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Chip:" | sed 's/.*Chip: //')
		if [[ ! -z "$CHIP_INFO" ]]; then
			CPU_PROC="$CHIP_INFO"
		fi
		
		# Get performance and efficiency core counts
		PERF_CORES=$(sysctl -n hw.perflevel0.logicalcpu 2>/dev/null || "0")
		EFF_CORES=$(sysctl -n hw.perflevel1.logicalcpu 2>/dev/null || "0")
		if [[ "$PERF_CORES" != "0" && "$EFF_CORES" != "0" ]]; then
			CPU_CORES="$PERF_CORES P-cores + $EFF_CORES E-cores"
		else
			CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo "Unknown")
		fi
		
		# Apple Silicon doesn't report frequency traditionally
		CPU_FREQ="Dynamic (Apple Silicon)"
		
		# Check for Neural Engine
		NEURAL_ENGINE="Present"
	else
		# Intel Mac
		CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo "Unknown")
		CPU_FREQ=$(sysctl -n hw.cpufrequency_max 2>/dev/null | awk '{printf "%.0f MHz", $1/1000000}' || echo "Unknown")
		NEURAL_ENGINE="N/A"
	fi
	
	# Memory information
	TOTAL_RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null)
	TOTAL_RAM_RAW=$((TOTAL_RAM_BYTES / 1024))
	TOTAL_RAM=$(format_size $TOTAL_RAM_RAW)
	
	# For Apple Silicon, check if unified memory
	if [[ "$CPU_PROC" == *"Apple"* ]]; then
		MEMORY_TYPE="Unified Memory"
	else
		MEMORY_TYPE="RAM"
	fi
	
	# Swap information (macOS reports differently)
	SWAP_INFO=$(sysctl -n vm.swapusage 2>/dev/null | grep -o 'total = [0-9.]*[MG]' | awk '{print $3}')
	if [[ "$SWAP_INFO" == *"G"* ]]; then
		TOTAL_SWAP="${SWAP_INFO%G} GiB"
		TOTAL_SWAP_RAW=$(echo "${SWAP_INFO%G} * 1048576" | bc 2>/dev/null || echo "$((${SWAP_INFO%G%%.*} * 1048576))")
	elif [[ "$SWAP_INFO" == *"M"* ]]; then
		TOTAL_SWAP="${SWAP_INFO%M} MiB"
		TOTAL_SWAP_RAW=$(echo "${SWAP_INFO%M} * 1024" | bc 2>/dev/null || echo "$((${SWAP_INFO%M%%.*} * 1024))")
	else
		TOTAL_SWAP="0 MiB"
		TOTAL_SWAP_RAW=0
	fi
	
	# Disk information
	TOTAL_DISK_RAW=$(df -k / | awk 'NR==2 {print $2}')
	TOTAL_DISK=$(format_size $TOTAL_DISK_RAW)
	
	# Virtualization detection for macOS
	if [[ $(sysctl -n kern.hv_vmm_present 2>/dev/null) == "1" ]]; then
		VIRT="VM"
	elif [[ $(sysctl -n sysctl.proc_translated 2>/dev/null) == "1" ]]; then
		VIRT="Rosetta 2"
	else
		VIRT="BARE-METAL"
	fi
	
	# Get macOS codename
	MACOS_VERSION=$(sw_vers -productVersion)
	case "${MACOS_VERSION%%.*}" in
		15) MACOS_CODENAME="Sequoia" ;;
		14) MACOS_CODENAME="Sonoma" ;;
		13) MACOS_CODENAME="Ventura" ;;
		12) MACOS_CODENAME="Monterey" ;;
		11) MACOS_CODENAME="Big Sur" ;;
		*) MACOS_CODENAME="" ;;
	esac
	
	if [[ ! -z "$MACOS_CODENAME" ]]; then
		DISTRO="$OS_NAME $OS_VERSION $MACOS_CODENAME ($OS_BUILD)"
	fi
}

# Function to display system info in Archey style
print_system_banner() {
    local logo_lines=12
    local info_array=()
    
    # Prepare system information
    detect_os
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        gather_system_info_macos
        # Get battery info if available
        BATTERY=$(pmset -g batt 2>/dev/null | grep -Eo "[0-9]+%" | head -1 || echo "N/A")
    else
        # Linux system info
        CPU_PROC=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' || echo "Unknown")
        TOTAL_RAM=$(free -h | awk 'NR==2 {print $2}' || echo "Unknown")
        BATTERY="N/A"
    fi
    
    # Get disk usage
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' || echo "Unknown")
    
    # Build info array
    info_array+=( "${CYAN}User:${NC} $(whoami)" )
    info_array+=( "${CYAN}Hostname:${NC} $(hostname -s)" )
    info_array+=( "${CYAN}Distro:${NC} ${DISTRO}" )
    info_array+=( "${CYAN}Kernel:${NC} $(uname -r)" )
    info_array+=( "${CYAN}Uptime:${NC} ${UPTIME}" )
    info_array+=( "${CYAN}Shell:${NC} $SHELL" )
    info_array+=( "${CYAN}Terminal:${NC} ${TERM:-Unknown}" )
    info_array+=( "${CYAN}CPU:${NC} ${CPU_PROC}" )
    if [[ "$OSTYPE" == "darwin"* && ! -z "$MEMORY_TYPE" ]]; then
        info_array+=( "${CYAN}Memory:${NC} ${TOTAL_RAM} (${MEMORY_TYPE})" )
    else
        info_array+=( "${CYAN}Memory:${NC} ${TOTAL_RAM}" )
    fi
    info_array+=( "${CYAN}Disk:${NC} ${DISK_USAGE} used" )
    [[ "$BATTERY" != "N/A" ]] && info_array+=( "${CYAN}Battery:${NC} ${BATTERY}" )
    
    # Print info without logo
    echo
    echo
}

# Function to print section header
print_section() {
    local title="$1"
    local icon="$2"
    echo -e "\n${BOLD}${MAGENTA}${icon} ${title}${NC}"
    echo -e "${MAGENTA}$(printf '─%.0s' {1..60})${NC}"
}

# Function to print status
print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        "success")
            echo -e "${GREEN}${CHECK_MARK}${NC} ${message}"
            ;;
        "error")
            echo -e "${RED}${CROSS_MARK}${NC} ${message}"
            ;;
        "warning")
            echo -e "${YELLOW}${WARNING}${NC} ${message}"
            ;;
        "info")
            echo -e "${CYAN}${INFO}${NC} ${message}"
            ;;
        *)
            echo -e "${ARROW} ${message}"
            ;;
    esac
}

# Function to display a progress bar
print_progress() {
    local current=$1
    local total=$2
    local width=${3:-50}
    local label=${4:-"Progress"}
    
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    # Build the progress bar
    printf "\r${CYAN}%-15s${NC} [" "$label"
    
    # Print filled portion
    if [ $filled -gt 0 ]; then
        printf "${GREEN}"
        for ((i=0; i<filled; i++)); do
            printf "▓"
        done
        printf "${NC}"
    fi
    
    # Print empty portion
    if [ $empty -gt 0 ]; then
        printf "${DIM}"
        for ((i=0; i<empty; i++)); do
            printf "░"
        done
        printf "${NC}"
    fi
    
    printf "] ${BOLD}%3d%%${NC}" $percentage
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Function to display animated transition
animated_transition() {
    local message="$1"
    local chars=("◐" "◓" "◑" "◒")
    
    for i in {1..8}; do
        echo -ne "\r${CYAN}${chars[$((i % 4))]}${NC} ${message}"
        sleep 0.1
    done
    echo -ne "\r${GREEN}${CHECK_MARK}${NC} ${message}\n"
}

# Enhanced OS detection function
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="macOS"
        OS_VERSION=$(sw_vers -productVersion)
        OS_BUILD=$(sw_vers -buildVersion)
        OS_NAME=$(sw_vers -productName)
        DISTRO="$OS_NAME $OS_VERSION ($OS_BUILD)"
    elif [[ -f /etc/os-release ]]; then
        OS_TYPE="Linux"
        DISTRO=$(grep 'PRETTY_NAME' /etc/os-release | cut -d '"' -f 2)
    else
        OS_TYPE="Unknown"
        DISTRO="Unknown OS"
    fi
}

# Cool animated intro
if [[ -t 1 ]]; then  # Check if running in terminal
    # Clear screen for dramatic effect
    clear
    
    # Animated intro text
    intro_text="YABS - Yet Another Bench Script"
    for (( i=0; i<${#intro_text}; i++ )); do
        echo -ne "${BOLD}${CYAN}${intro_text:$i:1}${NC}"
        sleep 0.03
    done
    echo
    sleep 0.5
    clear
fi

print_header

# First, gather basic system info for the banner
detect_os

# Get uptime early for banner
if [[ "$OSTYPE" == "darwin"* ]]; then
	# More robust uptime parsing for macOS
	UPTIME_RAW=$(uptime)
	if [[ "$UPTIME_RAW" =~ "day" ]]; then
		DAYS=$(echo "$UPTIME_RAW" | sed -E 's/.*up ([0-9]+) day.*/\1/')
		TIME_PART=$(echo "$UPTIME_RAW" | sed -E 's/.*day[s]?, *([0-9]+:[0-9]+).*/\1/')
		UPTIME="$DAYS days, $TIME_PART"
	elif [[ "$UPTIME_RAW" =~ "min" ]]; then
		MINS=$(echo "$UPTIME_RAW" | sed -E 's/.*up ([0-9]+) min.*/\1/')
		UPTIME="$MINS minutes"
	else
		TIME_PART=$(echo "$UPTIME_RAW" | sed -E 's/.*up *([0-9]+:[0-9]+).*/\1/')
		UPTIME="$TIME_PART"
	fi
else
	UPTIME=$(uptime | awk -F'( |,|:)+' '{d=h=m=0; if ($7=="min") m=$6; else {if ($7~/^day/) {d=$6;h=$8;m=$9} else {h=$6;m=$7}}} {print d+0,"days,",h+0,"hours,",m+0,"minutes"}')
fi

# Display the cool system banner with animation
if [[ -t 1 ]]; then  # Check if running in terminal
    animated_transition "Loading system information..."
    sleep 0.5
fi

print_system_banner

echo -e
echo -e "${DIM}$(date)${NC}"
TIME_START=$(date '+%Y%m%d-%H%M%S')
YABS_START_TIME=$(date +%s)

# Show a cool divider
echo -e "${BLUE}$(printf '═%.0s' {1..64})${NC}"

# override locale to eliminate parsing errors (i.e. using commas as delimiters rather than periods)
if locale -a 2>/dev/null | grep ^C$ > /dev/null; then
	# locale "C" installed
	export LC_ALL=C
else
	# locale "C" not installed, display warning
	print_status "warning" "Locale 'C' not detected. Test outputs may not be parsed correctly."
fi

# determine architecture of host
ARCH=$(uname -m)
if [[ $ARCH = *x86_64* ]]; then
	# host is running a 64-bit kernel
	ARCH="x64"
elif [[ $ARCH = *i?86* ]]; then
	# host is running a 32-bit kernel
	ARCH="x86"
elif [[ $ARCH = *aarch* || $ARCH = *arm* ]]; then
	KERNEL_BIT=$(getconf LONG_BIT)
	if [[ $KERNEL_BIT = *64* ]]; then
		# host is running an ARM 64-bit kernel
		ARCH="aarch64"
	else
		# host is running an ARM 32-bit kernel
		ARCH="arm"
	fi
	if [[ "$OSTYPE" == "darwin"* ]]; then
		print_status "info" "Apple Silicon detected (experimental support)"
	else
		print_status "warning" "ARM compatibility is considered experimental"
	fi
else
	# host is running a non-supported kernel
	print_status "error" "Architecture not supported by YABS."
	exit 1
fi

# flags to skip certain performance tests
unset PREFER_BIN SKIP_FIO SKIP_IPERF SKIP_GEEKBENCH SKIP_NET PRINT_HELP REDUCE_NET GEEKBENCH_4 GEEKBENCH_5 GEEKBENCH_6 DD_FALLBACK IPERF_DL_FAIL JSON JSON_SEND JSON_RESULT JSON_FILE
GEEKBENCH_6="True" # gb6 test enabled by default

# get any arguments that were passed to the script and set the associated skip flags (if applicable)
while getopts 'bfdignhr4596jw:s:' flag; do
	case "${flag}" in
		b) PREFER_BIN="True" ;;
		f) SKIP_FIO="True" ;;
		d) SKIP_FIO="True" ;;
		i) SKIP_IPERF="True" ;;
		g) SKIP_GEEKBENCH="True" ;;
		n) SKIP_NET="True" ;;
		h) PRINT_HELP="True" ;;
		r) REDUCE_NET="True" ;;
		4) GEEKBENCH_4="True" && unset GEEKBENCH_6 ;;
		5) GEEKBENCH_5="True" && unset GEEKBENCH_6 ;;
		9) GEEKBENCH_4="True" && GEEKBENCH_5="True" && unset GEEKBENCH_6 ;;
		6) GEEKBENCH_6="True" ;;
		j) JSON+="j" ;; 
		w) JSON+="w" && JSON_FILE=${OPTARG} ;;
		s) JSON+="s" && JSON_SEND=${OPTARG} ;; 
		*) exit 1 ;;
	esac
done

# check for local fio/iperf installs
command -v fio >/dev/null 2>&1 && LOCAL_FIO=true || unset LOCAL_FIO
command -v iperf3 >/dev/null 2>&1 && LOCAL_IPERF=true || unset LOCAL_IPERF

# check for ping
command -v ping >/dev/null 2>&1 && LOCAL_PING=true || unset LOCAL_PING

# check for curl/wget
command -v curl >/dev/null 2>&1 && LOCAL_CURL=true || unset LOCAL_CURL

# test if the host has IPv4/IPv6 connectivity
start_spinner "Checking network connectivity..."
[[ ! -z $LOCAL_CURL ]] && IP_CHECK_CMD="curl -s -m 4" || IP_CHECK_CMD="wget -qO- -T 4"
IPV4_CHECK=$( (ping -4 -c 1 -W 4 ipv4.google.com >/dev/null 2>&1 && echo true) || $IP_CHECK_CMD -4 icanhazip.com 2> /dev/null)
IPV6_CHECK=$( (ping -6 -c 1 -W 4 ipv6.google.com >/dev/null 2>&1 && echo true) || $IP_CHECK_CMD -6 icanhazip.com 2> /dev/null)
stop_spinner

if [[ -z "$IPV4_CHECK" && -z "$IPV6_CHECK" ]]; then
	print_status "error" "Both IPv4 AND IPv6 connectivity were not detected. Check for DNS issues..."
fi

# print help and exit script, if help flag was passed
if [ ! -z "$PRINT_HELP" ]; then
	print_section "Usage & Help" "$INFO"
	echo -e "${CYAN}Usage:${NC} ./yabs_enhanced.sh [-flags]"
	echo -e "       curl -sL yabs.sh | bash"
	echo -e "       curl -sL yabs.sh | bash -s -- -flags"
	echo -e "       wget -qO- yabs.sh | bash"
	echo -e "       wget -qO- yabs.sh | bash -s -- -flags"
	echo -e
	echo -e "${CYAN}Flags:${NC}"
	echo -e "  ${GREEN}-b${NC} : prefer pre-compiled binaries from repo over local packages"
	echo -e "  ${GREEN}-f/d${NC} : skips the fio disk benchmark test"
	echo -e "  ${GREEN}-i${NC} : skips the iperf network test"
	echo -e "  ${GREEN}-g${NC} : skips the geekbench performance test"
	echo -e "  ${GREEN}-n${NC} : skips the network information lookup and print out"
	echo -e "  ${GREEN}-h${NC} : prints this lovely message"
	echo -e "  ${GREEN}-r${NC} : reduce number of iperf3 network locations"
	echo -e "  ${GREEN}-4${NC} : use geekbench 4 instead of geekbench 6"
	echo -e "  ${GREEN}-5${NC} : use geekbench 5 instead of geekbench 6"
	echo -e "  ${GREEN}-9${NC} : use both geekbench 4 AND geekbench 5"
	echo -e "  ${GREEN}-6${NC} : use geekbench 6 in addition to 4 and/or 5"
	echo -e "  ${GREEN}-j${NC} : print jsonified YABS results"
	echo -e "  ${GREEN}-w${NC} <file> : write jsonified results to file"
	echo -e "  ${GREEN}-s${NC} <url> : send jsonified results to URL"
	echo -e
	print_section "System Detection" "$GEAR"
	echo -e "${CYAN}Detected Arch:${NC} $ARCH"
	detect_os
	echo -e "${CYAN}Detected OS:${NC} $OS_TYPE"
	echo -e "${CYAN}Detected Distro:${NC} $DISTRO"
	echo -e
	print_section "Detected Flags" "$PACKAGE"
	[[ ! -z $PREFER_BIN ]] && echo -e "  ${BULLET} Force using precompiled binaries"
	[[ ! -z $SKIP_FIO ]] && echo -e "  ${BULLET} Skipping fio disk benchmark"
	[[ ! -z $SKIP_IPERF ]] && echo -e "  ${BULLET} Skipping iperf network test"
	[[ ! -z $SKIP_GEEKBENCH ]] && echo -e "  ${BULLET} Skipping geekbench test"
	[[ ! -z $SKIP_NET ]] && echo -e "  ${BULLET} Skipping network info lookup"
	[[ ! -z $REDUCE_NET ]] && echo -e "  ${BULLET} Using reduced iperf3 locations"
	[[ ! -z $GEEKBENCH_4 ]] && echo -e "  ${BULLET} Running Geekbench 4"
	[[ ! -z $GEEKBENCH_5 ]] && echo -e "  ${BULLET} Running Geekbench 5"
	[[ ! -z $GEEKBENCH_6 ]] && echo -e "  ${BULLET} Running Geekbench 6"
	echo -e
	print_section "Local Binary Check" "$PACKAGE"
	[[ -z $LOCAL_FIO ]] && echo -e "  ${BULLET} fio: ${RED}not detected${NC} (will download)" || \
		[[ -z $PREFER_BIN ]] && echo -e "  ${BULLET} fio: ${GREEN}detected${NC} (using local)" || \
		echo -e "  ${BULLET} fio: ${YELLOW}detected${NC} (using binary anyway)"
	[[ -z $LOCAL_IPERF ]] && echo -e "  ${BULLET} iperf3: ${RED}not detected${NC} (will download)" || \
		[[ -z $PREFER_BIN ]] && echo -e "  ${BULLET} iperf3: ${GREEN}detected${NC} (using local)" || \
		echo -e "  ${BULLET} iperf3: ${YELLOW}detected${NC} (using binary anyway)"
	echo -e
	print_section "Network Connectivity" "$ROCKET"
	[[ ! -z $IPV4_CHECK ]] && echo -e "  ${BULLET} IPv4: ${GREEN}${CHECK_MARK} Connected${NC}" || \
		echo -e "  ${BULLET} IPv4: ${RED}${CROSS_MARK} Not connected${NC}"
	[[ ! -z $IPV6_CHECK ]] && echo -e "  ${BULLET} IPv6: ${GREEN}${CHECK_MARK} Connected${NC}" || \
		echo -e "  ${BULLET} IPv6: ${RED}${CROSS_MARK} Not connected${NC}"
	
	if [[ ! -z $JSON ]]; then
		echo -e
		print_section "JSON Options" "$CHART"
		[[ $JSON = *j* ]] && echo -e "  ${BULLET} Print JSON to screen"
		[[ $JSON = *w* ]] && echo -e "  ${BULLET} Write JSON to: ${CYAN}$JSON_FILE${NC}"
		[[ $JSON = *s* ]] && echo -e "  ${BULLET} Send JSON to: ${CYAN}$JSON_SEND${NC}"
	fi
	echo -e
	print_status "info" "Exiting..."
	exit 0
fi

# format_size
# Purpose: Formats raw disk and memory sizes from kibibytes (KiB) to largest unit
# Parameters:
#          1. RAW - the raw memory size (RAM/Swap) in kibibytes
# Returns:
#          Formatted memory size in KiB, MiB, GiB, or TiB
function format_size {
	RAW=$1 # mem size in KiB
	RESULT=$RAW
	local DENOM=1
	local UNIT="KiB"

	# ensure the raw value is a number, otherwise return blank
	re='^[0-9]+$'
	if ! [[ $RAW =~ $re ]] ; then
		echo "" 
		return 0
	fi

	if [ "$RAW" -ge 1073741824 ]; then
		DENOM=1073741824
		UNIT="TiB"
	elif [ "$RAW" -ge 1048576 ]; then
		DENOM=1048576
		UNIT="GiB"
	elif [ "$RAW" -ge 1024 ]; then
		DENOM=1024
		UNIT="MiB"
	fi

	# divide the raw result to get the corresponding formatted result (based on determined unit)
	RESULT=$(awk -v a="$RESULT" -v b="$DENOM" 'BEGIN { print a / b }')
	# shorten the formatted result to two decimal places (i.e. x.x)
	RESULT=$(echo $RESULT | awk -F. '{ printf "%0.1f",$1"."substr($2,1,2) }')
	# concat formatted result value with units and return result
	RESULT="$RESULT $UNIT"
	echo $RESULT
}

# gather basic system information (inc. CPU, AES-NI/virt status, RAM + swap + disk size)
animated_transition "Gathering system details..."
print_section "Basic System Information" "$INFO"

# Uptime was already calculated for the banner
printf "${CYAN}%-15s${NC}: %s\n" "Uptime" "$UPTIME"

# Gather system info based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
	gather_system_info_macos
else
	# Linux system info gathering (original code)
	command -v lscpu >/dev/null 2>&1 && LOCAL_LSCPU=true || unset LOCAL_LSCPU
	if [[ $ARCH = *aarch64* || $ARCH = *arm* ]] && [[ ! -z $LOCAL_LSCPU ]]; then
		CPU_PROC=$(lscpu | grep "Model name" | sed 's/Model name: *//g')
	else
		CPU_PROC=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
	fi
	
	if [[ $ARCH = *aarch64* || $ARCH = *arm* ]] && [[ ! -z $LOCAL_LSCPU ]]; then
		CPU_CORES=$(lscpu | grep "^[[:blank:]]*CPU(s):" | sed 's/CPU(s): *//g')
		CPU_FREQ=$(lscpu | grep "CPU max MHz" | sed 's/CPU max MHz: *//g')
		[[ -z "$CPU_FREQ" ]] && CPU_FREQ="???"
		CPU_FREQ="${CPU_FREQ} MHz"
	else
		CPU_CORES=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
		CPU_FREQ=$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq " MHz"}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
	fi
	
	TOTAL_RAM_RAW=$(free | awk 'NR==2 {print $2}')
	TOTAL_RAM=$(format_size $TOTAL_RAM_RAW)
	TOTAL_SWAP_RAW=$(free | grep Swap | awk '{ print $2 }')
	TOTAL_SWAP=$(format_size $TOTAL_SWAP_RAW)
	# total disk size is calculated by adding all partitions of the types listed below (after the -t flags)
	TOTAL_DISK_RAW=$(df -t simfs -t ext2 -t ext3 -t ext4 -t btrfs -t xfs -t vfat -t ntfs -t swap --total 2>/dev/null | grep total | awk '{ print $2 }')
	TOTAL_DISK=$(format_size $TOTAL_DISK_RAW)
	VIRT=$(systemd-detect-virt 2>/dev/null)
	VIRT=${VIRT^^} || VIRT="UNKNOWN"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
	printf "${CYAN}%-15s${NC}: %s\n" "Chip Model" "$CPU_PROC"
	printf "${CYAN}%-15s${NC}: %s\n" "CPU Config" "$CPU_CORES"
	if [[ ! -z "$NEURAL_ENGINE" && "$NEURAL_ENGINE" != "N/A" ]]; then
		printf "${CYAN}%-15s${NC}: ${GREEN}${CHECK_MARK} %s${NC}\n" "Neural Eng" "$NEURAL_ENGINE"
	fi
else
	printf "${CYAN}%-15s${NC}: %s\n" "Processor" "$CPU_PROC"
	printf "${CYAN}%-15s${NC}: %s @ %s\n" "CPU cores" "$CPU_CORES" "$CPU_FREQ"
fi

# AES-NI detection
if [[ "$OSTYPE" == "darwin"* ]]; then
	if [[ "$CPU_PROC" == *"Apple"* ]]; then
		# Apple Silicon has AES acceleration built-in
		CPU_AES="${GREEN}${CHECK_MARK} Hardware Accelerated${NC}"
	else
		CPU_AES=$(sysctl -n hw.optional.aes 2>/dev/null)
		[[ "$CPU_AES" == "1" ]] && CPU_AES="${GREEN}${CHECK_MARK} Enabled${NC}" || CPU_AES="${RED}${CROSS_MARK} Disabled${NC}"
	fi
else
	CPU_AES=$(cat /proc/cpuinfo | grep aes)
	[[ -z "$CPU_AES" ]] && CPU_AES="${RED}${CROSS_MARK} Disabled${NC}" || CPU_AES="${GREEN}${CHECK_MARK} Enabled${NC}"
fi
printf "${CYAN}%-15s${NC}: %b\n" "AES-NI" "$CPU_AES"

# Virtualization detection
if [[ "$OSTYPE" == "darwin"* ]]; then
	# macOS doesn't have /proc/cpuinfo, check for hypervisor
	if [[ $(sysctl -n kern.hv_vmm_present 2>/dev/null) == "1" ]]; then
		CPU_VIRT="${GREEN}${CHECK_MARK} Enabled${NC}"
	else
		CPU_VIRT="${YELLOW}${WARNING} N/A${NC}"
	fi
else
	CPU_VIRT=$(cat /proc/cpuinfo | grep 'vmx\|svm')
	[[ -z "$CPU_VIRT" ]] && CPU_VIRT="${RED}${CROSS_MARK} Disabled${NC}" || CPU_VIRT="${GREEN}${CHECK_MARK} Enabled${NC}"
fi
printf "${CYAN}%-15s${NC}: %b\n" "VM-x/AMD-V" "$CPU_VIRT"

if [[ "$OSTYPE" == "darwin"* && ! -z "$MEMORY_TYPE" ]]; then
	printf "${CYAN}%-15s${NC}: %s\n" "$MEMORY_TYPE" "$TOTAL_RAM"
else
	printf "${CYAN}%-15s${NC}: %s\n" "RAM" "$TOTAL_RAM"
fi
printf "${CYAN}%-15s${NC}: %s\n" "Swap" "$TOTAL_SWAP"
printf "${CYAN}%-15s${NC}: %s\n" "Disk" "$TOTAL_DISK"
printf "${CYAN}%-15s${NC}: %s\n" "Distro" "$DISTRO"
KERNEL=$(uname -r)
printf "${CYAN}%-15s${NC}: %s\n" "Kernel" "$KERNEL"
printf "${CYAN}%-15s${NC}: %s\n" "VM Type" "$VIRT"
[[ -z "$IPV4_CHECK" ]] && ONLINE="${RED}${CROSS_MARK} Offline${NC} / " || ONLINE="${GREEN}${CHECK_MARK} Online${NC} / "
[[ -z "$IPV6_CHECK" ]] && ONLINE+="${RED}${CROSS_MARK} Offline${NC}" || ONLINE+="${GREEN}${CHECK_MARK} Online${NC}"
printf "${CYAN}%-15s${NC}: %b\n" "IPv4/IPv6" "$ONLINE"

# Add WiFi signal information for macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
	WIFI_SIGNAL=$(get_wifi_signal_macos)
	if [[ -n "$WIFI_SIGNAL" ]]; then
		printf "${CYAN}%-15s${NC}: %b\n" "WiFi Signal" "$WIFI_SIGNAL"
	fi
fi

# Function to get information from IP Address using ip-api.com free API
function ip_info() {
	# check for curl vs wget
	[[ ! -z $LOCAL_CURL ]] && DL_CMD="curl -s" || DL_CMD="wget -qO-"

	local ip6me_resp="$($DL_CMD http://ip6.me/api/)"
	local net_type="$(echo $ip6me_resp | cut -d, -f1)"
	local net_ip="$(echo $ip6me_resp | cut -d, -f2)"

	local response=$($DL_CMD http://ip-api.com/json/$net_ip)

	# if no response, skip output
	if [[ -z $response ]]; then
		return
	fi

	local country=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^country/ {print $2}' | head -1 | sed 's/^"\(.*\)"$/\1/')
	local region=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^regionName/ {print $2}' | sed 's/^"\(.*\)"$/\1/')
	local region_code=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^region/ {print $2}' | head -1 | sed 's/^"\(.*\)"$/\1/')
	local city=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^city/ {print $2}' | sed 's/^"\(.*\)"$/\1/')
	local isp=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^isp/ {print $2}' | sed 's/^"\(.*\)"$/\1/')
	local org=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^org/ {print $2}' | sed 's/^"\(.*\)"$/\1/')
	local as=$(echo "$response" | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/^as/ {print $2}' | sed 's/^"\(.*\)"$/\1/')
	
	print_section "$net_type Network Information" "$ROCKET"

	if [[ -n "$isp" ]]; then
		printf "${CYAN}%-15s${NC}: %s\n" "ISP" "$isp"
	else
		printf "${CYAN}%-15s${NC}: %s\n" "ISP" "Unknown"
	fi
	if [[ -n "$as" ]]; then
		printf "${CYAN}%-15s${NC}: %s\n" "ASN" "$as"
	else
		printf "${CYAN}%-15s${NC}: %s\n" "ASN" "Unknown"
	fi
	if [[ -n "$org" ]]; then
		printf "${CYAN}%-15s${NC}: %s\n" "Host" "$org"
	fi
	if [[ -n "$city" && -n "$region" ]]; then
		printf "${CYAN}%-15s${NC}: %s, %s (%s)\n" "Location" "$city" "$region" "$region_code"
	fi
	if [[ -n "$country" ]]; then
		printf "${CYAN}%-15s${NC}: %s\n" "Country" "$country"
	fi 

	[[ ! -z $JSON ]] && JSON_RESULT+=',\"ip_info\":{\"protocol\":\"'$net_type'\",\"isp\":\"'$isp'\",\"asn\":\"'$as'\",\"org\":\"'$org'\",\"city\":\"'$city'\",\"region\":\"'$region'\",\"region_code\":\"'$region_code'\",\"country\":\"'$country'\"}'
}

if [ ! -z $JSON ]; then
	UPTIME_S=$(awk '{print $1}' /proc/uptime 2>/dev/null || echo "0")
	IPV4=$([ ! -z $IPV4_CHECK ] && echo "true" || echo "false")
	IPV6=$([ ! -z $IPV6_CHECK ] && echo "true" || echo "false")
	AES=$([[ "$CPU_AES" = *Enabled* ]] && echo "true" || echo "false")
	CPU_VIRT_BOOL=$([[ "$CPU_VIRT" = *Enabled* ]] && echo "true" || echo "false")
	JSON_RESULT='{"version":"'$YABS_VERSION'","time":"'$TIME_START'","os":{"arch":"'$ARCH'","distro":"'$DISTRO'","kernel":"'$KERNEL'",'
	JSON_RESULT+='"uptime":'$UPTIME_S',"vm":"'$VIRT'"},"net":{"ipv4":'$IPV4',"ipv6":'$IPV6'},"cpu":{"model":"'$CPU_PROC'","cores":'$CPU_CORES','
	JSON_RESULT+='"freq":"'$CPU_FREQ'","aes":'$AES',"virt":'$CPU_VIRT_BOOL'},"mem":{"ram":'$TOTAL_RAM_RAW',"ram_units":"KiB","swap":'${TOTAL_SWAP_RAW:-0}',"swap_units":"KiB","disk":'$TOTAL_DISK_RAW',"disk_units":"KB"}'
fi

if [ -z $SKIP_NET ]; then
	start_spinner "Gathering network information..."
	ip_info
	stop_spinner
fi

# create a directory in the same location that the script is being run to temporarily store YABS-related files
DATE=$(date -Iseconds | sed -e "s/:/_/g")
YABS_PATH=./$DATE
touch "$DATE.test" 2> /dev/null
# test if the user has write permissions in the current directory and exit if not
if [ ! -f "$DATE.test" ]; then
	echo -e
	print_status "error" "You do not have write permission in this directory. Switch to an owned directory and re-run the script."
	exit 1
fi
rm "$DATE.test"
mkdir -p "$YABS_PATH"

# trap CTRL+C signals to exit script cleanly
trap catch_abort INT

# catch_abort
# Purpose: This method will catch CTRL+C signals in order to exit the script cleanly and remove
#          yabs-related files.
function catch_abort() {
	echo -e "\n"
	print_status "warning" "Aborting YABS. Cleaning up files..."
	rm -rf "$YABS_PATH"
	unset LC_ALL
	exit 0
}

# format_speed
# Purpose: This method is a convenience function to format the output of the fio disk tests which
#          always returns a result in KB/s. If result is >= 1 GB/s, use GB/s. If result is < 1 GB/s
#          and >= 1 MB/s, then use MB/s. Otherwise, use KB/s.
# Parameters:
#          1. RAW - the raw disk speed result (in KB/s)
# Returns:
#          Formatted disk speed in GB/s, MB/s, or KB/s
function format_speed {
	RAW=$1 # disk speed in KB/s
	RESULT=$RAW
	local DENOM=1
	local UNIT="KB/s"

	# ensure raw value is not null, if it is, return blank
	if [ -z "$RAW" ]; then
		echo ""
		return 0
	fi

	# check if disk speed >= 1 GB/s
	if [ "$RAW" -ge 1000000 ]; then
		DENOM=1000000
		UNIT="GB/s"
	# check if disk speed < 1 GB/s && >= 1 MB/s
	elif [ "$RAW" -ge 1000 ]; then
		DENOM=1000
		UNIT="MB/s"
	fi

	# divide the raw result to get the corresponding formatted result (based on determined unit)
	RESULT=$(awk -v a="$RESULT" -v b="$DENOM" 'BEGIN { print a / b }')
	# shorten the formatted result to two decimal places (i.e. x.xx)
	RESULT=$(echo $RESULT | awk -F. '{ printf "%0.2f",$1"."substr($2,1,2) }')
	# concat formatted result value with units and return result
	RESULT="$RESULT $UNIT"
	echo $RESULT
}

# format_iops
# Purpose: This method is a convenience function to format the output of the raw IOPS result
# Parameters:
#          1. RAW - the raw IOPS result
# Returns:
#          Formatted IOPS (i.e. 8, 123, 1.7k, 275.9k, etc.)
function format_iops {
	RAW=$1 # iops
	RESULT=$RAW

	# ensure raw value is not null, if it is, return blank
	if [ -z "$RAW" ]; then
		echo ""
		return 0
	fi

	# check if IOPS speed > 1k
	if [ "$RAW" -ge 1000 ]; then
		# divide the raw result by 1k
		RESULT=$(awk -v a="$RESULT" 'BEGIN { print a / 1000 }')
		# shorten the formatted result to one decimal place (i.e. x.x)
		RESULT=$(echo $RESULT | awk -F. '{ printf "%0.1f",$1"."substr($2,1,1) }')
		RESULT="$RESULT"k
	fi

	echo $RESULT
}

# get_speed_color
# Purpose: Returns color code based on disk speed performance
# Parameters:
#          1. SPEED - the formatted speed string (e.g., "125.50 MB/s")
#          2. TYPE - the test type (4k, 64k, 512k, 1m)
# Returns:
#          Color code string
function get_speed_color {
	SPEED_STR=$1
	TYPE=$2
	
	# Extract numeric value and unit
	SPEED_NUM=$(echo "$SPEED_STR" | awk '{print $1}')
	SPEED_UNIT=$(echo "$SPEED_STR" | awk '{print $2}')
	
	# Convert to KB/s for comparison
	if [[ "$SPEED_UNIT" == "GB/s" ]]; then
		SPEED_KB=$(awk -v a="$SPEED_NUM" 'BEGIN { print int(a * 1000000) }')
	elif [[ "$SPEED_UNIT" == "MB/s" ]]; then
		SPEED_KB=$(awk -v a="$SPEED_NUM" 'BEGIN { print int(a * 1000) }')
	else
		SPEED_KB=$(awk -v a="$SPEED_NUM" 'BEGIN { print int(a) }')
	fi
	
	# Define thresholds based on block size
	case $TYPE in
		"4k")
			if [ "$SPEED_KB" -ge 100000 ]; then
				echo "$GREEN"  # Excellent: >= 100 MB/s
			elif [ "$SPEED_KB" -ge 50000 ]; then
				echo "$YELLOW" # Good: >= 50 MB/s
			elif [ "$SPEED_KB" -ge 20000 ]; then
				echo "$ORANGE" # Fair: >= 20 MB/s
			else
				echo "$RED"    # Poor: < 20 MB/s
			fi
			;;
		"64k")
			if [ "$SPEED_KB" -ge 500000 ]; then
				echo "$GREEN"  # Excellent: >= 500 MB/s
			elif [ "$SPEED_KB" -ge 250000 ]; then
				echo "$YELLOW" # Good: >= 250 MB/s
			elif [ "$SPEED_KB" -ge 100000 ]; then
				echo "$ORANGE" # Fair: >= 100 MB/s
			else
				echo "$RED"    # Poor: < 100 MB/s
			fi
			;;
		"512k")
			if [ "$SPEED_KB" -ge 1000000 ]; then
				echo "$GREEN"  # Excellent: >= 1 GB/s
			elif [ "$SPEED_KB" -ge 500000 ]; then
				echo "$YELLOW" # Good: >= 500 MB/s
			elif [ "$SPEED_KB" -ge 250000 ]; then
				echo "$ORANGE" # Fair: >= 250 MB/s
			else
				echo "$RED"    # Poor: < 250 MB/s
			fi
			;;
		"1m")
			if [ "$SPEED_KB" -ge 2000000 ]; then
				echo "$GREEN"  # Excellent: >= 2 GB/s
			elif [ "$SPEED_KB" -ge 1000000 ]; then
				echo "$YELLOW" # Good: >= 1 GB/s
			elif [ "$SPEED_KB" -ge 500000 ]; then
				echo "$ORANGE" # Fair: >= 500 MB/s
			else
				echo "$RED"    # Poor: < 500 MB/s
			fi
			;;
	esac
}

# get_speed_rating
# Purpose: Returns performance rating based on disk speed
# Parameters:
#          1. SPEED - the formatted speed string (e.g., "125.50 MB/s")
#          2. TYPE - the test type (4k, 64k, 512k, 1m)
# Returns:
#          Rating string (Excellent, Good, Fair, Poor)
function get_speed_rating {
	SPEED_STR=$1
	TYPE=$2
	
	COLOR=$(get_speed_color "$SPEED_STR" "$TYPE")
	
	if [[ "$COLOR" == "$GREEN" ]]; then
		echo "Excellent"
	elif [[ "$COLOR" == "$YELLOW" ]]; then
		echo "Good"
	elif [[ "$COLOR" == "$ORANGE" ]]; then
		echo "Fair"
	else
		echo "Poor"
	fi
}

# draw_speed_bar
# Purpose: Draws a visual bar graph for disk speed
# Parameters:
#          1. SPEED - the formatted speed string (e.g., "125.50 MB/s")
#          2. TYPE - the test type (4k, 64k, 512k, 1m)
#          3. MAX_WIDTH - maximum width of the bar (default: 20)
# Returns:
#          Visual bar string
function draw_speed_bar {
	SPEED_STR=$1
	TYPE=$2
	MAX_WIDTH=${3:-20}
	
	# Extract numeric value and unit
	SPEED_NUM=$(echo "$SPEED_STR" | awk '{print $1}')
	SPEED_UNIT=$(echo "$SPEED_STR" | awk '{print $2}')
	
	# Convert to KB/s for comparison
	if [[ "$SPEED_UNIT" == "GB/s" ]]; then
		SPEED_KB=$(awk -v a="$SPEED_NUM" 'BEGIN { print int(a * 1000000) }')
	elif [[ "$SPEED_UNIT" == "MB/s" ]]; then
		SPEED_KB=$(awk -v a="$SPEED_NUM" 'BEGIN { print int(a * 1000) }')
	else
		SPEED_KB=$(awk -v a="$SPEED_NUM" 'BEGIN { print int(a) }')
	fi
	
	# Define max values for normalization based on block size
	case $TYPE in
		"4k")   MAX_SPEED=200000 ;;    # 200 MB/s max
		"64k")  MAX_SPEED=1000000 ;;   # 1 GB/s max
		"512k") MAX_SPEED=3000000 ;;   # 3 GB/s max
		"1m")   MAX_SPEED=5000000 ;;   # 5 GB/s max
	esac
	
	# Calculate bar length
	BAR_LENGTH=$(awk -v speed="$SPEED_KB" -v max="$MAX_SPEED" -v width="$MAX_WIDTH" 'BEGIN { 
		len = int((speed / max) * width); 
		if (len > width) len = width; 
		if (len < 1 && speed > 0) len = 1; 
		print len 
	}')
	
	# Get color
	COLOR=$(get_speed_color "$SPEED_STR" "$TYPE")
	
	# Build the bar
	BAR=""
	for ((i=1; i<=MAX_WIDTH; i++)); do
		if [ $i -le $BAR_LENGTH ]; then
			BAR="${BAR}${COLOR}${PROGRESS_FILLED}${NC}"
		else
			BAR="${BAR}${DIM}${PROGRESS_EMPTY}${NC}"
		fi
	done
	
	echo "$BAR"
}

# disk_test
# Purpose: This method is designed to test the disk performance of the host using the partition that the
#          script is being run from using fio random read/write speed tests.
# Parameters:
#          - (none)
function disk_test {
	if [[ "$ARCH" = "aarch64" || "$ARCH" = "arm" ]]; then
		FIO_SIZE=512M
	else
		FIO_SIZE=2G
	fi
	
	# For macOS, use appropriate ioengine
	if [[ "$OSTYPE" == "darwin"* ]]; then
		IO_ENGINE="posixaio"
	else
		IO_ENGINE="libaio"
	fi

	# run a quick test to generate the fio test file to be used by the actual tests
	start_spinner "Generating fio test file..."
	$FIO_CMD --name=setup --ioengine=$IO_ENGINE --rw=read --bs=64k --iodepth=64 --numjobs=2 --size=$FIO_SIZE --runtime=1 --gtod_reduce=1 --filename="$DISK_PATH/test.fio" --direct=1 --minimal &> /dev/null
	stop_spinner

	# get array of block sizes to evaluate
	BLOCK_SIZES=("$@")
	BLOCK_SIZE_COUNT=${#BLOCK_SIZES[@]}
	CURRENT_TEST=0

	for BS in "${BLOCK_SIZES[@]}"; do
		CURRENT_TEST=$((CURRENT_TEST + 1))
		# run rand read/write mixed fio test with block size = $BS
		echo -ne "\r"
		print_progress $CURRENT_TEST $BLOCK_SIZE_COUNT 40 "Disk Test ($BS)"
		start_spinner "Testing with $BS block size..."
		if [[ "$OSTYPE" == "darwin"* ]]; then
			# macOS timeout command syntax is different
			DISK_TEST=$(gtimeout 35 $FIO_CMD --name=rand_rw_$BS --ioengine=$IO_ENGINE --rw=randrw --rwmixread=50 --bs=$BS --iodepth=64 --numjobs=2 --size=$FIO_SIZE --runtime=30 --gtod_reduce=1 --direct=1 --filename="$DISK_PATH/test.fio" --group_reporting --minimal 2> /dev/null | grep rand_rw_$BS || \
				$FIO_CMD --name=rand_rw_$BS --ioengine=$IO_ENGINE --rw=randrw --rwmixread=50 --bs=$BS --iodepth=64 --numjobs=2 --size=$FIO_SIZE --runtime=30 --gtod_reduce=1 --direct=1 --filename="$DISK_PATH/test.fio" --group_reporting --minimal 2> /dev/null | grep rand_rw_$BS)
		else
			DISK_TEST=$(timeout 35 $FIO_CMD --name=rand_rw_$BS --ioengine=libaio --rw=randrw --rwmixread=50 --bs=$BS --iodepth=64 --numjobs=2 --size=$FIO_SIZE --runtime=30 --gtod_reduce=1 --direct=1 --filename="$DISK_PATH/test.fio" --group_reporting --minimal 2> /dev/null | grep rand_rw_$BS)
		fi
		DISK_IOPS_R=$(echo $DISK_TEST | awk -F';' '{print $8}')
		DISK_IOPS_W=$(echo $DISK_TEST | awk -F';' '{print $49}')
		DISK_IOPS=$(awk -v a="$DISK_IOPS_R" -v b="$DISK_IOPS_W" 'BEGIN { print a + b }')
		DISK_TEST_R=$(echo $DISK_TEST | awk -F';' '{print $7}')
		DISK_TEST_W=$(echo $DISK_TEST | awk -F';' '{print $48}')
		DISK_TEST=$(awk -v a="$DISK_TEST_R" -v b="$DISK_TEST_W" 'BEGIN { print a + b }')
		DISK_RESULTS_RAW+=( "$DISK_TEST" "$DISK_TEST_R" "$DISK_TEST_W" "$DISK_IOPS" "$DISK_IOPS_R" "$DISK_IOPS_W" )

		DISK_IOPS=$(format_iops $DISK_IOPS)
		DISK_IOPS_R=$(format_iops $DISK_IOPS_R)
		DISK_IOPS_W=$(format_iops $DISK_IOPS_W)
		DISK_TEST=$(format_speed $DISK_TEST)
		DISK_TEST_R=$(format_speed $DISK_TEST_R)
		DISK_TEST_W=$(format_speed $DISK_TEST_W)

		DISK_RESULTS+=( "$DISK_TEST" "$DISK_TEST_R" "$DISK_TEST_W" "$DISK_IOPS" "$DISK_IOPS_R" "$DISK_IOPS_W" )
		stop_spinner
		
		# Show completion for this test with color-coded performance
		echo -ne "\r"
		READ_COLOR=$(get_speed_color "${DISK_TEST_R}" "$BS")
		WRITE_COLOR=$(get_speed_color "${DISK_TEST_W}" "$BS")
		READ_BAR=$(draw_speed_bar "${DISK_TEST_R}" "$BS" 10)
		WRITE_BAR=$(draw_speed_bar "${DISK_TEST_W}" "$BS" 10)
		echo -e "${GREEN}${CHECK_MARK}${NC} Completed ${BOLD}$BS${NC} test: ${CYAN}Read${NC}  ${READ_COLOR}${DISK_TEST_R}${NC} ${READ_BAR}  ${CYAN}Write${NC} ${WRITE_COLOR}${DISK_TEST_W}${NC} ${WRITE_BAR}"
	done
}

# dd_test
# Purpose: This method is invoked if the fio disk test failed. dd sequential speed tests are
#          not indiciative or real-world results, however, some form of disk speed measure 
#          is better than nothing.
# Parameters:
#          - (none)
function dd_test {
	I=0
	DISK_WRITE_TEST_RES=()
	DISK_READ_TEST_RES=()
	DISK_WRITE_TEST_AVG=0
	DISK_READ_TEST_AVG=0

	# run the disk speed tests (write and read) thrice over
	echo -e "\n${CYAN}Running dd fallback tests...${NC}"
	while [ $I -lt 3 ]
	do
		print_progress $((I + 1)) 3 30 "DD Test"
		# write test using dd, "direct" flag is used to test direct I/O for data being stored to disk
		if [[ "$OSTYPE" == "darwin"* ]]; then
			# macOS doesn't support oflag=direct, use different approach
			DISK_WRITE_TEST=$(dd if=/dev/zero of="$DISK_PATH/$DATE.test" bs=64k count=16k 2>&1 | grep -E 'bytes|copied' | tail -1 | awk '{ print $(NF-1) " " $(NF)}')
		else
			DISK_WRITE_TEST=$(dd if=/dev/zero of="$DISK_PATH/$DATE.test" bs=64k count=16k oflag=direct |& grep copied | awk '{ print $(NF-1) " " $(NF)}')
		fi
		VAL=$(echo $DISK_WRITE_TEST | cut -d " " -f 1)
		[[ "$DISK_WRITE_TEST" == *"GB"* ]] && VAL=$(awk -v a="$VAL" 'BEGIN { print a * 1000 }')
		DISK_WRITE_TEST_RES+=( "$DISK_WRITE_TEST" )
		DISK_WRITE_TEST_AVG=$(awk -v a="$DISK_WRITE_TEST_AVG" -v b="$VAL" 'BEGIN { print a + b }')

		# read test using dd using the 1G file written during the write test
		if [[ "$OSTYPE" == "darwin"* ]]; then
			DISK_READ_TEST=$(dd if="$DISK_PATH/$DATE.test" of=/dev/null bs=8k 2>&1 | grep -E 'bytes|copied' | tail -1 | awk '{ print $(NF-1) " " $(NF)}')
		else
			DISK_READ_TEST=$(dd if="$DISK_PATH/$DATE.test" of=/dev/null bs=8k |& grep copied | awk '{ print $(NF-1) " " $(NF)}')
		fi
		VAL=$(echo $DISK_READ_TEST | cut -d " " -f 1)
		[[ "$DISK_READ_TEST" == *"GB"* ]] && VAL=$(awk -v a="$VAL" 'BEGIN { print a * 1000 }')
		DISK_READ_TEST_RES+=( "$DISK_READ_TEST" )
		DISK_READ_TEST_AVG=$(awk -v a="$DISK_READ_TEST_AVG" -v b="$VAL" 'BEGIN { print a + b }')

		I=$(( $I + 1 ))
	done
	# calculate the write and read speed averages using the results from the three runs
	DISK_WRITE_TEST_AVG=$(awk -v a="$DISK_WRITE_TEST_AVG" 'BEGIN { print a / 3 }')
	DISK_READ_TEST_AVG=$(awk -v a="$DISK_READ_TEST_AVG" 'BEGIN { print a / 3 }')
}

# check if disk performance is being tested and the host has required space (2G)
AVAIL_SPACE=$(df -k . | awk 'NR==2{print $4}')
if [[ -z "$SKIP_FIO" && "$AVAIL_SPACE" -lt 2097152 && "$ARCH" != "aarch64" && "$ARCH" != "arm" ]]; then # 2GB = 2097152KB
	print_status "warning" "Less than 2GB of space available. Skipping disk test..."
elif [[ -z "$SKIP_FIO" && "$AVAIL_SPACE" -lt 524288 && ("$ARCH" = "aarch64" || "$ARCH" = "arm") ]]; then # 512MB = 524288KB
	print_status "warning" "Less than 512MB of space available. Skipping disk test..."
# if the skip disk flag was set, skip the disk performance test, otherwise test disk performance
elif [ -z "$SKIP_FIO" ]; then
	# Perform ZFS filesystem detection and determine if we have enough free space according to spa_asize_inflation
	ZFSCHECK="/sys/module/zfs/parameters/spa_asize_inflation"
	if [[ -f "$ZFSCHECK" ]];then
		mul_spa=$((($(cat /sys/module/zfs/parameters/spa_asize_inflation)*2)))
		warning=0
		poss=()

		for pathls in $(df -Th | awk '{print $7}' | tail -n +2)
		do
			if [[ "${PWD##$pathls}" != "${PWD}" ]]; then
				poss+=("$pathls")
			fi
		done

		long=""
		m=-1
		for x in ${poss[@]}
		do
			if [ ${#x} -gt $m ];then
				m=${#x}
				long=$x
			fi
		done

		size_b=$(df -Th | grep -w $long | grep -i zfs | awk '{print $5}' | tail -c -2 | head -c 1)
		free_space=$(df -Th | grep -w $long | grep -i zfs | awk '{print $5}' | head -c -2)

		if [[ $size_b == 'T' ]]; then
			free_space=$(awk "BEGIN {print int($free_space * 1024)}")
			size_b='G'
		fi

		if [[ $(df -Th | grep -w $long) == *"zfs"* ]];then

			if [[ $size_b == 'G' ]]; then
				if ((free_space < mul_spa)); then
					warning=1
				fi
			else
				warning=1
			fi

		fi

		if [[ $warning -eq 1 ]];then
			print_status "warning" "You are running YABS on a ZFS Filesystem and your disk space is too low for the fio test. Your test results will be inaccurate. You need at least $mul_spa GB free in order to complete this test accurately."
		fi
	fi
	
	start_spinner "Preparing system for disk tests..."

	# create temp directory to store disk write/read test files
	DISK_PATH=$YABS_PATH/disk
	mkdir -p "$DISK_PATH"

	if [[ -z "$PREFER_BIN" && ! -z "$LOCAL_FIO" ]]; then # local fio has been detected, use instead of pre-compiled binary
		FIO_CMD=fio
	else
		# For macOS, the pre-compiled binaries are Linux ELF format and won't work
		if [[ "$OSTYPE" == "darwin"* ]]; then
			# Try to install fio via Homebrew if available
			if command -v brew >/dev/null 2>&1; then
				print_status "info" "Installing fio via Homebrew for macOS compatibility..."
				brew install fio >/dev/null 2>&1
				if command -v fio >/dev/null 2>&1; then
					FIO_CMD=fio
				else
					print_status "warning" "Homebrew fio install failed. Using dd test as fallback..."
					DD_FALLBACK=True
				fi
			else
				print_status "warning" "macOS detected but Homebrew not available. Pre-compiled fio binaries are Linux-only. Using dd test as fallback..."
				DD_FALLBACK=True
			fi
		else
			# Linux - download pre-compiled fio binary
			if [[ ! -z $LOCAL_CURL ]]; then
				curl -s --connect-timeout 5 --retry 5 --retry-delay 0 https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/bin/fio/fio_$ARCH -o "$DISK_PATH/fio"
			else
				wget -q -T 5 -t 5 -w 0 https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/bin/fio/fio_$ARCH -O "$DISK_PATH/fio"
			fi

			if [ ! -f "$DISK_PATH/fio" ]; then # ensure fio binary download successfully
				stop_spinner
				print_status "error" "Fio binary download failed. Running dd test as fallback...."
				DD_FALLBACK=True
			else
				chmod +x "$DISK_PATH/fio"
				FIO_CMD=$DISK_PATH/fio
			fi
		fi
	fi

	stop_spinner

	if [ -z "$DD_FALLBACK" ]; then # if not falling back on dd tests, run fio test
		animated_transition "Initializing disk performance tests..."
		print_section "Disk Speed Tests (fio)" "$CHART"
		echo
		echo -e "${DIM}Running mixed read/write tests with various block sizes...${NC}"
		echo -e "${DIM}Each test performs random I/O operations to measure real-world performance.${NC}"
		echo

		# init global array to store disk performance values
		declare -a DISK_RESULTS DISK_RESULTS_RAW
		# disk block sizes to evaluate
		BLOCK_SIZES=( "4k" "64k" "512k" "1m" )

		# execute disk performance test
		disk_test "${BLOCK_SIZES[@]}"
	fi

	if [[ ! -z "$DD_FALLBACK" || ${#DISK_RESULTS[@]} -eq 0 ]]; then # fio download failed or test was killed or returned an error, run dd test instead
		if [ -z "$DD_FALLBACK" ]; then # print error notice if ended up here due to fio error
			print_status "error" "fio disk speed tests failed. Run manually to determine cause."
			print_status "info" "Running dd test as fallback..."
		fi

		dd_test

		# format the speed averages by converting to GB/s if > 1000 MB/s
		if [ $(echo $DISK_WRITE_TEST_AVG | cut -d "." -f 1) -ge 1000 ]; then
			DISK_WRITE_TEST_AVG=$(awk -v a="$DISK_WRITE_TEST_AVG" 'BEGIN { print a / 1000 }')
			DISK_WRITE_TEST_UNIT="GB/s"
		else
			DISK_WRITE_TEST_UNIT="MB/s"
		fi
		if [ $(echo $DISK_READ_TEST_AVG | cut -d "." -f 1) -ge 1000 ]; then
			DISK_READ_TEST_AVG=$(awk -v a="$DISK_READ_TEST_AVG" 'BEGIN { print a / 1000 }')
			DISK_READ_TEST_UNIT="GB/s"
		else
			DISK_READ_TEST_UNIT="MB/s"
		fi

		# print dd sequential disk speed test results
		print_section "dd Sequential Disk Speed Tests" "$CHART"
		echo -e "${BLUE}┌────────┬─────────────┬─────────────┬─────────────┬──────────────┐${NC}"
		echo -e "${BLUE}│${NC}        ${BLUE}│${NC} ${BOLD}Test 1${NC}      ${BLUE}│${NC} ${BOLD}Test 2${NC}      ${BLUE}│${NC} ${BOLD}Test 3${NC}      ${BLUE}│${NC} ${BOLD}Average${NC}      ${BLUE}│${NC}"
		echo -e "${BLUE}├────────┼─────────────┼─────────────┼─────────────┼──────────────┤${NC}"
		printf "${BLUE}│${NC} ${CYAN}Write${NC}  ${BLUE}│${NC} %-11s ${BLUE}│${NC} %-11s ${BLUE}│${NC} %-11s ${BLUE}│${NC} ${GREEN}%-6.2f %-4s${NC}  ${BLUE}│${NC}\n" "${DISK_WRITE_TEST_RES[0]}" "${DISK_WRITE_TEST_RES[1]}" "${DISK_WRITE_TEST_RES[2]}" "${DISK_WRITE_TEST_AVG}" "${DISK_WRITE_TEST_UNIT}" 
		printf "${BLUE}│${NC} ${CYAN}Read${NC}   ${BLUE}│${NC} %-11s ${BLUE}│${NC} %-11s ${BLUE}│${NC} %-11s ${BLUE}│${NC} ${GREEN}%-6.2f %-4s${NC}  ${BLUE}│${NC}\n" "${DISK_READ_TEST_RES[0]}" "${DISK_READ_TEST_RES[1]}" "${DISK_READ_TEST_RES[2]}" "${DISK_READ_TEST_AVG}" "${DISK_READ_TEST_UNIT}" 
		echo -e "${BLUE}└────────┴─────────────┴─────────────┴─────────────┴──────────────┘${NC}"
	else # fio tests completed successfully, print results
		# Get the correct partition for the current directory
		if [[ "$OSTYPE" == "darwin"* ]]; then
			CURRENT_PARTITION=$(df -P . 2>/dev/null | tail -1 | awk '{print $1}' | head -1)
		else
			CURRENT_PARTITION=$(df -P . 2>/dev/null | tail -1 | cut -d' ' -f 1)
		fi
		[[ ! -z $JSON ]] && JSON_RESULT+=',\"partition\":\"'$CURRENT_PARTITION'\",\"fio\":['
		DISK_RESULTS_NUM=$(expr ${#DISK_RESULTS[@]} / 6)
		DISK_COUNT=0

		# print disk speed test results
		print_section "fio Disk Speed Tests (Mixed R/W 50/50)" "$CHART"
		echo -e "${DIM}Partition: $CURRENT_PARTITION${NC}"
		echo
		
		# Display results with visual bars
		echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
		echo -e "${BLUE}║${NC}  ${BOLD}Block Size${NC}      ${BOLD}Read Speed${NC}          ${BOLD}Write Speed${NC}         ${BOLD}Performance${NC}          ${BLUE}║${NC}"
		echo -e "${BLUE}╠═══════════════════════════════════════════════════════════════════════════════╣${NC}"
		
		# 4k test results
		READ_COLOR_4K=$(get_speed_color "${DISK_RESULTS[1]}" "4k")
		WRITE_COLOR_4K=$(get_speed_color "${DISK_RESULTS[2]}" "4k")
		READ_RATING_4K=$(get_speed_rating "${DISK_RESULTS[1]}" "4k")
		WRITE_RATING_4K=$(get_speed_rating "${DISK_RESULTS[2]}" "4k")
		READ_BAR_4K=$(draw_speed_bar "${DISK_RESULTS[1]}" "4k" 15)
		WRITE_BAR_4K=$(draw_speed_bar "${DISK_RESULTS[2]}" "4k" 15)
		
		echo -e "${BLUE}║${NC}  ${BOLD}4k${NC}                                                                           ${BLUE}║${NC}"
		printf "${BLUE}║${NC}   ${CYAN}├─ Read:${NC}  ${READ_COLOR_4K}%-11s${NC} ${READ_BAR_4K}  ${DIM}(%8s IOPS)${NC}  ${READ_COLOR_4K}%-10s${NC}          ${BLUE}║${NC}\n" "${DISK_RESULTS[1]}" "${DISK_RESULTS[4]}" "${READ_RATING_4K}"
		printf "${BLUE}║${NC}   ${CYAN}└─ Write:${NC} ${WRITE_COLOR_4K}%-11s${NC} ${WRITE_BAR_4K}  ${DIM}(%8s IOPS)${NC}  ${WRITE_COLOR_4K}%-10s${NC}          ${BLUE}║${NC}\n" "${DISK_RESULTS[2]}" "${DISK_RESULTS[5]}" "${WRITE_RATING_4K}"
		
		echo -e "${BLUE}╟───────────────────────────────────────────────────────────────────────────────╢${NC}"
		
		# 64k test results
		READ_COLOR_64K=$(get_speed_color "${DISK_RESULTS[7]}" "64k")
		WRITE_COLOR_64K=$(get_speed_color "${DISK_RESULTS[8]}" "64k")
		READ_RATING_64K=$(get_speed_rating "${DISK_RESULTS[7]}" "64k")
		WRITE_RATING_64K=$(get_speed_rating "${DISK_RESULTS[8]}" "64k")
		READ_BAR_64K=$(draw_speed_bar "${DISK_RESULTS[7]}" "64k" 15)
		WRITE_BAR_64K=$(draw_speed_bar "${DISK_RESULTS[8]}" "64k" 15)
		
		echo -e "${BLUE}║${NC}  ${BOLD}64k${NC}                                                                        ${BLUE}║${NC}"
		printf "${BLUE}║${NC}   ${CYAN}├─ Read:${NC}  ${READ_COLOR_64K}%-11s${NC} ${READ_BAR_64K}  ${DIM}(%8s IOPS)${NC}  ${READ_COLOR_64K}%-10s${NC} ${BLUE}║${NC}\n" "${DISK_RESULTS[7]}" "${DISK_RESULTS[10]}" "${READ_RATING_64K}"
		printf "${BLUE}║${NC}   ${CYAN}└─ Write:${NC} ${WRITE_COLOR_64K}%-11s${NC} ${WRITE_BAR_64K}  ${DIM}(%8s IOPS)${NC}  ${WRITE_COLOR_64K}%-10s${NC} ${BLUE}║${NC}\n" "${DISK_RESULTS[8]}" "${DISK_RESULTS[11]}" "${WRITE_RATING_64K}"
		
		echo -e "${BLUE}╟───────────────────────────────────────────────────────────────────────────────╢${NC}"
		
		# 512k test results
		READ_COLOR_512K=$(get_speed_color "${DISK_RESULTS[13]}" "512k")
		WRITE_COLOR_512K=$(get_speed_color "${DISK_RESULTS[14]}" "512k")
		READ_RATING_512K=$(get_speed_rating "${DISK_RESULTS[13]}" "512k")
		WRITE_RATING_512K=$(get_speed_rating "${DISK_RESULTS[14]}" "512k")
		READ_BAR_512K=$(draw_speed_bar "${DISK_RESULTS[13]}" "512k" 15)
		WRITE_BAR_512K=$(draw_speed_bar "${DISK_RESULTS[14]}" "512k" 15)
		
		echo -e "${BLUE}║${NC}  ${BOLD}512k${NC}                                                                       ${BLUE}║${NC}"
		printf "${BLUE}║${NC}   ${CYAN}├─ Read:${NC}  ${READ_COLOR_512K}%-11s${NC} ${READ_BAR_512K}  ${DIM}(%8s IOPS)${NC}  ${READ_COLOR_512K}%-10s${NC} ${BLUE}║${NC}\n" "${DISK_RESULTS[13]}" "${DISK_RESULTS[16]}" "${READ_RATING_512K}"
		printf "${BLUE}║${NC}   ${CYAN}└─ Write:${NC} ${WRITE_COLOR_512K}%-11s${NC} ${WRITE_BAR_512K}  ${DIM}(%8s IOPS)${NC}  ${WRITE_COLOR_512K}%-10s${NC} ${BLUE}║${NC}\n" "${DISK_RESULTS[14]}" "${DISK_RESULTS[17]}" "${WRITE_RATING_512K}"
		
		echo -e "${BLUE}╟───────────────────────────────────────────────────────────────────────────────╢${NC}"
		
		# 1m test results
		READ_COLOR_1M=$(get_speed_color "${DISK_RESULTS[19]}" "1m")
		WRITE_COLOR_1M=$(get_speed_color "${DISK_RESULTS[20]}" "1m")
		READ_RATING_1M=$(get_speed_rating "${DISK_RESULTS[19]}" "1m")
		WRITE_RATING_1M=$(get_speed_rating "${DISK_RESULTS[20]}" "1m")
		READ_BAR_1M=$(draw_speed_bar "${DISK_RESULTS[19]}" "1m" 15)
		WRITE_BAR_1M=$(draw_speed_bar "${DISK_RESULTS[20]}" "1m" 15)
		
		echo -e "${BLUE}║${NC}  ${BOLD}1m${NC}                                                                         ${BLUE}║${NC}"
		printf "${BLUE}║${NC}   ${CYAN}├─ Read:${NC}  ${READ_COLOR_1M}%-11s${NC} ${READ_BAR_1M}  ${DIM}(%8s IOPS)${NC}  ${READ_COLOR_1M}%-10s${NC} ${BLUE}║${NC}\n" "${DISK_RESULTS[19]}" "${DISK_RESULTS[22]}" "${READ_RATING_1M}"
		printf "${BLUE}║${NC}   ${CYAN}└─ Write:${NC} ${WRITE_COLOR_1M}%-11s${NC} ${WRITE_BAR_1M}  ${DIM}(%8s IOPS)${NC}  ${WRITE_COLOR_1M}%-10s${NC} ${BLUE}║${NC}\n" "${DISK_RESULTS[20]}" "${DISK_RESULTS[23]}" "${WRITE_RATING_1M}"
		
		echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
		
		# Display summary
		echo
		echo -e "${BOLD}Performance Summary:${NC}"
		echo -e "  ${GREEN}●${NC} Excellent  ${YELLOW}●${NC} Good  ${ORANGE}●${NC} Fair  ${RED}●${NC} Poor"
		echo

		if [ ! -z $JSON ]; then
			for ((i=0; i<4; i++)); do
				JSON_RESULT+='{"bs":"'${BLOCK_SIZES[i]}'","speed_r":'${DISK_RESULTS_RAW[i*6+1]}',"iops_r":'${DISK_RESULTS_RAW[i*6+4]}
				JSON_RESULT+=',"speed_w":'${DISK_RESULTS_RAW[i*6+2]}',"iops_w":'${DISK_RESULTS_RAW[i*6+5]}',"speed_rw":'${DISK_RESULTS_RAW[i*6]}
				JSON_RESULT+=',"iops_rw":'${DISK_RESULTS_RAW[i*6+3]}',"speed_units":"KBps"},'
			done
			JSON_RESULT=${JSON_RESULT::${#JSON_RESULT}-1}
			JSON_RESULT+=']'
		fi
	fi
fi

# iperf_test
# Purpose: This method is designed to test the network performance of the host by executing an
#          iperf3 test to/from the public iperf server passed to the function. Both directions 
#          (send and receive) are tested.
# Parameters:
#          1. URL - URL/domain name of the iperf server
#          2. PORTS - the range of ports on which the iperf server operates
#          3. HOST - the friendly name of the iperf server host/owner
#          4. FLAGS - any flags that should be passed to the iperf command
function iperf_test {
	URL=$1
	PORTS=$2
	HOST=$3
	FLAGS=$4
	
	# attempt the iperf send test 3 times, allowing for a slot to become available on the
	#   server or to throw out any bad/error results
	I=1
	while [ $I -le 3 ]
	do
		start_spinner "Performing $MODE iperf3 send test to $HOST (Attempt #$I of 3)..."
		# select a random iperf port from the range provided
		PORT=$(shuf -i $PORTS -n 1)
		# run the iperf test sending data from the host to the iperf server; includes
		#   a timeout of 15s in case the iperf server is not responding; uses 8 parallel
		#   threads for the network test
		if [[ "$OSTYPE" == "darwin"* ]]; then
			# Try gtimeout first (from GNU coreutils), fallback to no timeout
			if command -v gtimeout >/dev/null 2>&1; then
				IPERF_RUN_SEND="$(gtimeout 15 $IPERF_CMD $FLAGS -c "$URL" -p $PORT -P 8 2> /dev/null)"
			else
				IPERF_RUN_SEND="$($IPERF_CMD $FLAGS -c "$URL" -p $PORT -P 8 -t 10 2> /dev/null)"
			fi
		else
			IPERF_RUN_SEND="$(timeout 15 $IPERF_CMD $FLAGS -c "$URL" -p $PORT -P 8 2> /dev/null)"
		fi
		# check if iperf exited cleanly and did not return an error
		if [[ "$IPERF_RUN_SEND" == *"receiver"* && "$IPERF_RUN_SEND" != *"error"* ]]; then
			# test did not result in an error, parse speed result
			SPEED=$(echo "${IPERF_RUN_SEND}" | grep SUM | grep receiver | awk '{ print $6 }')
			# if speed result is blank or bad (0.00), rerun, otherwise set counter to exit loop
			[[ -z $SPEED || "$SPEED" == "0.00" ]] && I=$(( $I + 1 )) || I=11
		else
			# if iperf server is not responding, set counter to exit, otherwise increment, sleep, and rerun
			[[ "$IPERF_RUN_SEND" == *"unable to connect"* ]] && I=11 || I=$(( $I + 1 )) && sleep 2
		fi
		stop_spinner
	done

	# small sleep necessary to give iperf server a breather to get ready for a new test
	sleep 1

	# attempt the iperf receive test 3 times, allowing for a slot to become available on
	#   the server or to throw out any bad/error results
	J=1
	while [ $J -le 3 ]
	do
		start_spinner "Performing $MODE iperf3 recv test from $HOST (Attempt #$J of 3)..."
		# select a random iperf port from the range provided
		PORT=$(shuf -i $PORTS -n 1)
		# run the iperf test receiving data from the iperf server to the host; includes
		#   a timeout of 15s in case the iperf server is not responding; uses 8 parallel
		#   threads for the network test
		if [[ "$OSTYPE" == "darwin"* ]]; then
			# Try gtimeout first (from GNU coreutils), fallback to no timeout
			if command -v gtimeout >/dev/null 2>&1; then
				IPERF_RUN_RECV="$(gtimeout 15 $IPERF_CMD $FLAGS -c "$URL" -p $PORT -P 8 -R 2> /dev/null)"
			else
				IPERF_RUN_RECV="$($IPERF_CMD $FLAGS -c "$URL" -p $PORT -P 8 -R -t 10 2> /dev/null)"
			fi
		else
			IPERF_RUN_RECV="$(timeout 15 $IPERF_CMD $FLAGS -c "$URL" -p $PORT -P 8 -R 2> /dev/null)"
		fi
		# check if iperf exited cleanly and did not return an error
		if [[ "$IPERF_RUN_RECV" == *"receiver"* && "$IPERF_RUN_RECV" != *"error"* ]]; then
			# test did not result in an error, parse speed result
			SPEED=$(echo "${IPERF_RUN_RECV}" | grep SUM | grep receiver | awk '{ print $6 }')
			# if speed result is blank or bad (0.00), rerun, otherwise set counter to exit loop
			[[ -z $SPEED || "$SPEED" == "0.00" ]] && J=$(( $J + 1 )) || J=11
		else
			# if iperf server is not responding, set counter to exit, otherwise increment, sleep, and rerun
			[[ "$IPERF_RUN_RECV" == *"unable to connect"* ]] && J=11 || J=$(( $J + 1 )) && sleep 2
		fi
		stop_spinner
	done
	
	# Run a latency test via ping -c1 command -> will return "xx.x ms"
	[[ ! -z $LOCAL_PING ]] && LATENCY_RUN="$(ping -c1 $URL 2>/dev/null | grep -o 'time=.*' | sed s/'time='//)" 
	[[ -z $LATENCY_RUN ]] && LATENCY_RUN="--"

	# parse the resulting send and receive speed results
	IPERF_SENDRESULT="$(echo "${IPERF_RUN_SEND}" | grep SUM | grep receiver)"
	IPERF_RECVRESULT="$(echo "${IPERF_RUN_RECV}" | grep SUM | grep receiver)"
	LATENCY_RESULT="$(echo "${LATENCY_RUN}")"
}

# launch_iperf
# Purpose: This method is designed to facilitate the execution of iperf network speed tests to
#          each public iperf server in the iperf server locations array.
# Parameters:
#          1. MODE - indicates the type of iperf tests to run (IPv4 or IPv6)
function launch_iperf {
	MODE=$1
	[[ "$MODE" == *"IPv6"* ]] && IPERF_FLAGS="-6" || IPERF_FLAGS="-4"

	# print iperf3 network speed results as they are completed
	print_section "iperf3 Network Speed Tests ($MODE)" "$ROCKET"
	echo -e "${BLUE}┌─────────────────┬───────────────────────────┬─────────────────┬─────────────────┬──────────────┐${NC}"
	echo -e "${BLUE}│${NC} ${BOLD}Provider${NC}        ${BLUE}│${NC} ${BOLD}Location (Link)${NC}           ${BLUE}│${NC} ${BOLD}Send Speed${NC}      ${BLUE}│${NC} ${BOLD}Recv Speed${NC}      ${BLUE}│${NC} ${BOLD}Ping${NC}         ${BLUE}│${NC}"
	echo -e "${BLUE}├─────────────────┼───────────────────────────┼─────────────────┼─────────────────┼──────────────┤${NC}"
	
	# loop through iperf locations array to run iperf test using each public iperf server
	for (( i = 0; i < IPERF_LOCS_NUM; i++ )); do
		# test if the current iperf location supports the network mode being tested (IPv4/IPv6)
		if [[ "${IPERF_LOCS[i*5+4]}" == *"$MODE"* ]]; then
			# call the iperf_test function passing the required parameters
			iperf_test "${IPERF_LOCS[i*5]}" "${IPERF_LOCS[i*5+1]}" "${IPERF_LOCS[i*5+2]}" "$IPERF_FLAGS"
			# parse the send and receive speed results
			IPERF_SENDRESULT_VAL=$(echo $IPERF_SENDRESULT | awk '{ print $6 }')
			IPERF_SENDRESULT_UNIT=$(echo $IPERF_SENDRESULT | awk '{ print $7 }')
			IPERF_RECVRESULT_VAL=$(echo $IPERF_RECVRESULT | awk '{ print $6 }')
			IPERF_RECVRESULT_UNIT=$(echo $IPERF_RECVRESULT | awk '{ print $7 }')
			LATENCY_VAL=$(echo $LATENCY_RESULT)
			# if the results are blank, then the server is "busy" and being overutilized
			[[ -z $IPERF_SENDRESULT_VAL || "$IPERF_SENDRESULT_VAL" == *"0.00"* ]] && IPERF_SENDRESULT_VAL="busy" && IPERF_SENDRESULT_UNIT=""
			[[ -z $IPERF_RECVRESULT_VAL || "$IPERF_RECVRESULT_VAL" == *"0.00"* ]] && IPERF_RECVRESULT_VAL="busy" && IPERF_RECVRESULT_UNIT=""
			# print the speed results for the iperf location currently being evaluated
			# Apply colors conditionally for busy status
			if [[ "$IPERF_SENDRESULT_VAL" == "busy" ]]; then
				SEND_COLOR="${YELLOW}"
			else
				SEND_COLOR="${GREEN}"
			fi
			if [[ "$IPERF_RECVRESULT_VAL" == "busy" ]]; then
				RECV_COLOR="${YELLOW}"
			else
				RECV_COLOR="${GREEN}"
			fi
			echo -e "${BLUE}│${NC} $(printf "%-15s" "${IPERF_LOCS[i*5+2]}") ${BLUE}│${NC} $(printf "%-25s" "${IPERF_LOCS[i*5+3]}") ${BLUE}│${NC} ${SEND_COLOR}$(printf "%-15s" "$IPERF_SENDRESULT_VAL $IPERF_SENDRESULT_UNIT")${NC} ${BLUE}│${NC} ${RECV_COLOR}$(printf "%-15s" "$IPERF_RECVRESULT_VAL $IPERF_RECVRESULT_UNIT")${NC} ${BLUE}│${NC} ${CYAN}$(printf "%-12s" "$LATENCY_VAL")${NC} ${BLUE}│${NC}"
			if [ ! -z $JSON ]; then
				JSON_RESULT+='{"mode":"'$MODE'","provider":"'${IPERF_LOCS[i*5+2]}'","loc":"'${IPERF_LOCS[i*5+3]}
				JSON_RESULT+='","send":"'$IPERF_SENDRESULT_VAL' '$IPERF_SENDRESULT_UNIT'","recv":"'$IPERF_RECVRESULT_VAL' '$IPERF_RECVRESULT_UNIT'","latency":"'$LATENCY_VAL'"},'
			fi
		fi
	done
	echo -e "${BLUE}└─────────────────┴───────────────────────────┴─────────────────┴─────────────────┴──────────────┘${NC}"
}

# if the skip iperf flag was set, skip the network performance test, otherwise test network performance
if [ -z "$SKIP_IPERF" ]; then

	if [[ -z "$PREFER_BIN" && ! -z "$LOCAL_IPERF" ]]; then # local iperf has been detected, use instead of pre-compiled binary
		IPERF_CMD=iperf3
	else
		# create a temp directory to house the required iperf binary and library
		IPERF_PATH=$YABS_PATH/iperf
		mkdir -p "$IPERF_PATH"

		# download iperf3 binary
		start_spinner "Downloading iperf3 binary..."
		if [[ ! -z $LOCAL_CURL ]]; then
			curl -s --connect-timeout 5 --retry 5 --retry-delay 0 https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/bin/iperf/iperf3_$ARCH -o "$IPERF_PATH/iperf3"
		else
			wget -q -T 5 -t 5 -w 0 https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/bin/iperf/iperf3_$ARCH -O "$IPERF_PATH/iperf3"
		fi
		stop_spinner

		if [ ! -f "$IPERF_PATH/iperf3" ]; then # ensure iperf3 binary downloaded successfully
			IPERF_DL_FAIL=True
		else
			chmod +x "$IPERF_PATH/iperf3"
			IPERF_CMD=$IPERF_PATH/iperf3
		fi
	fi
	
	# array containing all currently available iperf3 public servers to use for the network test
	# format: "1" "2" "3" "4" "5" \
	#   1. domain name of the iperf server
	#   2. range of ports that the iperf server is running on (lowest-highest)
	#   3. friendly name of the host/owner of the iperf server
	#   4. location and advertised speed link of the iperf server
	#   5. network modes supported by the iperf server (IPv4 = IPv4-only, IPv4|IPv6 = IPv4 + IPv6, etc.)
	IPERF_LOCS=( \
		"lon.speedtest.clouvider.net" "5200-5209" "Clouvider" "London, UK (10G)" "IPv4|IPv6" \
		"iperf-ams-nl.eranium.net" "5201-5210" "Eranium" "Amsterdam, NL (100G)" "IPv4|IPv6" \
		#"speedtest.extra.telia.fi" "5201-5208" "Telia" "Helsinki, FI (10G)" "IPv4" \
		# AFR placeholder
		"speedtest.uztelecom.uz" "5200-5209" "Uztelecom" "Tashkent, UZ (10G)" "IPv4|IPv6" \
		"speedtest.sin1.sg.leaseweb.net" "5201-5210" "Leaseweb" "Singapore, SG (10G)" "IPv4|IPv6" \
		"la.speedtest.clouvider.net" "5200-5209" "Clouvider" "Los Angeles, CA, US (10G)" "IPv4|IPv6" \
		"speedtest.nyc1.us.leaseweb.net" "5201-5210" "Leaseweb" "NYC, NY, US (10G)" "IPv4|IPv6" \
		"speedtest.sao1.edgoo.net" "9204-9240" "Edgoo" "Sao Paulo, BR (1G)" "IPv4|IPv6"
	)

	# if the "REDUCE_NET" flag is activated, then do a shorter iperf test with only three locations
	# (Clouvider London, Clouvider NYC, and Online.net France)
	if [ ! -z "$REDUCE_NET" ]; then
		IPERF_LOCS=( \
			"lon.speedtest.clouvider.net" "5200-5209" "Clouvider" "London, UK (10G)" "IPv4|IPv6" \
			"speedtest.sin1.sg.leaseweb.net" "5201-5210" "Leaseweb" "Singapore, SG (10G)" "IPv4|IPv6" \
			"speedtest.nyc1.us.leaseweb.net" "5201-5210" "Leaseweb" "NYC, NY, US (10G)" "IPv4|IPv6" \
		)
	fi
	
	# get the total number of iperf locations (total array size divided by 5 since each location has 5 elements)
	IPERF_LOCS_NUM=${#IPERF_LOCS[@]}
	IPERF_LOCS_NUM=$((IPERF_LOCS_NUM / 5))
	
	if [ -z "$IPERF_DL_FAIL" ]; then
		[[ ! -z $JSON ]] && JSON_RESULT+=',\"iperf\":['
		# check if the host has IPv4 connectivity, if so, run iperf3 IPv4 tests
		[ ! -z "$IPV4_CHECK" ] && launch_iperf "IPv4"
		# check if the host has IPv6 connectivity, if so, run iperf3 IPv6 tests
		[ ! -z "$IPV6_CHECK" ] && launch_iperf "IPv6"
		[[ ! -z $JSON ]] && JSON_RESULT=${JSON_RESULT::${#JSON_RESULT}-1} && JSON_RESULT+=']'
	else
		print_status "error" "iperf3 binary download failed. Skipping iperf network tests..."
	fi
fi

# launch_geekbench
# Purpose: This method is designed to run the Primate Labs' Geekbench 4/5 Cross-Platform Benchmark utility
# Parameters:
#          1. VERSION - indicates which Geekbench version to run
function launch_geekbench {
	VERSION=$1

	# create a temp directory to house all geekbench files
	GEEKBENCH_PATH=$YABS_PATH/geekbench_$VERSION
	mkdir -p "$GEEKBENCH_PATH"

	GB_URL=""
	GB_CMD=""
	GB_RUN=""

	# check for curl vs wget
	[[ ! -z $LOCAL_CURL ]] && DL_CMD="curl -s" || DL_CMD="wget -qO-"

	# Handle macOS separately
	if [[ "$OSTYPE" == "darwin"* ]]; then
		# Check if Geekbench is installed as an app - look for command-line tools in Resources
		if [[ -f "/Applications/Geekbench $VERSION.app/Contents/Resources/geekbench_aarch64" ]] && [[ "$ARCH" == *"aarch64"* || "$ARCH" == *"arm64"* ]]; then
			GB_CMD="/Applications/Geekbench $VERSION.app/Contents/Resources/geekbench_aarch64"
			GB_RUN="True"
			GEEKBENCH_PATH="/Applications/Geekbench $VERSION.app/Contents/Resources"
		elif [[ -f "/Applications/Geekbench $VERSION.app/Contents/Resources/geekbench_x86_64" ]] && [[ "$ARCH" == *"x86_64"* ]]; then
			GB_CMD="/Applications/Geekbench $VERSION.app/Contents/Resources/geekbench_x86_64"
			GB_RUN="True"
			GEEKBENCH_PATH="/Applications/Geekbench $VERSION.app/Contents/Resources"
		elif [[ -f "/Applications/Geekbench $VERSION.app/Contents/Resources/geekbench$VERSION" ]]; then
			GB_CMD="/Applications/Geekbench $VERSION.app/Contents/Resources/geekbench$VERSION"
			GB_RUN="True"
			GEEKBENCH_PATH="/Applications/Geekbench $VERSION.app/Contents/Resources"
		elif command -v "geekbench$VERSION" &>/dev/null; then
			GEEKBENCH_PATH=$(dirname "$(command -v "geekbench$VERSION")")
			GB_CMD="geekbench$VERSION"
			GB_RUN="True"
		else
			print_status "error" "Geekbench $VERSION not found. Please install Geekbench $VERSION for macOS or ensure geekbench$VERSION is in your PATH."
			GB_RUN="False"
		fi
	else
		# Linux/Unix handling
		if [[ $VERSION == *4* && ($ARCH = *aarch64* || $ARCH = *arm*) ]]; then
			print_status "warning" "ARM architecture not supported by Geekbench 4, use Geekbench 5 or 6."
		elif [[ $VERSION == *4* && $ARCH != *aarch64* && $ARCH != *arm* ]]; then # Geekbench v4
			GB_URL="https://cdn.geekbench.com/Geekbench-4.4.4-Linux.tar.gz"
			[[ "$ARCH" == *"x86"* ]] && GB_CMD="geekbench_x86_32" || GB_CMD="geekbench4"
			GB_RUN="True"
		elif [[ $VERSION == *5* || $VERSION == *6* ]]; then # Geekbench v5/6
			if [[ $ARCH = *x86* && $GEEKBENCH_4 == *False* ]]; then # don't run Geekbench 5 if on 32-bit arch
				print_status "warning" "Geekbench $VERSION cannot run on 32-bit architectures. Re-run with -4 flag to use Geekbench 4."
			elif [[ $ARCH = *x86* && $GEEKBENCH_4 == *True* ]]; then
				print_status "warning" "Geekbench $VERSION cannot run on 32-bit architectures. Skipping test."
			else
				if [[ $VERSION == *5* ]]; then # Geekbench v5
					[[ $ARCH = *aarch64* || $ARCH = *arm* ]] && GB_URL="https://cdn.geekbench.com/Geekbench-5.5.1-LinuxARMPreview.tar.gz" \
						|| GB_URL="https://cdn.geekbench.com/Geekbench-5.5.1-Linux.tar.gz"
					GB_CMD="geekbench5"
				else # Geekbench v6
					[[ $ARCH = *aarch64* || $ARCH = *arm* ]] && GB_URL="https://cdn.geekbench.com/Geekbench-6.3.0-LinuxARMPreview.tar.gz" \
						|| GB_URL="https://cdn.geekbench.com/Geekbench-6.3.0-Linux.tar.gz"
					GB_CMD="geekbench6"
				fi
				GB_RUN="True"
			fi
		fi
	fi

	if [[ $GB_RUN == *True* ]]; then # run GB test
		start_spinner "Running Geekbench $VERSION test... ${CLOCK} (this may take several minutes)"

		# Handle macOS vs Linux differently for execution
		if [[ "$OSTYPE" == "darwin"* ]]; then
			# For macOS, we already have the full path to the executable
			GEEKBENCH_EXECUTABLE="$GB_CMD"
		else
			# Linux/Unix handling
			if command -v "$GB_CMD" &>/dev/null; then
				GEEKBENCH_PATH=$(dirname "$(command -v "$GB_CMD")")
				GEEKBENCH_EXECUTABLE="$GB_CMD"
			else
				# download the desired Geekbench tarball and extract to geekbench temp directory
				$DL_CMD $GB_URL | tar xz --strip-components=1 -C "$GEEKBENCH_PATH" &>/dev/null
				GEEKBENCH_EXECUTABLE="$GEEKBENCH_PATH/$GB_CMD"
			fi
		fi

		# unlock if license file detected
		test -f "geekbench.license" && "$GEEKBENCH_EXECUTABLE" --unlock $(cat geekbench.license) > /dev/null 2>&1

		# run the Geekbench test and grep the test results URL given at the end of the test
		if [[ "$OSTYPE" == "darwin"* ]]; then
			# For macOS, run the benchmark and capture the output
			GEEKBENCH_OUTPUT=$("$GEEKBENCH_EXECUTABLE" --cpu 2>/dev/null)
			# Extract the URL from the output - newer versions automatically upload
			GEEKBENCH_TEST=$(echo "$GEEKBENCH_OUTPUT" | grep -o "https://browser.geekbench.com/v6/cpu/[0-9]*")
			if [[ -z "$GEEKBENCH_TEST" ]]; then
				# Try alternative patterns for the URL
				GEEKBENCH_TEST=$(echo "$GEEKBENCH_OUTPUT" | grep -o "https://browser[^[:space:]]*")
			fi
		else
			# Linux command line version
			if [[ $VERSION == *4* || $VERSION == *5* ]]; then
				# Older versions use --upload flag
				GEEKBENCH_TEST=$("$GEEKBENCH_EXECUTABLE" --upload 2>/dev/null | grep "https://browser")
			else
				# Newer versions (6+) automatically upload
				GEEKBENCH_OUTPUT=$("$GEEKBENCH_EXECUTABLE" --cpu 2>/dev/null)
				GEEKBENCH_TEST=$(echo "$GEEKBENCH_OUTPUT" | grep -o "https://browser[^[:space:]]*")
			fi
		fi

		stop_spinner

		# ensure the test ran successfully
		if [ -z "$GEEKBENCH_TEST" ]; then
			# detect if CentOS 7 and print a more helpful error message
			if grep -q "CentOS Linux 7" /etc/os-release 2>/dev/null; then
				print_status "error" "CentOS 7 and Geekbench have known issues relating to glibc"
			fi
			if [[ -z "$IPV4_CHECK" ]]; then
				# Geekbench test failed to download because host lacks IPv4 (cdn.geekbench.com = IPv4 only)
				print_status "error" "Geekbench releases can only be downloaded over IPv4. FTP the Geekbench files and run manually."
			elif [[ $VERSION != *4* && $TOTAL_RAM_RAW -le 1048576 ]]; then
				# Geekbench 5/6 test failed with low memory (<=1GB)
				print_status "error" "Geekbench test failed and low memory was detected. Add at least 1GB of SWAP or use GB4 instead."
			elif [[ $ARCH != *x86* ]]; then
				# if the Geekbench test failed for any other reason, exit cleanly and print error message
				print_status "error" "Geekbench $VERSION test failed. Run manually to determine cause."
			fi
		else
			# if the Geekbench test succeeded, parse the test results URL
			GEEKBENCH_URL=$(echo -e $GEEKBENCH_TEST | head -1)
			GEEKBENCH_URL_CLAIM=$(echo $GEEKBENCH_URL | awk '{ print $2 }')
			GEEKBENCH_URL=$(echo $GEEKBENCH_URL | awk '{ print $1 }')
			# sleep a bit to wait for results to be made available on the geekbench website
			sleep 10
			# parse the public results page for the single and multi core geekbench scores
			[[ $VERSION == *4* ]] && GEEKBENCH_SCORES=$($DL_CMD $GEEKBENCH_URL | grep "span class='score'") || \
				GEEKBENCH_SCORES=$($DL_CMD $GEEKBENCH_URL | grep "div class='score'")
				
			GEEKBENCH_SCORES_SINGLE=$(echo $GEEKBENCH_SCORES | awk -v FS="(>|<)" '{ print $3 }')
			GEEKBENCH_SCORES_MULTI=$(echo $GEEKBENCH_SCORES | awk -v FS="(>|<)" '{ print $7 }')
		
			# print the Geekbench results
			print_section "Geekbench $VERSION Benchmark Test" "$STAR"
			echo -e "${BLUE}┌─────────────────┬────────────────────────────────┐${NC}"
			echo -e "${BLUE}│${NC} ${BOLD}Test${NC}            ${BLUE}│${NC} ${BOLD}Value${NC}                          ${BLUE}│${NC}"
			echo -e "${BLUE}├─────────────────┼────────────────────────────────┤${NC}"
			printf "${BLUE}│${NC} %-15s ${BLUE}│${NC} ${GREEN}%-30s${NC} ${BLUE}│${NC}\n" "Single Core" "$GEEKBENCH_SCORES_SINGLE"
			printf "${BLUE}│${NC} %-15s ${BLUE}│${NC} ${GREEN}%-30s${NC} ${BLUE}│${NC}\n" "Multi Core" "$GEEKBENCH_SCORES_MULTI"
			printf "${BLUE}│${NC} %-15s ${BLUE}│${NC} ${CYAN}%-30s${NC} ${BLUE}│${NC}\n" "Full Test" "$GEEKBENCH_URL"
			echo -e "${BLUE}└─────────────────┴────────────────────────────────┘${NC}"

			if [ ! -z $JSON ]; then
				JSON_RESULT+='{"version":'$VERSION',"single":'$GEEKBENCH_SCORES_SINGLE',"multi":'$GEEKBENCH_SCORES_MULTI
				JSON_RESULT+=',"url":"'$GEEKBENCH_URL'"},'
			fi

			# write the geekbench claim URL to a file so the user can add the results to their profile (if desired)
			[ ! -z "$GEEKBENCH_URL_CLAIM" ] && echo -e "$GEEKBENCH_URL_CLAIM" >> geekbench_claim.url 2> /dev/null
		fi
	fi
}

# if the skip geekbench flag was set, skip the system performance test, otherwise test system performance
if [ -z "$SKIP_GEEKBENCH" ]; then
	[[ ! -z $JSON ]] && JSON_RESULT+=',\"geekbench\":['
	if [[ $GEEKBENCH_4 == *True* ]]; then
		launch_geekbench 4
	fi

	if [[ $GEEKBENCH_5 == *True* ]]; then
		launch_geekbench 5
	fi

	if [[ $GEEKBENCH_6 == *True* ]]; then
		launch_geekbench 6
	fi
	[[ ! -z $JSON ]] && [[ $(echo -n $JSON_RESULT | tail -c 1) == ',' ]] && JSON_RESULT=${JSON_RESULT::${#JSON_RESULT}-1}
	[[ ! -z $JSON ]] && JSON_RESULT+=']'
fi

# finished all tests, clean up all YABS files and exit
echo -e
rm -rf "$YABS_PATH"

YABS_END_TIME=$(date +%s)

# calculate_time_taken
# Purpose: This method is designed to find the time taken for the completion of a YABS run.
# Parameters:
#          1. YABS_END_TIME - time when GB has completed and all files are removed
#          2. YABS_START_TIME - time when YABS is started
function calculate_time_taken() {
	end_time=$1
	start_time=$2

	time_taken=$(( ${end_time} - ${start_time} ))
	if [ ${time_taken} -gt 60 ]; then
		min=$(expr $time_taken / 60)
		sec=$(expr $time_taken % 60)
		print_status "success" "YABS completed in ${min} min ${sec} sec ${CHECK_MARK}"
	else
		print_status "success" "YABS completed in ${time_taken} sec ${CHECK_MARK}"
	fi
	[[ ! -z $JSON ]] && JSON_RESULT+=',\"runtime\":{\"start\":'$start_time',\"end\":'$end_time',\"elapsed\":'$time_taken'}'
}

calculate_time_taken $YABS_END_TIME $YABS_START_TIME

if [[ ! -z $JSON ]]; then
	JSON_RESULT+='}'

	# write json results to file
	if [[ $JSON = *w* ]]; then
		echo $JSON_RESULT > "$JSON_FILE"
		print_status "info" "JSON results written to: $JSON_FILE"
	fi

	# send json results
	if [[ $JSON = *s* ]]; then
		IFS=',' read -r -a JSON_SITES <<< "$JSON_SEND"
		for JSON_SITE in "${JSON_SITES[@]}"
		do
			if [[ ! -z $LOCAL_CURL ]]; then
				curl -s -H "Content-Type:application/json" -X POST --data ''"$JSON_RESULT"'' $JSON_SITE
			else
				wget -qO- --post-data=''"$JSON_RESULT"'' --header='Content-Type:application/json' $JSON_SITE
			fi
		done
		print_status "info" "JSON results sent to: $JSON_SEND"
	fi

	# print json result to screen
	if [[ $JSON = *j* ]]; then
		echo -e
		print_section "JSON Output" "$CHART"
		echo $JSON_RESULT | python3 -m json.tool 2>/dev/null || echo $JSON_RESULT
	fi
fi

# Display completion message with visual flair
echo -e
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}    ${BOLD}${GREEN}Benchmark Complete!${NC} Thank you for using YABS ${ROCKET}          ${BLUE}║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"

# End of script

# reset locale settings
unset LC_ALL
