#!/bin/bash

# Data Transfer Test Script
# Tests: SCP, rsync, curl/wget download speeds
# Part of the comprehensive performance testing suite

SCRIPT_VERSION="v1.0.0"
TIMESTAMP=$(date '+%b-%d-%Y_%H-%M-%S')
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions and colors
source "$PROJECT_ROOT/lib/common_functions.sh"

# Define colors if not already defined
if [ -z "$BLUE" ]; then
    BLUE='\033[0;34m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
fi

echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e '#           Data Transfer Test Script                #'
echo -e '#                   '$SCRIPT_VERSION'                  #'
echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e

# Default values
OUTPUT_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results/${PRE_POST}_${TIMESTAMP}-Extended-Test-Suite-Results}"
TEST_TYPE=""
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PATH=""
LOCAL_FILE=""
TEST_FILE_SIZE="100M"  # Default test file size
PRE_POST=""
DOWNLOAD_URL=""
USE_PARALLEL=false
PARALLEL_STREAMS=4

# Function to display usage
usage() {
    echo "Usage: $0 -t <test_type> [options]"
    echo ""
    echo "Options:"
    echo "  -t <test_type>       Test type: scp, rsync, wget, curl, or all"
    echo "  -h <remote_host>     Remote host for scp/rsync tests"
    echo "  -u <remote_user>     Remote user for scp/rsync tests"
    echo "  -r <remote_path>     Remote path for scp/rsync tests"
    echo "  -l <local_file>      Local file to transfer (or will create test file)"
    echo "  -s <size>            Test file size if creating (e.g., 100M, 1G)"
    echo "  -d <download_url>    URL for wget/curl download tests"
    echo "  -p <pre|post>        Test phase: pre or post (for result naming)"
    echo "  -P                   Use parallel transfers where applicable"
    echo "  -n <streams>         Number of parallel streams (default: 4)"
    echo "  -H                   Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -t scp -h server.com -u user -r /tmp -s 100M -p pre"
    echo "  $0 -t wget -d http://speedtest.tele2.net/100MB.zip -p post"
    echo "  $0 -t all -h server.com -u user -r /tmp -d http://example.com/file.zip"
    exit 1
}

# Parse command line arguments
while getopts "t:h:u:r:l:s:d:p:Pn:H" opt; do
    case ${opt} in
        t )
            TEST_TYPE=$OPTARG
            ;;
        h )
            REMOTE_HOST=$OPTARG
            ;;
        u )
            REMOTE_USER=$OPTARG
            ;;
        r )
            REMOTE_PATH=$OPTARG
            ;;
        l )
            LOCAL_FILE=$OPTARG
            ;;
        s )
            TEST_FILE_SIZE=$OPTARG
            ;;
        d )
            DOWNLOAD_URL=$OPTARG
            ;;
        p )
            PRE_POST=$OPTARG
            ;;
        P )
            USE_PARALLEL=true
            ;;
        n )
            PARALLEL_STREAMS=$OPTARG
            ;;
        H )
            usage
            ;;
        \? )
            echo "Invalid option: -$OPTARG" 1>&2
            usage
            ;;
        : )
            echo "Option -$OPTARG requires an argument." 1>&2
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$TEST_TYPE" ]; then
    echo "Error: Test type is required (-t)"
    usage
fi

