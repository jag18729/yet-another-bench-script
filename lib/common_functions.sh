#!/bin/bash

# Common functions library for Performance Test Suite
# Version: 1.0.0

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color
export BOLD='\033[1m'

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print info messages
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root
is_root() {
    [ "$EUID" -eq 0 ]
}

# Function to get OS type
get_os_type() {
    case "$(uname -s)" in
        Linux*)     echo "linux";;
        Darwin*)    echo "macos";;
        CYGWIN*)    echo "cygwin";;
        MINGW*)     echo "mingw";;
        *)          echo "unknown";;
    esac
}

# Function to create timestamp
get_timestamp() {
    date '+%Y-%m-%d_%H-%M-%S'
}

# Function to create short timestamp
get_short_timestamp() {
    date '+%Y%m%d-%H%M%S'
}

# Function to ensure directory exists
ensure_dir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            print_error "Failed to create directory: $dir"
            return 1
        }
    fi
}

# Function to validate IP address
is_valid_ip() {
    local ip=$1
    local valid_ip_regex="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
    
    if [[ $ip =~ $valid_ip_regex ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate hostname
is_valid_hostname() {
    local hostname=$1
    local valid_hostname_regex="^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$"
    
    if [[ $hostname =~ $valid_hostname_regex ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check network connectivity
check_network() {
    local test_host=${1:-"8.8.8.8"}
    local timeout=${2:-2}
    
    if ping -c 1 -W "$timeout" "$test_host" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to format bytes to human readable
format_bytes() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while (( $(echo "$bytes >= 1024" | bc -l) )) && (( unit < ${#units[@]} - 1 )); do
        bytes=$(echo "scale=2; $bytes / 1024" | bc)
        ((unit++))
    done
    
    echo "${bytes} ${units[$unit]}"
}

# Function to calculate percentage
calculate_percentage() {
    local value=$1
    local total=$2
    
    if [ "$total" -eq 0 ]; then
        echo "0"
    else
        echo "scale=2; ($value * 100) / $total" | bc
    fi
}

# Function to create JSON output
create_json() {
    local -n json_data=$1
    local output_file=$2
    
    {
        echo "{"
        local first=true
        for key in "${!json_data[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            echo -n "  \"$key\": \"${json_data[$key]}\""
        done
        echo ""
        echo "}"
    } > "$output_file"
}

# Function to log messages
log_message() {
    local log_file=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] $message" >> "$log_file"
}

# Function to display a progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=${3:-50}
    
    local progress=$((current * width / total))
    local percentage=$((current * 100 / total))
    
    printf "\r["
    printf "%${progress}s" | tr ' ' '='
    printf "%$((width - progress))s" | tr ' ' '-'
    printf "] %d%%" "$percentage"
    
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# Function to check required dependencies
check_required_deps() {
    local -a deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Export functions
export -f print_color print_error print_success print_warning print_info
export -f command_exists is_root get_os_type
export -f get_timestamp get_short_timestamp ensure_dir
export -f is_valid_ip is_valid_hostname check_network
export -f format_bytes calculate_percentage create_json
export -f log_message show_progress check_required_deps