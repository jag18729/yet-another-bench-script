#!/bin/bash

# Simple Performance Test Runner
# Quick command wrapper for common test scenarios

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERFORMANCE_SUITE="$SCRIPT_DIR/scripts/core/performance_test_suite.sh"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if performance suite exists
if [ ! -f "$PERFORMANCE_SUITE" ]; then
    echo -e "${RED}Error: Performance test suite not found at $PERFORMANCE_SUITE${NC}"
    exit 1
fi

# Function to display usage
usage() {
    cat <<EOF
${BLUE}Simple Performance Test Runner${NC}

QUICK COMMANDS:
  $0 quick                     Quick test with defaults (5s tests)
  $0 full                      Full comprehensive test (30s tests)
  $0 network                   Network tests only
  $0 dns                       DNS tests only
  $0 compare                   Compare pre/post results

COMMON OPTIONS:
  $0 --server <IP>             Run tests with specific iPerf server
  $0 --config <file>           Use configuration file
  $0 --phase <pre|post>        Specify test phase

ADVANCED EXAMPLES:
  # Quick test with custom server
  $0 quick --server 192.168.1.100

  # Full test with parallel streams
  $0 full --server 192.168.1.100 --parallel 4

  # Network test with reverse mode
  $0 network --server 192.168.1.100 --reverse

  # Upload file test
  $0 --upload /path/to/file.bin --server 192.168.1.100

CONFIGURATION:
  # Create a template config file
  $0 create-config

  # Use existing config
  $0 --config my_config.conf

DEFAULT SERVERS:
  DNS: 1.1.1.1 (Cloudflare)
  Ping: 1.1.1.1
  Download: http://speedtest.tele2.net/100MB.zip

For full options, run:
  $PERFORMANCE_SUITE --help

EOF
    exit 0
}

# Parse first argument as command
COMMAND="${1:-help}"
shift

case "$COMMAND" in
    quick)
        echo -e "${GREEN}Running quick performance test...${NC}"
        "$PERFORMANCE_SUITE" -q "$@"
        ;;
    
    full)
        echo -e "${GREEN}Running full performance test suite...${NC}"
        "$PERFORMANCE_SUITE" --full "$@"
        ;;
    
    network)
        echo -e "${GREEN}Running network tests only...${NC}"
        "$PERFORMANCE_SUITE" --network-only "$@"
        ;;
    
    dns)
        echo -e "${GREEN}Running DNS tests only...${NC}"
        "$PERFORMANCE_SUITE" -N -T "$@"
        ;;
    
    compare)
        echo -e "${GREEN}Comparing pre/post results...${NC}"
        "$PERFORMANCE_SUITE" --compare
        ;;
    
    create-config)
        echo -e "${GREEN}Creating configuration template...${NC}"
        "$PERFORMANCE_SUITE" --create-config
        ;;
    
    # Handle options that start with --
    --server)
        echo -e "${GREEN}Running test with server $1...${NC}"
        "$PERFORMANCE_SUITE" --server "$@"
        ;;
    
    --config)
        echo -e "${GREEN}Running test with config file $1...${NC}"
        "$PERFORMANCE_SUITE" -c "$@"
        ;;
    
    --phase)
        echo -e "${GREEN}Running $1 phase test...${NC}"
        "$PERFORMANCE_SUITE" -p "$@"
        ;;
    
    --upload)
        echo -e "${GREEN}Running upload test with file $1...${NC}"
        "$PERFORMANCE_SUITE" --upload "$@"
        ;;
    
    help|--help|-h|"")
        usage
        ;;
    
    *)
        echo -e "${YELLOW}Unknown command: $COMMAND${NC}"
        echo ""
        usage
        ;;
esac