# Validate test-specific requirements
if [[ "$TEST_TYPE" == "scp" || "$TEST_TYPE" == "rsync" || "$TEST_TYPE" == "all" ]]; then
    if [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_PATH" ]; then
        echo "Error: Remote host (-h), user (-u), and path (-r) are required for scp/rsync tests"
        usage
    fi
fi

if [[ "$TEST_TYPE" == "wget" || "$TEST_TYPE" == "curl" ]] && [ -z "$DOWNLOAD_URL" ]; then
    if [ -z "$DOWNLOAD_URL" ]; then
        # Use default speed test URLs
        DOWNLOAD_URL="http://speedtest.tele2.net/100MB.zip"
    fi
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Set file prefix based on pre/post
FILE_PREFIX=""
if [ ! -z "$PRE_POST" ]; then
    FILE_PREFIX="${PRE_POST}_"
fi

# Function to create test file
create_test_file() {
    local size=$1
    local test_file="$OUTPUT_DIR/test_file_${TIMESTAMP}.dat"
    
    echo "Creating test file of size $size..."
    
    # Use dd to create a file with random data
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        dd if=/dev/urandom of="$test_file" bs=1048576 count=$(echo "$size" | sed 's/[^0-9]*//g') 2>/dev/null
    else
        # Linux
        dd if=/dev/urandom of="$test_file" bs=1M count=$(echo "$size" | sed 's/[^0-9]*//g') 2>/dev/null
    fi
    
    if [ -f "$test_file" ]; then
        echo "Test file created: $test_file"
        echo "$test_file"
    else
        echo "Error: Failed to create test file"
        return 1
    fi
}

# Function to calculate transfer speed
calculate_speed() {
    local bytes=$1
    local seconds=$2
    
    if [ -z "$seconds" ] || [ "$seconds" == "0" ]; then
        echo "0"
        return
    fi
    
    # Calculate MB/s
    local mbps=$(echo "scale=2; $bytes / 1048576 / $seconds" | bc 2>/dev/null || echo "0")
    echo "$mbps"
}

# Function to run SCP test
run_scp_test() {
    local output_file="${OUTPUT_DIR}/${FILE_PREFIX}scp_${REMOTE_HOST}_${TIMESTAMP}.txt"
    local json_file="${OUTPUT_DIR}/${FILE_PREFIX}scp_${REMOTE_HOST}_${TIMESTAMP}.json"
    
    echo "Running SCP transfer test..."
    echo "Remote: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
    
    # Create or use test file
    if [ -z "$LOCAL_FILE" ]; then
        LOCAL_FILE=$(create_test_file "$TEST_FILE_SIZE")
        if [ $? -ne 0 ]; then
            return 1
        fi
        CLEANUP_FILE=true
    else
        CLEANUP_FILE=false
    fi
    
    # Get file size
    local file_size=$(stat -f%z "$LOCAL_FILE" 2>/dev/null || stat -c%s "$LOCAL_FILE" 2>/dev/null)
    
    # Run SCP with timing
    echo "Uploading file..."
    local start_time=$(date +%s.%N)
    
    if [ "$USE_PARALLEL" = true ] && command -v pscp >/dev/null 2>&1; then
        # Use parallel SCP if available
        pscp -p $PARALLEL_STREAMS "$LOCAL_FILE" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/" > "$output_file" 2>&1
    else
        # Standard SCP
        scp -o ConnectTimeout=10 "$LOCAL_FILE" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/" > "$output_file" 2>&1
    fi
    
    local scp_result=$?
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    if [ $scp_result -eq 0 ]; then
        local speed=$(calculate_speed "$file_size" "$duration")
        
        # Create JSON output
        cat > "$json_file" <<EOF
{
    "test_type": "scp",
    "timestamp": "$TIMESTAMP",
    "remote_host": "$REMOTE_HOST",
    "direction": "upload",
    "file_size_bytes": $file_size,
    "duration_seconds": $duration,
    "speed_mbps": $speed,
    "parallel": $USE_PARALLEL,
    "status": "success"
}
EOF
        
        echo ""
        echo -e "${GREEN}✓ SCP upload completed successfully${NC}"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}  SCP UPLOAD RESULTS - $REMOTE_HOST${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}File Size:${NC}   $(echo "scale=2; $file_size / 1048576" | bc) MB"
        echo -e "  ${BOLD}Duration:${NC}    ${duration} seconds"
        echo -e "  ${BOLD}Speed:${NC}       ${GREEN}${speed} MB/s${NC}"
        [ "$USE_PARALLEL" = true ] && echo -e "  ${BOLD}Mode:${NC}        ${YELLOW}Parallel Transfer${NC}"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Clean up remote file
        ssh "${REMOTE_USER}@${REMOTE_HOST}" "rm -f ${REMOTE_PATH}/$(basename $LOCAL_FILE)" 2>/dev/null
    else
        echo "SCP transfer failed. Check $output_file for details."
        cat > "$json_file" <<EOF
{
    "test_type": "scp",
    "timestamp": "$TIMESTAMP",
    "remote_host": "$REMOTE_HOST",
    "status": "failed"
}
EOF
    fi
    
    # Cleanup test file if we created it
    if [ "$CLEANUP_FILE" = true ]; then
        rm -f "$LOCAL_FILE"
    fi
}

