#!/bin/bash

# Network Performance Test Script
# Tests: ping, traceroute, iperf3 (with reverse and parallel options)
# Part of the comprehensive performance testing suite

SCRIPT_VERSION="v2.0.0"
TIMESTAMP=$(date '+%b-%d-%Y_%H-%M-%S')
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
source "$PROJECT_ROOT/lib/common_functions.sh"

echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e '#           Network Performance Test Script          #'
echo -e '#                   '$SCRIPT_VERSION'                            #'
echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e

# Default values
DEFAULT_PING_COUNT=100
DEFAULT_TRACEROUTE_HOPS=30
DEFAULT_IPERF_DURATION=60
OUTPUT_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results/${PRE_POST}_${TIMESTAMP}-Extended-Test-Suite-Results}"
TEST_TYPE=""
DESTINATION=""
IPERF_SERVER=""
PING_COUNT=${PING_COUNT:-$DEFAULT_PING_COUNT}
TRACEROUTE_HOPS=${TRACE_HOPS:-$DEFAULT_TRACEROUTE_HOPS}
IPERF_DURATION=${IPERF_TIME:-$DEFAULT_IPERF_DURATION}
IPERF_REVERSE=${IPERF_REVERSE:-false}
IPERF_PARALLEL=${IPERF_PARALLEL:-1}
PRE_POST=""

# Function to display usage
usage() {
    echo "Usage: $0 -t <test_type> -d <destination> [-s <iperf_server>] [options]"
    echo ""
    echo "Options:"
    echo "  -t <test_type>       Test type: ping, traceroute, iperf, or all"
    echo "  -d <destination>     Destination IP or hostname for ping/traceroute"
    echo "  -s <iperf_server>    iPerf server IP (required for iperf test)"
    echo "  -c <ping_count>      Number of ping packets (default: 100)"
    echo "  -m <max_hops>        Maximum hops for traceroute (default: 30)"
    echo "  -i <iperf_duration>  iPerf test duration in seconds (default: 60)"
    echo "  -p <pre|post>        Test phase: pre or post (for result naming)"
    echo "  -R                   Run iPerf in reverse mode (server sends)"
    echo "  -P <streams>         Number of parallel iPerf streams (default: 1)"
    echo "  -h                   Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -t all -d 8.8.8.8 -s 192.168.1.100 -p pre"
    echo "  $0 -t ping -d google.com -c 50 -p post"
    echo "  $0 -t iperf -s 10.0.0.1 -i 30 -R -P 4"
    echo ""
    echo "Environment variables:"
    echo "  IPERF_REVERSE        Set to 'true' for reverse mode"
    echo "  IPERF_PARALLEL       Number of parallel streams"
    echo "  IPERF_TIME          Test duration (overrides -i)"
    exit 1
}

# Parse command line arguments
while getopts "t:d:s:c:m:i:p:P:Rh" opt; do
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
        R )
            IPERF_REVERSE=true
            ;;
        P )
            IPERF_PARALLEL=$OPTARG
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
            IFS='/' read -r min avg max stddev <<< "$min_avg_max"
            
            # Create JSON output
            cat > "$json_file" <<EOF
{
    "test_type": "ping",
    "destination": "$dest",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "packets_transmitted": $transmitted,
    "packets_received": $received,
    "packet_loss_percent": $loss,
    "rtt_min_ms": $min,
    "rtt_avg_ms": $avg,
    "rtt_max_ms": $max,
    "rtt_stddev_ms": ${stddev:-0},
    "ping_count": $PING_COUNT,
    "output_file": "$output_file"
}
EOF
            echo ""
            echo -e "${GREEN}✓ Ping test completed${NC}"
            echo ""
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BOLD}  PING RESULTS - $dest${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo -e "  ${BOLD}Packets:${NC}     $received/$transmitted (${GREEN}$loss% loss${NC})"
            echo -e "  ${BOLD}Latency:${NC}     ${YELLOW}Min: ${min}ms${NC} | ${GREEN}Avg: ${avg}ms${NC} | ${RED}Max: ${max}ms${NC}"
            echo -e "  ${BOLD}Std Dev:${NC}     ${stddev}ms"
            echo ""
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
        else
            echo "Warning: Unable to parse ping results. Check $output_file"
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
    "destination": "$dest",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "max_hops": $TRACEROUTE_HOPS,
    "hops_found": $hop_count,
    "output_file": "$output_file"
}
EOF

    echo "Traceroute test completed. Results saved to $output_file and $json_file"
}

