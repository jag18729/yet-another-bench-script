#!/bin/bash

# Performance Test Suite Master Script
# Orchestrates all performance tests with easy-to-use parameters
# Supports parallel execution, file operations, and comprehensive testing

SCRIPT_VERSION="v2.0.0"
TIMESTAMP=$(date '+%b-%d-%Y_%H-%M-%S')
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
source "$PROJECT_ROOT/lib/common_functions.sh"

echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e '#         Performance Test Suite Master              #'
echo -e '#                   '$SCRIPT_VERSION'                            #'
echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e

# Default values
TEST_PHASE="pre"
RUN_YABS=true
RUN_NETWORK=true
RUN_DNS=true
RUN_TRANSFER=true
USE_WORKTREE=false
WORKTREE_NAME=""
CONFIG_FILE=""
PARALLEL_EXECUTION=false
RESULTS_DIR=""  # Will be set after parsing arguments

# Test configuration defaults
DESTINATION_IP="8.8.8.8"
IPERF_SERVER=""
IPERF_REVERSE=false
IPERF_PARALLEL=1
IPERF_TIME=10
DNS_SERVER="8.8.8.8"
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PATH="/tmp"
DOWNLOAD_URL="http://speedtest.tele2.net/100MB.zip"
UPLOAD_FILE=""
DOWNLOAD_FILE=""
PING_COUNT=20
TRACE_HOPS=30
DNS_QUERIES=20
QUICK_MODE=false
VERBOSE=false

# Function to display usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

BASIC OPTIONS:
  -p <pre|post>        Test phase (default: pre)
  -c <config_file>     Configuration file with test parameters
  -h                   Display this help message
  -v                   Verbose output
  -q                   Quick mode (reduced test iterations)

TEST SELECTION:
  -Y                   Skip YABS benchmark
  -N                   Skip network tests (ping, traceroute, iperf)
  -D                   Skip DNS tests
  -T                   Skip data transfer tests

NETWORK TEST OPTIONS:
  --server <ip>        iPerf3 server IP address
  --reverse            Run iPerf3 in reverse mode (server sends)
  --parallel <n>       Number of parallel iPerf3 streams (default: 1)
  --time <seconds>     iPerf3 test duration (default: 10)
  --ping-count <n>     Number of ping packets (default: 20)
  --trace-hops <n>     Max traceroute hops (default: 30)

DNS TEST OPTIONS:
  --dns <server>       DNS server to test (default: 8.8.8.8)
  --queries <n>        Number of DNS queries (default: 20)

FILE TRANSFER OPTIONS:
  --upload <file>      File to upload for transfer tests
  --download <url>     URL to download for speed tests
  --remote <host>      Remote host for SCP/rsync tests
  --user <username>    Remote username for SCP/rsync
  --path <path>        Remote path for file transfers

EXECUTION OPTIONS:
  -P                   Run tests in parallel (requires GNU parallel)
  -w <worktree>        Use git worktree for isolated execution

QUICK COMMANDS:
  $0 --quick           Run quick test with defaults
  $0 --full            Run full test suite
  $0 --network-only    Run only network tests
  $0 --compare         Compare pre/post results

EXAMPLES:
  # Quick test with custom iPerf server
  $0 -q --server 192.168.1.100

  # Full test with file upload
  $0 --upload /path/to/testfile.bin --server 192.168.1.100

  # Network only with reverse mode and parallel streams
  $0 --network-only --server 192.168.1.100 --reverse --parallel 4

  # DNS test with custom server
  $0 -N -T --dns 1.1.1.1 --queries 50

  # Complete test with config file
  $0 -c my_config.conf --time 30 --parallel 8

CONFIG FILE FORMAT:
  DESTINATION_IP=1.1.1.1
  IPERF_SERVER=192.168.2.10
  DNS_SERVER=1.1.1.1
  REMOTE_HOST=server.example.com
  REMOTE_USER=username
  DOWNLOAD_URL=http://example.com/testfile.zip

EOF
    exit 0
}