# Function to run rsync test
run_rsync_test() {
    local output_file="${OUTPUT_DIR}/${FILE_PREFIX}rsync_${REMOTE_HOST}_${TIMESTAMP}.txt"
    local json_file="${OUTPUT_DIR}/${FILE_PREFIX}rsync_${REMOTE_HOST}_${TIMESTAMP}.json"
    
    echo "Running rsync transfer test..."
    echo "Remote: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
    
    # Check if rsync is available
    if ! command -v rsync >/dev/null 2>&1; then
        echo "Error: rsync not found"
        return 1
    fi
    
    # Create or use test file
    if [ -z "$LOCAL_FILE" ]; then
        LOCAL_FILE=$(create_test_file "$TEST_FILE_SIZE")
        if [ $? -ne 0 ]; then
            return 1
        fi
        CLEANUP_FILE=true
    else
        CLEANUP_FILE=false
    fi
    
    # Get file size
    local file_size=$(stat -f%z "$LOCAL_FILE" 2>/dev/null || stat -c%s "$LOCAL_FILE" 2>/dev/null)
    
    # Run rsync with timing and progress
    echo "Synchronizing file..."
    local start_time=$(date +%s.%N)
    
    if [ "$USE_PARALLEL" = true ]; then
        # Use parallel rsync transfers
        rsync -avz --progress --stats -e "ssh -o ConnectTimeout=10" \
              --bwlimit=0 --inplace \
              "$LOCAL_FILE" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/" 2>&1 | tee "$output_file"
    else
        # Standard rsync
        rsync -avz --progress --stats -e "ssh -o ConnectTimeout=10" \
              "$LOCAL_FILE" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/" 2>&1 | tee "$output_file"
    fi
    
    local rsync_result=$?
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    if [ $rsync_result -eq 0 ]; then
        local speed=$(calculate_speed "$file_size" "$duration")
        
        # Extract transfer rate from rsync output if available
        local rsync_rate=$(grep -o "[0-9.]*MB/s" "$output_file" | tail -1)
        
        # Create JSON output
        cat > "$json_file" <<EOF
{
    "test_type": "rsync",
    "timestamp": "$TIMESTAMP",
    "remote_host": "$REMOTE_HOST",
    "direction": "upload",
    "file_size_bytes": $file_size,
    "duration_seconds": $duration,
    "speed_mbps": $speed,
    "rsync_reported_rate": "${rsync_rate:-N/A}",
    "compression": true,
    "status": "success"
}
EOF
        
        echo ""
        echo -e "${GREEN}✓ rsync completed successfully${NC}"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}  RSYNC RESULTS - $REMOTE_HOST${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}File Size:${NC}   $(echo "scale=2; $file_size / 1048576" | bc) MB"
        echo -e "  ${BOLD}Duration:${NC}    ${duration} seconds"
        echo -e "  ${BOLD}Speed:${NC}       ${GREEN}${speed} MB/s${NC}"
        [ ! -z "$rsync_rate" ] && echo -e "  ${BOLD}Rsync Rate:${NC}  ${YELLOW}$rsync_rate${NC}"
        echo -e "  ${BOLD}Compression:${NC} ${GREEN}Enabled${NC}"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Clean up remote file
        ssh "${REMOTE_USER}@${REMOTE_HOST}" "rm -f ${REMOTE_PATH}/$(basename $LOCAL_FILE)" 2>/dev/null
    else
        echo "rsync transfer failed. Check $output_file for details."
        cat > "$json_file" <<EOF
{
    "test_type": "rsync",
    "timestamp": "$TIMESTAMP",
    "remote_host": "$REMOTE_HOST",
    "status": "failed"
}
EOF
    fi
    
    # Cleanup test file if we created it
    if [ "$CLEANUP_FILE" = true ]; then
        rm -f "$LOCAL_FILE"
    fi
}

