#!/bin/bash

# Performance Test Suite Master Script
# Orchestrates all performance tests and manages pre/post comparisons
# Supports parallel execution using git worktrees

SCRIPT_VERSION="v1.0.0"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
source "$PROJECT_ROOT/lib/common_functions.sh"

echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e '#         Performance Test Suite Master              #'
echo -e '#                   '$SCRIPT_VERSION'                  #'
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
RESULTS_DIR="$PROJECT_ROOT/results/test_results_${TIMESTAMP}"

# Test configuration defaults
DESTINATION_IP="8.8.8.8"
IPERF_SERVER=""
DNS_SERVER="8.8.8.8"
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PATH="/tmp"
DOWNLOAD_URL="http://speedtest.tele2.net/100MB.zip"

# Function to display usage
usage() {
    echo "Usage: $0 [-p <pre|post>] [-c <config_file>] [options]"
    echo ""
    echo "Options:"
    echo "  -p <pre|post>        Test phase (default: pre)"
    echo "  -c <config_file>     Configuration file with test parameters"
    echo "  -w <worktree_name>   Use git worktree for isolated execution"
    echo "  -P                   Run tests in parallel (requires GNU parallel)"
    echo "  -Y                   Skip YABS benchmark"
    echo "  -N                   Skip network tests (ping, traceroute, iperf)"
    echo "  -D                   Skip DNS tests"
    echo "  -T                   Skip data transfer tests"
    echo "  -h                   Display this help message"
    echo ""
    echo "Configuration file format (optional):"
    echo "  DESTINATION_IP=8.8.8.8"
    echo "  IPERF_SERVER=192.168.1.100"
    echo "  DNS_SERVER=1.1.1.1"
    echo "  REMOTE_HOST=server.example.com"
    echo "  REMOTE_USER=username"
    echo "  REMOTE_PATH=/path/to/directory"
    echo "  DOWNLOAD_URL=http://example.com/testfile.zip"
    echo ""
    echo "Examples:"
    echo "  $0 -p pre -c test_config.conf"
    echo "  $0 -p post -w feature-branch -P"
    echo "  $0 -p pre -Y -D  # Skip YABS and DNS tests"
    exit 1
}