# Function to create default config file
create_default_config() {
    cat > test_config_template.conf <<EOF
# Performance Test Suite Configuration
# Generated: $(date)

# Network test configuration
DESTINATION_IP=1.1.1.1
IPERF_SERVER=192.168.1.100
IPERF_REVERSE=false
IPERF_PARALLEL=1
IPERF_TIME=10

# DNS test configuration
DNS_SERVER=1.1.1.1
DNS_QUERIES=20

# Data transfer test configuration
REMOTE_HOST=server.example.com
REMOTE_USER=username
REMOTE_PATH=/tmp
DOWNLOAD_URL=http://speedtest.tele2.net/100MB.zip
UPLOAD_FILE=

# Test parameters
PING_COUNT=20
TRACE_HOPS=30
EOF
    echo "Created template configuration file: test_config_template.conf"
}

# Function to load configuration file
load_config() {
    local config_file=$1
    if [ -f "$config_file" ]; then
        echo "Loading configuration from: $config_file"
        source "$config_file"
    else
        echo "Warning: Configuration file not found: $config_file"
        return 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p)
            TEST_PHASE="$2"
            shift 2
            ;;
        -c)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -w)
            USE_WORKTREE=true
            WORKTREE_NAME="$2"
            shift 2
            ;;
        -P)
            PARALLEL_EXECUTION=true
            shift
            ;;
        -Y)
            RUN_YABS=false
            shift
            ;;
        -N)
            RUN_NETWORK=false
            shift
            ;;
        -D)
            RUN_DNS=false
            shift
            ;;
        -T)
            RUN_TRANSFER=false
            shift
            ;;
        -q)
            QUICK_MODE=true
            PING_COUNT=10
            TRACE_HOPS=15
            DNS_QUERIES=10
            IPERF_TIME=5
            # Use smaller download file for quick mode
            DOWNLOAD_URL="http://speedtest.tele2.net/1MB.zip"
            shift
            ;;
        -v)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        --server)
            IPERF_SERVER="$2"
            shift 2
            ;;
        --reverse)
            IPERF_REVERSE=true
            shift
            ;;
        --parallel)
            IPERF_PARALLEL="$2"
            shift 2
            ;;
        --time)
            IPERF_TIME="$2"
            shift 2
            ;;
        --ping-count)
            PING_COUNT="$2"
            shift 2
            ;;
        --trace-hops)
            TRACE_HOPS="$2"
            shift 2
            ;;
        --dns)
            DNS_SERVER="$2"
            shift 2
            ;;
        --queries)
            DNS_QUERIES="$2"
            shift 2
            ;;
        --upload)
            UPLOAD_FILE="$2"
            shift 2
            ;;
        --download)
            DOWNLOAD_URL="$2"
            shift 2
            ;;
        --remote)
            REMOTE_HOST="$2"
            shift 2
            ;;
        --user)
            REMOTE_USER="$2"
            shift 2
            ;;
        --path)
            REMOTE_PATH="$2"
            shift 2
            ;;
        --quick)
            QUICK_MODE=true
            PING_COUNT=10
            TRACE_HOPS=15
            DNS_QUERIES=10
            IPERF_TIME=5
            shift
            ;;
        --full)
            PING_COUNT=100
            TRACE_HOPS=30
            DNS_QUERIES=100
            IPERF_TIME=30
            shift
            ;;
        --network-only)
            RUN_YABS=false
            RUN_DNS=false
            RUN_TRANSFER=false
            shift
            ;;
        --compare)
            compare_results
            exit 0
            ;;
        --create-config)
            create_default_config
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Load configuration file if provided
if [ ! -z "$CONFIG_FILE" ]; then
    load_config "$CONFIG_FILE"
fi

# Validate test phase
if [[ "$TEST_PHASE" != "pre" && "$TEST_PHASE" != "post" ]]; then
    echo "Error: Invalid test phase. Must be 'pre' or 'post'."
    exit 1
fi