# Function to run wget test
run_wget_test() {
    local url=$1
    local output_file="${OUTPUT_DIR}/${FILE_PREFIX}wget_${TIMESTAMP}.txt"
    local json_file="${OUTPUT_DIR}/${FILE_PREFIX}wget_${TIMESTAMP}.json"
    local download_file="${OUTPUT_DIR}/wget_download_${TIMESTAMP}"
    
    echo "Running wget download test..."
    echo "URL: $url"
    
    # Check if wget is available
    if ! command -v wget >/dev/null 2>&1; then
        echo "Error: wget not found"
        return 1
    fi
    
    # Run wget with timing
    local start_time=$(date +%s.%N)
    
    if [ "$USE_PARALLEL" = true ] && command -v aria2c >/dev/null 2>&1; then
        # Use aria2c for parallel downloads
        aria2c -x $PARALLEL_STREAMS -s $PARALLEL_STREAMS -d "$OUTPUT_DIR" -o "$(basename $download_file)" \
               "$url" 2>&1 | tee "$output_file"
        local wget_result=$?
    else
        # Standard wget
        wget --progress=bar:force --tries=1 --timeout=30 -O "$download_file" "$url" 2>&1 | tee "$output_file"
        local wget_result=$?
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    if [ $wget_result -eq 0 ] && [ -f "$download_file" ]; then
        local file_size=$(stat -f%z "$download_file" 2>/dev/null || stat -c%s "$download_file" 2>/dev/null)
        local speed=$(calculate_speed "$file_size" "$duration")
        
        # Create JSON output
        cat > "$json_file" <<EOF
{
    "test_type": "wget",
    "timestamp": "$TIMESTAMP",
    "url": "$url",
    "file_size_bytes": $file_size,
    "duration_seconds": $duration,
    "speed_mbps": $speed,
    "parallel": $USE_PARALLEL,
    "status": "success"
}
EOF
        
        echo ""
        echo -e "${GREEN}✓ wget download completed successfully${NC}"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}  WGET DOWNLOAD RESULTS${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}URL:${NC}         $(echo $url | cut -c1-50)..."
        echo -e "  ${BOLD}File Size:${NC}   $(echo "scale=2; $file_size / 1048576" | bc) MB"
        echo -e "  ${BOLD}Duration:${NC}    ${duration} seconds"
        echo -e "  ${BOLD}Speed:${NC}       ${GREEN}${speed} MB/s${NC}"
        local mbps=$(echo "scale=2; $speed * 8" | bc)
        echo -e "  ${BOLD}Bandwidth:${NC}   ${YELLOW}${mbps} Mbps${NC}"
        [ "$USE_PARALLEL" = true ] && echo -e "  ${BOLD}Mode:${NC}        ${YELLOW}Parallel Download (aria2c)${NC}"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Cleanup download
        rm -f "$download_file"
    else
        echo "wget download failed. Check $output_file for details."
        cat > "$json_file" <<EOF
{
    "test_type": "wget",
    "timestamp": "$TIMESTAMP",
    "url": "$url",
    "status": "failed"
}
EOF
    fi
}

