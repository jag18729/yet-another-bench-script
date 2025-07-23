#!/bin/bash

# Network Performance Test Script
# Tests: ping, traceroute, iperf3
# Part of the comprehensive performance testing suite

SCRIPT_VERSION="v1.0.0"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
source "$PROJECT_ROOT/lib/common_functions.sh"

echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e '#           Network Performance Test Script          #'
echo -e '#                   '$SCRIPT_VERSION'                  #'
echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e

# Default values
DEFAULT_PING_COUNT=100
DEFAULT_TRACEROUTE_HOPS=30
DEFAULT_IPERF_DURATION=60
OUTPUT_DIR="$PROJECT_ROOT/results/network_test_results"
TEST_TYPE=""
DESTINATION=""
IPERF_SERVER=""
PING_COUNT=$DEFAULT_PING_COUNT
TRACEROUTE_HOPS=$DEFAULT_TRACEROUTE_HOPS
IPERF_DURATION=$DEFAULT_IPERF_DURATION
PRE_POST=""

# Function to display usage
usage() {
    echo "Usage: $0 -t <test_type> -d <destination> [-s <iperf_server>] [-c <ping_count>] [-m <max_hops>] [-i <iperf_duration>] [-p <pre|post>]"
    echo ""
    echo "Options:"
    echo "  -t <test_type>       Test type: ping, traceroute, iperf, or all"
    echo "  -d <destination>     Destination IP or hostname for ping/traceroute"
    echo "  -s <iperf_server>    iPerf server IP (required for iperf test)"
    echo "  -c <ping_count>      Number of ping packets (default: 100)"
    echo "  -m <max_hops>        Maximum hops for traceroute (default: 30)"
    echo "  -i <iperf_duration>  iPerf test duration in seconds (default: 60)"
    echo "  -p <pre|post>        Test phase: pre or post (for result naming)"
    echo "  -h                   Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -t all -d 8.8.8.8 -s 192.168.1.100 -p pre"
    echo "  $0 -t ping -d google.com -c 50 -p post"
    echo "  $0 -t iperf -s 10.0.0.1 -i 30"
    exit 1
}

# Parse command line arguments
while getopts "t:d:s:c:m:i:p:h" opt; do
    case ${opt} in
        t )
            TEST_TYPE=$OPTARG
            ;;
        d )
            DESTINATION=$OPTARG
            ;;
        s )
            IPERF_SERVER=$OPTARG
            ;;
        c )
            PING_COUNT=$OPTARG
            ;;
        m )
            TRACEROUTE_HOPS=$OPTARG
            ;;
        i )
            IPERF_DURATION=$OPTARG
            ;;
        p )
            PRE_POST=$OPTARG
            ;;
        h )
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

if [[ "$TEST_TYPE" == "ping" || "$TEST_TYPE" == "traceroute" || "$TEST_TYPE" == "all" ]] && [ -z "$DESTINATION" ]; then
    echo "Error: Destination is required for ping/traceroute tests (-d)"
    usage
fi

if [[ "$TEST_TYPE" == "iperf" || "$TEST_TYPE" == "all" ]] && [ -z "$IPERF_SERVER" ]; then
    echo "Error: iPerf server is required for iperf tests (-s)"
    usage
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Set file prefix based on pre/post
FILE_PREFIX=""
if [ ! -z "$PRE_POST" ]; then
    FILE_PREFIX="${PRE_POST}_"
fi

# Function to run ping test
run_ping_test() {
    local dest=$1
    local output_file="${OUTPUT_DIR}/${FILE_PREFIX}ping_${dest}_${TIMESTAMP}.txt"
    local json_file="${OUTPUT_DIR}/${FILE_PREFIX}ping_${dest}_${TIMESTAMP}.json"
    
    echo "Running ping test to $dest..."
    echo "Output will be saved to: $output_file"
    
    # Run ping and save raw output
    ping -c $PING_COUNT "$dest" > "$output_file" 2>&1
    
    # Parse results and create JSON
    if [ -f "$output_file" ]; then
        # Extract statistics
        local transmitted=$(grep "packets transmitted" "$output_file" | awk '{print $1}')
        local received=$(grep "packets transmitted" "$output_file" | awk '{print $4}')
        local loss=$(grep "packets transmitted" "$output_file" | awk -F'[,%]' '{print $3}' | tr -d ' ')
        local min_avg_max=$(grep "min/avg/max" "$output_file" | awk -F'=' '{print $2}' | tr -d ' ms')
        
        if [ ! -z "$min_avg_max" ]; then
            local min=$(echo "$min_avg_max" | cut -d'/' -f1)
            local avg=$(echo "$min_avg_max" | cut -d'/' -f2)
            local max=$(echo "$min_avg_max" | cut -d'/' -f3)
            local mdev=$(echo "$min_avg_max" | cut -d'/' -f4)
            
            # Create JSON output
            cat > "$json_file" <<EOF
{
    "test_type": "ping",
    "timestamp": "$TIMESTAMP",
    "destination": "$dest",
    "packets_transmitted": $transmitted,
    "packets_received": $received,
    "packet_loss_percent": $loss,
    "rtt_min_ms": $min,
    "rtt_avg_ms": $avg,
    "rtt_max_ms": $max,
    "rtt_mdev_ms": $mdev
}
EOF
            echo "Ping test completed. Results saved to $output_file and $json_file"
            echo "Summary: $received/$transmitted packets, $loss% loss, avg RTT: ${avg}ms"
        else
            echo "Warning: Could not parse ping statistics"
        fi
    fi
}