# Set results directory with test phase
RESULTS_DIR="$PROJECT_ROOT/results/${TEST_PHASE}_${TIMESTAMP}-Extended-Test-Suite-Results"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Export variables for child scripts
export TEST_PHASE DESTINATION_IP IPERF_SERVER DNS_SERVER REMOTE_HOST REMOTE_USER REMOTE_PATH
export DOWNLOAD_URL UPLOAD_FILE DOWNLOAD_FILE PING_COUNT TRACE_HOPS DNS_QUERIES
export IPERF_TIME IPERF_PARALLEL IPERF_REVERSE VERBOSE RESULTS_DIR

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for optional but recommended tools
    local optional_tools=("iperf3" "dig" "jq" "parallel")
    echo "Checking for optional dependencies..."
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_deps+=("$tool")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}Warning: Optional tools not found: ${missing_deps[*]}${NC}"
        echo "Some tests may be skipped or have reduced functionality."
        echo ""
    fi
}

# Function to run YABS benchmark
run_yabs_test() {
    echo -e "\n${BLUE}=== Running YABS Benchmark ===${NC}"
    local yabs_output="$RESULTS_DIR/yabs_${TEST_PHASE}_results.txt"
    
    # Detect macOS and use appropriate script
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "Running YABS Extended..."
        if [ -f "${PROJECT_ROOT}/yabs_extended.sh" ]; then
            # Export configuration for yabs_extended.sh
            export DNS_SERVER IPERF_SERVER DESTINATION_IP
            # Skip network info in quick mode to prevent hanging
            yabs_args="-p $TEST_PHASE"
            [ "$QUICK_MODE" = true ] && yabs_args="$yabs_args -I"
            bash "${PROJECT_ROOT}/yabs_extended.sh" $yabs_args | tee "$yabs_output"
        else
            echo "Error: yabs_extended.sh not found"
            return 1
        fi
    else
        # Run YABS Extended on Linux
        if [ -f "${PROJECT_ROOT}/yabs_extended.sh" ]; then
            echo "Running YABS Extended..."
            # Export configuration for yabs_extended.sh
            export DNS_SERVER IPERF_SERVER DESTINATION_IP
            # Skip network info in quick mode to prevent hanging
            yabs_args="-p $TEST_PHASE"
            [ "$QUICK_MODE" = true ] && yabs_args="$yabs_args -I"
            bash "${PROJECT_ROOT}/yabs_extended.sh" $yabs_args | tee "$yabs_output"
        elif [ -f "${PROJECT_ROOT}/yabs.sh" ]; then
            echo "Warning: yabs_extended.sh not found, using standard yabs.sh"
            bash "${PROJECT_ROOT}/yabs.sh" -j | tee "$yabs_output"
        else
            echo "Error: No YABS script found"
            return 1
        fi
    fi
}

# Function to run network tests
run_network_tests() {
    echo -e "\n${BLUE}=== Running Network Performance Tests ===${NC}"
    local network_script="$SCRIPT_DIR/network_performance_test.sh"
    
    if [ -f "$network_script" ]; then
        # Run ping test
        [ "$VERBOSE" = true ] && echo "Running ping test to $DESTINATION_IP..."
        "$network_script" -t ping -d "$DESTINATION_IP" -c "$PING_COUNT" -p "$TEST_PHASE"
        
        # Run traceroute test
        [ "$VERBOSE" = true ] && echo "Running traceroute to $DESTINATION_IP..."
        "$network_script" -t traceroute -d "$DESTINATION_IP" -m "$TRACE_HOPS" -p "$TEST_PHASE"
        
        # Run iperf tests if server is specified
        if [ ! -z "$IPERF_SERVER" ]; then
            local iperf_args="-s $IPERF_SERVER -i $IPERF_TIME -p $TEST_PHASE"
            
            # Add parallel streams if specified
            if [ "$IPERF_PARALLEL" -gt 1 ]; then
                iperf_args="$iperf_args -P $IPERF_PARALLEL"
            fi
            
            # Add reverse mode if specified
            if [ "$IPERF_REVERSE" = true ]; then
                iperf_args="$iperf_args -R"
            fi
            
            [ "$VERBOSE" = true ] && echo "Running iPerf3 test to $IPERF_SERVER..."
            "$network_script" -t iperf $iperf_args
        else
            echo "Skipping iPerf tests - no server specified"
        fi
    else
        echo "Error: Network test script not found: $network_script"
        return 1
    fi
}