# Function to create default config file
create_default_config() {
    cat > test_config_template.conf <<EOF
# Performance Test Suite Configuration
# Uncomment and modify values as needed

# Network test configuration
DESTINATION_IP=8.8.8.8
IPERF_SERVER=
# IPERF_SERVER=192.168.1.100

# DNS test configuration
DNS_SERVER=8.8.8.8
# Alternative DNS servers to test:
# DNS_SERVER=1.1.1.1      # Cloudflare
# DNS_SERVER=9.9.9.9      # Quad9
# DNS_SERVER=208.67.222.222  # OpenDNS

# Data transfer test configuration
# REMOTE_HOST=server.example.com
# REMOTE_USER=username
# REMOTE_PATH=/tmp
DOWNLOAD_URL=http://speedtest.tele2.net/100MB.zip

# Additional speed test URLs:
# DOWNLOAD_URL=http://speed.hetzner.de/100MB.bin
# DOWNLOAD_URL=http://proof.ovh.net/files/100Mb.dat
# DOWNLOAD_URL=http://speedtest.sea01.softlayer.com/downloads/test100.zip
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

# Function to setup git worktree
setup_worktree() {
    local worktree_name=$1
    local worktree_dir="../${worktree_name}-performance-test"
    
    echo "Setting up git worktree: $worktree_name"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository"
        return 1
    fi
    
    # Check if worktree already exists
    if git worktree list | grep -q "$worktree_dir"; then
        echo "Worktree already exists: $worktree_dir"
    else
        # Create new worktree
        git worktree add "$worktree_dir" -b "performance-test-$worktree_name-$TIMESTAMP"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create worktree"
            return 1
        fi
    fi
    
    # Copy test scripts to worktree
    cp "${SCRIPT_DIR}"/*.sh "$worktree_dir/"
    
    echo "Worktree created at: $worktree_dir"
    echo "Switching to worktree directory..."
    cd "$worktree_dir"
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required tools
    command -v bc >/dev/null 2>&1 || missing_deps+=("bc")
    
    # Check for optional tools
    echo "Checking for optional dependencies..."
    command -v iperf3 >/dev/null 2>&1 || echo "  - iperf3 not found (network tests will be limited)"
    command -v dig >/dev/null 2>&1 || echo "  - dig not found (DNS tests will be limited)"
    command -v jq >/dev/null 2>&1 || echo "  - jq not found (JSON processing will be limited)"
    
    if [ "$PARALLEL_EXECUTION" = true ]; then
        command -v parallel >/dev/null 2>&1 || missing_deps+=("GNU parallel")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        echo "Please install them before running this script."
        return 1
    fi
    
    return 0
}

# Function to run YABS benchmark
run_yabs_test() {
    echo "=== Running YABS Benchmark ==="
    local yabs_output="${RESULTS_DIR}/yabs_${TEST_PHASE}_${TIMESTAMP}.txt"
    
    if [ -f "${PROJECT_ROOT}/yabs.sh" ]; then
        # Run YABS with JSON output
        bash "${PROJECT_ROOT}/yabs.sh" -j | tee "$yabs_output"
    else
        echo "Warning: yabs.sh not found in project root"
        return 1
    fi
}

# Function to run network tests
run_network_tests() {
    echo "=== Running Network Performance Tests ==="
    
    if [ ! -f "${SCRIPT_DIR}/network_performance_test.sh" ]; then
        echo "Warning: network_performance_test.sh not found"
        return 1
    fi
    
    # Run comprehensive network test
    local net_cmd="bash '${SCRIPT_DIR}/network_performance_test.sh'"
    
    if [ ! -z "$IPERF_SERVER" ]; then
        # Run all tests including iperf when server is available
        net_cmd="$net_cmd -t all -d '$DESTINATION_IP' -s '$IPERF_SERVER' -p '$TEST_PHASE'"
    else
        # Run only ping and traceroute when no iperf server
        net_cmd="$net_cmd -t ping -d '$DESTINATION_IP' -p '$TEST_PHASE'"
        eval $net_cmd
        net_cmd="bash '${SCRIPT_DIR}/network_performance_test.sh' -t traceroute -d '$DESTINATION_IP' -p '$TEST_PHASE'"
    fi
    
    eval $net_cmd
}

# Function to run DNS tests
run_dns_tests() {
    echo "=== Running DNS Performance Tests ==="
    
    if [ ! -f "${SCRIPT_DIR}/dns_performance_test.sh" ]; then
        echo "Warning: dns_performance_test.sh not found"
        return 1
    fi
    
    bash "${SCRIPT_DIR}/dns_performance_test.sh" -s "$DNS_SERVER" -p "$TEST_PHASE"
}

# Function to run data transfer tests
run_transfer_tests() {
    echo "=== Running Data Transfer Tests ==="
    
    if [ ! -f "${SCRIPT_DIR}/data_transfer_test.sh" ]; then
        echo "Warning: data_transfer_test.sh not found"
        return 1
    fi
    
    # Determine which tests to run based on configuration
    local transfer_cmd=""
    
    if [ ! -z "$REMOTE_HOST" ] && [ ! -z "$REMOTE_USER" ]; then
        transfer_cmd="bash '${SCRIPT_DIR}/data_transfer_test.sh' -t all -h '$REMOTE_HOST' -u '$REMOTE_USER' -r '$REMOTE_PATH' -d '$DOWNLOAD_URL' -p '$TEST_PHASE'"
    else
        # Only run wget/curl tests
        transfer_cmd="bash '${SCRIPT_DIR}/data_transfer_test.sh' -t wget -d '$DOWNLOAD_URL' -p '$TEST_PHASE'"
        eval $transfer_cmd
        transfer_cmd="bash '${SCRIPT_DIR}/data_transfer_test.sh' -t curl -d '$DOWNLOAD_URL' -p '$TEST_PHASE'"
    fi
    
    eval $transfer_cmd
}

# Function to run all tests in parallel
run_tests_parallel() {
    echo "Running tests in parallel..."
    
    export -f run_yabs_test run_network_tests run_dns_tests run_transfer_tests
    export RESULTS_DIR TEST_PHASE SCRIPT_DIR
    export DESTINATION_IP IPERF_SERVER DNS_SERVER REMOTE_HOST REMOTE_USER REMOTE_PATH DOWNLOAD_URL
    
    # Create array of test functions to run
    local test_functions=()
    [ "$RUN_YABS" = true ] && test_functions+=("run_yabs_test")
    [ "$RUN_NETWORK" = true ] && test_functions+=("run_network_tests")
    [ "$RUN_DNS" = true ] && test_functions+=("run_dns_tests")
    [ "$RUN_TRANSFER" = true ] && test_functions+=("run_transfer_tests")
    
    # Run tests in parallel
    printf "%s\n" "${test_functions[@]}" | parallel -j 4 --no-notice "bash -c {}"
}

# Function to run all tests sequentially
run_tests_sequential() {
    echo "Running tests sequentially..."
    
    [ "$RUN_YABS" = true ] && { run_yabs_test; echo ""; }
    [ "$RUN_NETWORK" = true ] && { run_network_tests; echo ""; }
    [ "$RUN_DNS" = true ] && { run_dns_tests; echo ""; }
    [ "$RUN_TRANSFER" = true ] && { run_transfer_tests; echo ""; }
}

# Function to generate summary report
generate_summary() {
    local summary_file="${RESULTS_DIR}/test_summary_${TEST_PHASE}_${TIMESTAMP}.txt"
    
    echo "=== Performance Test Summary ===" > "$summary_file"
    echo "Test Phase: $TEST_PHASE" >> "$summary_file"
    echo "Timestamp: $TIMESTAMP" >> "$summary_file"
    echo "Results Directory: $RESULTS_DIR" >> "$summary_file"
    echo "" >> "$summary_file"
    
    # List all result files
    echo "Generated Files:" >> "$summary_file"
    find "$RESULTS_DIR" -name "*.txt" -o -name "*.json" | sort >> "$summary_file"
    
    echo ""
    echo "Summary saved to: $summary_file"
    cat "$summary_file"
}

# Parse command line arguments
while getopts "p:c:w:PYNDTh" opt; do
    case ${opt} in
        p )
            TEST_PHASE=$OPTARG
            ;;
        c )
            CONFIG_FILE=$OPTARG
            ;;
        w )
            USE_WORKTREE=true
            WORKTREE_NAME=$OPTARG
            ;;
        P )
            PARALLEL_EXECUTION=true
            ;;
        Y )
            RUN_YABS=false
            ;;
        N )
            RUN_NETWORK=false
            ;;
        D )
            RUN_DNS=false
            ;;
        T )
            RUN_TRANSFER=false
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

# Main execution
echo "Performance Test Suite - $TEST_PHASE phase"
echo "=========================================="
echo ""

# Check if template config is requested
if [ "$1" = "--create-config" ]; then
    create_default_config
    exit 0
fi

# Load configuration file if provided
if [ ! -z "$CONFIG_FILE" ]; then
    load_config "$CONFIG_FILE"
fi

# Check dependencies
check_dependencies || exit 1

# Setup worktree if requested
if [ "$USE_WORKTREE" = true ]; then
    setup_worktree "$WORKTREE_NAME" || exit 1
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

# Make scripts executable
chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null

# Display test configuration
echo "Test Configuration:"
echo "==================="
echo "Phase: $TEST_PHASE"
echo "Results Directory: $RESULTS_DIR"
echo "Parallel Execution: $PARALLEL_EXECUTION"
echo ""
echo "Tests to run:"
[ "$RUN_YABS" = true ] && echo "  ✓ YABS System Benchmark"
[ "$RUN_NETWORK" = true ] && echo "  ✓ Network Performance (ping, traceroute, iperf)"
[ "$RUN_DNS" = true ] && echo "  ✓ DNS Performance"
[ "$RUN_TRANSFER" = true ] && echo "  ✓ Data Transfer (scp, rsync, wget, curl)"
echo ""
echo "Test Parameters:"
echo "  Destination IP: $DESTINATION_IP"
echo "  DNS Server: $DNS_SERVER"
[ ! -z "$IPERF_SERVER" ] && echo "  iPerf Server: $IPERF_SERVER"
[ ! -z "$REMOTE_HOST" ] && echo "  Remote Host: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"
echo "  Download URL: $DOWNLOAD_URL"
echo ""

# Confirm before proceeding
read -p "Press Enter to start tests or Ctrl+C to cancel..."
echo ""

# Record start time
START_TIME=$(date +%s)

# Run tests
if [ "$PARALLEL_EXECUTION" = true ] && command -v parallel >/dev/null 2>&1; then
    run_tests_parallel
else
    run_tests_sequential
fi

# Record end time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "All tests completed in $DURATION seconds"
echo ""

# Generate summary report
generate_summary

# Cleanup worktree if used
if [ "$USE_WORKTREE" = true ] && [ ! -z "$WORKTREE_NAME" ]; then
    echo ""
    echo "Note: Tests were run in worktree. To remove it:"
    echo "  git worktree remove $(pwd)"
fi

echo ""
echo "Test suite completed successfully!"