# Function to run traceroute test
run_traceroute_test() {
    local dest=$1
    local output_file="${OUTPUT_DIR}/${FILE_PREFIX}traceroute_${dest}_${TIMESTAMP}.txt"
    local json_file="${OUTPUT_DIR}/${FILE_PREFIX}traceroute_${dest}_${TIMESTAMP}.json"
    
    echo "Running traceroute test to $dest..."
    echo "Output will be saved to: $output_file"
    
    # Check if traceroute is available, otherwise use tracepath
    if command -v traceroute >/dev/null 2>&1; then
        traceroute -m $TRACEROUTE_HOPS "$dest" > "$output_file" 2>&1
    elif command -v tracepath >/dev/null 2>&1; then
        tracepath -m $TRACEROUTE_HOPS "$dest" > "$output_file" 2>&1
    else
        echo "Error: Neither traceroute nor tracepath found"
        return 1
    fi
    
    # Create basic JSON output
    local hop_count=$(grep -E "^[[:space:]]*[0-9]+" "$output_file" | wc -l)
    cat > "$json_file" <<EOF
{
    "test_type": "traceroute",
    "timestamp": "$TIMESTAMP",
    "destination": "$dest",
    "max_hops": $TRACEROUTE_HOPS,
    "hops_found": $hop_count,
    "output_file": "$output_file"
}
EOF
    
    echo "Traceroute test completed. Results saved to $output_file and $json_file"
}

# Function to run iperf test
run_iperf_test() {
    local server=$1
    local output_file="${OUTPUT_DIR}/${FILE_PREFIX}iperf_${server}_${TIMESTAMP}.txt"
    local json_file="${OUTPUT_DIR}/${FILE_PREFIX}iperf_${server}_${TIMESTAMP}.json"
    
    echo "Running iperf3 test to $server..."
    echo "Output will be saved to: $output_file"
    
    # Check if iperf3 is available
    if ! command -v iperf3 >/dev/null 2>&1; then
        echo "Error: iperf3 not found. Please install iperf3."
        return 1
    fi
    
    # Run iperf3 test with JSON output
    iperf3 -c "$server" -t $IPERF_DURATION -i 1 -J > "$json_file" 2>"$output_file"
    
    # Extract summary from JSON if successful
    if [ -s "$json_file" ] && grep -q "bits_per_second" "$json_file"; then
        # Extract key metrics using basic tools
        local bitrate=$(grep -o '"bits_per_second"[[:space:]]*:[[:space:]]*[0-9.]*' "$json_file" | tail -1 | awk -F':' '{print $2}' | tr -d ' ')
        local bitrate_mbps=$(echo "scale=2; $bitrate / 1000000" | bc 2>/dev/null || echo "N/A")
        
        echo "iPerf3 test completed. Results saved to $json_file"
        echo "Summary: Average bitrate: ${bitrate_mbps} Mbps"
    else
        echo "Warning: iPerf3 test may have failed. Check $output_file for errors."
    fi
}

# Main execution
echo "Starting network performance tests..."
echo "Test type: $TEST_TYPE"
echo "Timestamp: $TIMESTAMP"
echo ""

case $TEST_TYPE in
    "ping")
        run_ping_test "$DESTINATION"
        ;;
    "traceroute")
        run_traceroute_test "$DESTINATION"
        ;;
    "iperf")
        run_iperf_test "$IPERF_SERVER"
        ;;
    "all")
        run_ping_test "$DESTINATION"
        echo ""
        run_traceroute_test "$DESTINATION"
        echo ""
        if [ ! -z "$IPERF_SERVER" ]; then
            run_iperf_test "$IPERF_SERVER"
        fi
        ;;
    *)
        echo "Error: Invalid test type. Use ping, traceroute, iperf, or all"
        usage
        ;;
esac

echo ""
echo "All tests completed. Results are saved in the $OUTPUT_DIR directory."