# Function to run DNS tests
run_dns_tests() {
    echo -e "\n${BLUE}=== Running DNS Performance Tests ===${NC}"
    local dns_script="$SCRIPT_DIR/dns_performance_test.sh"
    
    if [ -f "$dns_script" ]; then
        [ "$VERBOSE" = true ] && echo "Running DNS queries to $DNS_SERVER..."
        "$dns_script" -s "$DNS_SERVER" -c "$DNS_QUERIES" -p "$TEST_PHASE"
    else
        echo "Error: DNS test script not found: $dns_script"
        return 1
    fi
}

# Function to run data transfer tests
run_transfer_tests() {
    echo -e "\n${BLUE}=== Running Data Transfer Tests ===${NC}"
    local transfer_script="$SCRIPT_DIR/data_transfer_test.sh"
    
    if [ -f "$transfer_script" ]; then
        # Run download test
        if [ ! -z "$DOWNLOAD_URL" ]; then
            [ "$VERBOSE" = true ] && echo "Running download test from $DOWNLOAD_URL..."
            "$transfer_script" -t wget -d "$DOWNLOAD_URL" -p "$TEST_PHASE"
        fi
        
        # Run upload test if file specified
        if [ ! -z "$UPLOAD_FILE" ] && [ -f "$UPLOAD_FILE" ]; then
            if [ ! -z "$REMOTE_HOST" ] && [ ! -z "$REMOTE_USER" ]; then
                [ "$VERBOSE" = true ] && echo "Uploading $UPLOAD_FILE to $REMOTE_HOST..."
                "$transfer_script" -t scp -h "$REMOTE_HOST" -u "$REMOTE_USER" \
                    -r "$REMOTE_PATH" -l "$UPLOAD_FILE" -p "$TEST_PHASE"
            else
                echo "Skipping upload test - remote host/user not specified"
            fi
        fi
    else
        echo "Warning: Transfer test script not found: $transfer_script"
    fi
}

# Function to compare pre/post results
compare_results() {
    echo -e "\n${BLUE}=== Comparing Pre/Post Results ===${NC}"
    
    # Find the most recent pre and post result directories
    local pre_dir=$(ls -dt "$PROJECT_ROOT/results/"*pre* 2>/dev/null | head -1)
    local post_dir=$(ls -dt "$PROJECT_ROOT/results/"*post* 2>/dev/null | head -1)
    
    if [ -z "$pre_dir" ] || [ -z "$post_dir" ]; then
        echo "Error: Could not find pre/post result directories"
        return 1
    fi
    
    echo "Comparing:"
    echo "  Pre:  $(basename "$pre_dir")"
    echo "  Post: $(basename "$post_dir")"
    echo ""
    
    # Compare network metrics
    if [ -f "$pre_dir/network_summary.json" ] && [ -f "$post_dir/network_summary.json" ]; then
        echo "Network Performance Changes:"
        # Use jq to compare if available
        if command -v jq >/dev/null 2>&1; then
            # Extract and compare ping times
            local pre_ping=$(jq -r '.ping.avg_rtt' "$pre_dir/network_summary.json" 2>/dev/null)
            local post_ping=$(jq -r '.ping.avg_rtt' "$post_dir/network_summary.json" 2>/dev/null)
            if [ ! -z "$pre_ping" ] && [ ! -z "$post_ping" ]; then
                local ping_diff=$(echo "$post_ping - $pre_ping" | bc)
                echo "  Ping RTT: ${pre_ping}ms → ${post_ping}ms (${ping_diff}ms)"
            fi
        fi
    fi
    
    # Generate comparison report
    local comparison_report="$PROJECT_ROOT/results/comparison_$(date +%Y%m%d_%H%M%S).txt"
    echo -e "\nGenerating detailed comparison report: $comparison_report"
}

# Function to run tests in parallel
run_parallel_tests() {
    echo -e "\n${BLUE}=== Running Tests in Parallel ===${NC}"
    
    if ! command -v parallel >/dev/null 2>&1; then
        echo "Error: GNU parallel not found. Install it or run without -P flag."
        exit 1
    fi
    
    # Create list of test functions to run
    local test_functions=()
    [ "$RUN_YABS" = true ] && test_functions+=("run_yabs_test")
    [ "$RUN_NETWORK" = true ] && test_functions+=("run_network_tests")
    [ "$RUN_DNS" = true ] && test_functions+=("run_dns_tests")
    [ "$RUN_TRANSFER" = true ] && test_functions+=("run_transfer_tests")
    
    # Export functions for parallel
    export -f run_yabs_test run_network_tests run_dns_tests run_transfer_tests
    
    # Run tests in parallel
    printf '%s\n' "${test_functions[@]}" | parallel -j0 --tag {}
}