# Function to run TCP iperf test
run_iperf_test() {
    local server=$1
    local output_file="${OUTPUT_DIR}/${FILE_PREFIX}iperf_tcp_${server}_${TIMESTAMP}.txt"
    local json_file="${OUTPUT_DIR}/${FILE_PREFIX}iperf_tcp_${server}_${TIMESTAMP}.json"
    
    echo "Running iperf3 TCP test to $server..."
    [ "$IPERF_REVERSE" = true ] && echo "Mode: Reverse (server sends)"
    [ "$IPERF_PARALLEL" -gt 1 ] && echo "Parallel streams: $IPERF_PARALLEL"
    echo "Duration: ${IPERF_DURATION}s"
    echo "Output will be saved to: $output_file"
    
    # Check if iperf3 is available
    if ! command -v iperf3 >/dev/null 2>&1; then
        echo "Error: iperf3 not found. Please install iperf3."
        return 1
    fi
    
    # Build iperf3 command
    local iperf_cmd="iperf3 -c $server -t $IPERF_DURATION -i 1 -J"
    [ "$IPERF_REVERSE" = true ] && iperf_cmd="$iperf_cmd -R"
    [ "$IPERF_PARALLEL" -gt 1 ] && iperf_cmd="$iperf_cmd -P $IPERF_PARALLEL"
    
    # Run iperf3 TCP test with JSON output
    eval "$iperf_cmd" > "$json_file" 2>"$output_file"
    
    # Extract summary from JSON if successful
    if [ -s "$json_file" ] && grep -q "bits_per_second" "$json_file"; then
        # Extract key metrics using basic tools
        local bitrate=$(grep -o '"bits_per_second"[[:space:]]*:[[:space:]]*[0-9.]*' "$json_file" | tail -1 | awk -F':' '{print $2}' | tr -d ' ')
        local bitrate_mbps=$(echo "scale=2; $bitrate / 1000000" | bc 2>/dev/null || echo "N/A")
        
        echo ""
        echo -e "${GREEN}✓ iPerf3 TCP test completed${NC}"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}  iPERF3 TCP RESULTS - $server${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}Throughput:${NC}  ${GREEN}${bitrate_mbps} Mbps${NC}"
        echo -e "  ${BOLD}Duration:${NC}    ${IPERF_DURATION} seconds"
        [ "$IPERF_REVERSE" = true ] && echo -e "  ${BOLD}Mode:${NC}        ${YELLOW}Reverse (Server → Client)${NC}"
        [ "$IPERF_PARALLEL" -gt 1 ] && echo -e "  ${BOLD}Streams:${NC}     ${IPERF_PARALLEL} parallel"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    else
        echo "Warning: iPerf3 TCP test may have failed. Check $output_file for errors."
    fi
    
    # Also run UDP test for jitter and packet loss
    run_iperf_udp_test "$server"
}

# Function to run UDP iperf test
run_iperf_udp_test() {
    local server=$1
    local output_file="${OUTPUT_DIR}/${FILE_PREFIX}iperf_udp_${server}_${TIMESTAMP}.txt"
    local json_file="${OUTPUT_DIR}/${FILE_PREFIX}iperf_udp_${server}_${TIMESTAMP}.json"
    
    echo ""
    echo "Running iperf3 UDP test to $server..."
    [ "$IPERF_REVERSE" = true ] && echo "Mode: Reverse (server sends)"
    [ "$IPERF_PARALLEL" -gt 1 ] && echo "Parallel streams: $IPERF_PARALLEL"
    echo "Output will be saved to: $output_file"
    
    # Build iperf3 UDP command
    local iperf_cmd="iperf3 -c $server -u -b 50M -t $IPERF_DURATION -i 1 -J"
    [ "$IPERF_REVERSE" = true ] && iperf_cmd="$iperf_cmd -R"
    [ "$IPERF_PARALLEL" -gt 1 ] && iperf_cmd="$iperf_cmd -P $IPERF_PARALLEL"
    
    # Run iperf3 UDP test with JSON output
    eval "$iperf_cmd" > "$json_file" 2>"$output_file"
    
    # Extract UDP-specific metrics from JSON if successful
    if [ -s "$json_file" ] && grep -q "bits_per_second" "$json_file"; then
        # Extract jitter and packet loss using jq if available
        if command -v jq >/dev/null 2>&1; then
            local jitter=$(jq -r '.end.sum.jitter_ms' "$json_file" 2>/dev/null || echo "N/A")
            local lost_packets=$(jq -r '.end.sum.lost_packets' "$json_file" 2>/dev/null || echo "N/A")
            local packets=$(jq -r '.end.sum.packets' "$json_file" 2>/dev/null || echo "N/A")
            local bitrate=$(jq -r '.end.sum.bits_per_second' "$json_file" 2>/dev/null || echo "N/A")
            
            if [[ "$packets" != "N/A" && "$lost_packets" != "N/A" && "$packets" != "0" ]]; then
                local loss_percent=$(echo "scale=2; $lost_packets * 100 / $packets" | bc 2>/dev/null || echo "N/A")
                echo ""
                echo -e "${GREEN}✓ iPerf3 UDP test completed${NC}"
                echo ""
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${BOLD}  iPERF3 UDP RESULTS - $server${NC}"
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo ""
                echo -e "  ${BOLD}Throughput:${NC}  ${GREEN}$(echo "scale=2; $bitrate / 1000000" | bc) Mbps${NC}"
                echo -e "  ${BOLD}Jitter:${NC}      ${YELLOW}${jitter}ms${NC}"
                local loss_color="${GREEN}"
                [ $(echo "$loss_percent > 0.5" | bc) -eq 1 ] && loss_color="${YELLOW}"
                [ $(echo "$loss_percent > 1.0" | bc) -eq 1 ] && loss_color="${RED}"
                echo -e "  ${BOLD}Packet Loss:${NC} ${loss_color}${loss_percent}%${NC}"
                echo -e "  ${BOLD}Duration:${NC}    ${IPERF_DURATION} seconds"
                [ "$IPERF_REVERSE" = true ] && echo -e "  ${BOLD}Mode:${NC}        ${YELLOW}Reverse (Server → Client)${NC}"
                echo ""
                echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo ""
            else
                echo "iPerf3 UDP test completed. Results saved to $json_file"
            fi
        else
            echo "iPerf3 UDP test completed. Results saved to $json_file"
        fi
    else
        echo "Warning: iPerf3 UDP test may have failed. Check $output_file for errors."
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
        echo "Error: Invalid test type: $TEST_TYPE"
        usage
        ;;
esac

echo ""
echo "All network tests completed."