# Function to run curl test
run_curl_test() {
    local url=$1
    local output_file="${OUTPUT_DIR}/${FILE_PREFIX}curl_${TIMESTAMP}.txt"
    local json_file="${OUTPUT_DIR}/${FILE_PREFIX}curl_${TIMESTAMP}.json"
    local download_file="${OUTPUT_DIR}/curl_download_${TIMESTAMP}"
    
    echo "Running curl download test..."
    echo "URL: $url"
    
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        echo "Error: curl not found"
        return 1
    fi
    
    # Run curl with timing and progress
    local start_time=$(date +%s.%N)
    
    # curl with detailed timing information
    curl -L --progress-bar -o "$download_file" -w "@-" "$url" <<'EOF' 2>&1 | tee "$output_file"
\n
Download Information:
--------------------
URL: %{url_effective}
HTTP Code: %{http_code}
Connect Time: %{time_connect}s
Start Transfer: %{time_starttransfer}s
Total Time: %{time_total}s
Download Size: %{size_download} bytes
Speed: %{speed_download} bytes/sec
EOF
    
    local curl_result=$?
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    if [ $curl_result -eq 0 ] && [ -f "$download_file" ]; then
        local file_size=$(stat -f%z "$download_file" 2>/dev/null || stat -c%s "$download_file" 2>/dev/null)
        local speed=$(calculate_speed "$file_size" "$duration")
        
        # Extract curl's reported speed
        local curl_speed=$(grep "Speed:" "$output_file" | awk '{print $2}')
        local curl_speed_mbps=$(echo "scale=2; $curl_speed / 1048576" | bc 2>/dev/null || echo "0")
        
        # Create JSON output
        cat > "$json_file" <<EOF
{
    "test_type": "curl",
    "timestamp": "$TIMESTAMP",
    "url": "$url",
    "file_size_bytes": $file_size,
    "duration_seconds": $duration,
    "speed_mbps": $speed,
    "curl_reported_speed_mbps": $curl_speed_mbps,
    "status": "success"
}
EOF
        
        echo ""
        echo -e "${GREEN}✓ curl download completed successfully${NC}"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}  CURL DOWNLOAD RESULTS${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}URL:${NC}         $(echo $url | cut -c1-50)..."
        echo -e "  ${BOLD}File Size:${NC}   $(echo "scale=2; $file_size / 1048576" | bc) MB"
        echo -e "  ${BOLD}Duration:${NC}    ${duration} seconds"
        echo -e "  ${BOLD}Speed:${NC}       ${GREEN}${speed} MB/s${NC}"
        echo -e "  ${BOLD}Curl Speed:${NC}  ${YELLOW}${curl_speed_mbps} MB/s${NC}"
        local mbps=$(echo "scale=2; $speed * 8" | bc)
        echo -e "  ${BOLD}Bandwidth:${NC}   ${YELLOW}${mbps} Mbps${NC}"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Cleanup download
        rm -f "$download_file"
    else
        echo "curl download failed. Check $output_file for details."
        cat > "$json_file" <<EOF
{
    "test_type": "curl",
    "timestamp": "$TIMESTAMP",
    "url": "$url",
    "status": "failed"
}
EOF
    fi
}

# Main execution
echo "Starting data transfer tests..."
echo "Timestamp: $TIMESTAMP"
echo ""

case $TEST_TYPE in
    "scp")
        run_scp_test
        ;;
    "rsync")
        run_rsync_test
        ;;
    "wget")
        run_wget_test "$DOWNLOAD_URL"
        ;;
    "curl")
        run_curl_test "$DOWNLOAD_URL"
        ;;
    "all")
        if [ ! -z "$REMOTE_HOST" ]; then
            run_scp_test
            echo ""
            run_rsync_test
            echo ""
        fi
        if [ ! -z "$DOWNLOAD_URL" ]; then
            run_wget_test "$DOWNLOAD_URL"
            echo ""
            run_curl_test "$DOWNLOAD_URL"
        fi
        ;;
    *)
        echo "Error: Invalid test type. Use scp, rsync, wget, curl, or all"
        usage
        ;;
esac

echo ""
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  ✓ ALL TRANSFER TESTS COMPLETED${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Results saved in:${NC}"
echo -e "  $OUTPUT_DIR"
echo ""