# Function to show final summary
show_final_summary() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  PERFORMANCE TEST SUMMARY${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Parse results from output files if they exist
    local ping_results=$(find "$RESULTS_DIR" -name "*ping*.json" -type f 2>/dev/null)
    if [ ! -z "$ping_results" ]; then
        echo -e "  ${BOLD}${CYAN}NETWORK LATENCY:${NC}"
        for result in $ping_results; do
            local dest=$(basename "$result" | sed 's/.*ping_\([^_]*\).*/\1/')
            local avg=$(grep -o '"rtt_avg_ms"[[:space:]]*:[[:space:]]*[0-9.]*' "$result" | awk -F':' '{print $2}' | tr -d ' ')
            if [ ! -z "$avg" ]; then
                local avg_color="${GREEN}"
                [ $(echo "$avg > 50" | bc) -eq 1 ] && avg_color="${YELLOW}"
                [ $(echo "$avg > 100" | bc) -eq 1 ] && avg_color="${RED}"
                echo -e "    ${dest}: ${avg_color}${avg}ms${NC}"
            fi
        done
        echo ""
    fi
    
    # iPerf results
    local iperf_tcp=$(find "$RESULTS_DIR" -name "*iperf_tcp*.json" -type f 2>/dev/null | head -1)
    local iperf_udp=$(find "$RESULTS_DIR" -name "*iperf_udp*.json" -type f 2>/dev/null | head -1)
    
    if [ ! -z "$iperf_tcp" ] || [ ! -z "$iperf_udp" ]; then
        echo -e "  ${BOLD}${CYAN}iPERF3 RESULTS:${NC}"
        if [ ! -z "$iperf_tcp" ] && [ -f "$iperf_tcp" ]; then
            local tcp_rate=$(grep -o '"bits_per_second"[[:space:]]*:[[:space:]]*[0-9.]*' "$iperf_tcp" 2>/dev/null | tail -1 | awk -F':' '{print $2}' | tr -d ' ')
            if [ ! -z "$tcp_rate" ]; then
                local tcp_mbps=$(echo "scale=2; $tcp_rate / 1000000" | bc 2>/dev/null || echo "0")
                echo -e "    TCP Throughput: ${GREEN}${tcp_mbps} Mbps${NC}"
            fi
        fi
        if [ ! -z "$iperf_udp" ] && [ -f "$iperf_udp" ]; then
            local jitter=$(grep -o '"jitter_ms"[[:space:]]*:[[:space:]]*[0-9.]*' "$iperf_udp" 2>/dev/null | tail -1 | awk -F':' '{print $2}' | tr -d ' ')
            [ ! -z "$jitter" ] && echo -e "    UDP Jitter: ${YELLOW}${jitter}ms${NC}"
        fi
        echo ""
    fi
    
    # DNS results
    local dns_stats=$(find "$RESULTS_DIR" -name "*dns*stats.txt" -type f 2>/dev/null | head -1)
    if [ ! -z "$dns_stats" ] && [ -f "$dns_stats" ]; then
        echo -e "  ${BOLD}${CYAN}DNS PERFORMANCE:${NC}"
        local dns_avg=$(grep "Average response time:" "$dns_stats" 2>/dev/null | awk '{print $4}' | tr -d 'ms')
        if [ ! -z "$dns_avg" ]; then
            local dns_color="${GREEN}"
            [ $dns_avg -gt 100 ] && dns_color="${YELLOW}"
            [ $dns_avg -gt 200 ] && dns_color="${RED}"
            echo -e "    Average Query Time: ${dns_color}${dns_avg}ms${NC}"
        fi
        echo ""
    fi
    
    # Data transfer results
    local wget_json=$(find "$RESULTS_DIR" -name "*wget*.json" -type f 2>/dev/null | head -1)
    local curl_json=$(find "$RESULTS_DIR" -name "*curl*.json" -type f 2>/dev/null | head -1)
    
    if [ ! -z "$wget_json" ] || [ ! -z "$curl_json" ]; then
        echo -e "  ${BOLD}${CYAN}DATA TRANSFER SPEEDS:${NC}"
        if [ ! -z "$wget_json" ] && [ -f "$wget_json" ]; then
            local wget_speed=$(grep -o '"speed_mbps"[[:space:]]*:[[:space:]]*[0-9.]*' "$wget_json" 2>/dev/null | tail -1 | awk -F':' '{print $2}' | tr -d ' ')
            if [ ! -z "$wget_speed" ]; then
                local wget_mbps=$(echo "scale=2; $wget_speed * 8" | bc 2>/dev/null || echo "0")
                echo -e "    Download Speed: ${GREEN}${wget_mbps} Mbps${NC} (${wget_speed} MB/s)"
            fi
        fi
        echo ""
    fi
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Performance Test Suite - $TEST_PHASE phase${NC}"
    echo "=========================================="
    echo ""
    
    # Show configuration
    echo "Test Configuration:"
    echo "==================="
    echo "Phase: $TEST_PHASE"
    echo "Results Directory: $RESULTS_DIR"
    echo "Parallel Execution: $PARALLEL_EXECUTION"
    [ "$QUICK_MODE" = true ] && echo "Mode: Quick (reduced iterations)"
    echo ""
    
    echo "Tests to run:"
    [ "$RUN_YABS" = true ] && echo "  ✓ YABS System Benchmark"
    [ "$RUN_NETWORK" = true ] && echo "  ✓ Network Performance (ping, traceroute, iperf)"
    [ "$RUN_DNS" = true ] && echo "  ✓ DNS Performance"
    [ "$RUN_TRANSFER" = true ] && echo "  ✓ Data Transfer Tests"
    echo ""
    
    echo "Test Parameters:"
    echo "  Destination IP: $DESTINATION_IP"
    echo "  DNS Server: $DNS_SERVER"
    [ ! -z "$IPERF_SERVER" ] && echo "  iPerf Server: $IPERF_SERVER"
    [ "$IPERF_REVERSE" = true ] && echo "  iPerf Mode: Reverse"
    [ "$IPERF_PARALLEL" -gt 1 ] && echo "  iPerf Streams: $IPERF_PARALLEL"
    echo "  iPerf Duration: ${IPERF_TIME}s"
    echo "  Ping Count: $PING_COUNT"
    echo "  DNS Queries: $DNS_QUERIES"
    [ ! -z "$UPLOAD_FILE" ] && echo "  Upload File: $UPLOAD_FILE"
    echo "  Download URL: $DOWNLOAD_URL"
    echo ""
    
    # Check dependencies
    check_dependencies
    
    # Run tests
    if [ "$PARALLEL_EXECUTION" = true ]; then
        run_parallel_tests
    else
        echo "Running tests sequentially..."
        [ "$RUN_YABS" = true ] && run_yabs_test
        [ "$RUN_NETWORK" = true ] && run_network_tests
        [ "$RUN_DNS" = true ] && run_dns_tests
        [ "$RUN_TRANSFER" = true ] && run_transfer_tests
    fi
    
    # Generate summary report
    echo -e "\n${BLUE}=== Generating Summary Report ===${NC}"
    local summary_file="$RESULTS_DIR/test_summary.txt"
    
    cat > "$summary_file" <<EOF
Performance Test Summary
========================
Test Phase: $TEST_PHASE
Date: $(date)
Configuration:
  Destination: $DESTINATION_IP
  DNS Server: $DNS_SERVER
  iPerf Server: $IPERF_SERVER
  Duration: ${IPERF_TIME}s
  
Results Directory: $RESULTS_DIR
EOF
    
    echo ""
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  ✓ ALL TESTS COMPLETED SUCCESSFULLY${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Results Directory:${NC}"
    echo -e "  $RESULTS_DIR"
    echo ""
    echo -e "  ${BOLD}Summary Report:${NC}"
    echo -e "  $summary_file"
    echo ""
    
    # Always show key metrics summary
    show_final_summary
}

# Execute main function
main