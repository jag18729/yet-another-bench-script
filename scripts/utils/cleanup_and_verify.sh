#!/bin/bash

# Cleanup and verification script for performance test suite

echo "Performance Test Suite - Cleanup and Verification"
echo "================================================"
echo

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check dependencies
echo "Checking local dependencies..."
deps=(jq python3 iperf3 dig curl wget rsync ssh)
missing_deps=()

for cmd in "${deps[@]}"; do
    if command -v $cmd >/dev/null 2>&1; then
        echo -e "  ✅ $cmd: $(which $cmd)"
    else
        echo -e "  ${RED}❌ $cmd: NOT FOUND${NC}"
        missing_deps+=($cmd)
    fi
done

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}Missing dependencies: ${missing_deps[*]}${NC}"
    echo "Run ./check_dependencies.sh for installation instructions"
fi

# Check Python modules
echo -e "\nChecking Python modules..."
python_modules=(matplotlib json argparse datetime)
for module in "${python_modules[@]}"; do
    if python3 -c "import $module" 2>/dev/null; then
        echo -e "  ✅ $module"
    else
        echo -e "  ${RED}❌ $module${NC}"
    fi
done

# Check SSH connectivity
echo -e "\n${YELLOW}Checking SSH connectivity to Zorin VM...${NC}"
if ssh -o BatchMode=yes -o ConnectTimeout=3 zorin0 "echo 'Connected'" 2>/dev/null; then
    echo -e "  ${GREEN}✅ SSH connection successful${NC}"
    
    # Check remote directory
    if ssh zorin0 "ls -d /home/rjgarcia/performance-tests" 2>/dev/null; then
        echo -e "  ${GREEN}✅ Remote directory exists${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Remote directory doesn't exist (will be created on sync)${NC}"
    fi
else
    echo -e "  ${RED}❌ SSH connection failed${NC}"
    echo -e "  Run: ${YELLOW}./setup_ssh_zorin.sh${NC} to set up SSH keys"
fi

# List test scripts
echo -e "\n${YELLOW}Available test scripts:${NC}"
for script in *_test.sh performance_test_suite.sh; do
    if [ -f "$script" ]; then
        echo "  - $script"
    fi
done

# List setup scripts
echo -e "\n${YELLOW}Setup scripts:${NC}"
echo "  - setup_client.sh    : Configure Mac client"
echo "  - setup_server.sh    : Configure Zorin server"
echo "  - setup_ssh_zorin.sh : Set up SSH keys"
echo "  - sync_to_zorin.sh   : Sync files to Zorin VM"

# Cleanup old results
echo -e "\n${YELLOW}Cleanup options:${NC}"
if ls "$PROJECT_ROOT"/results/test_results_* 2>/dev/null | head -1 >/dev/null; then
    count=$(ls -d "$PROJECT_ROOT"/results/test_results_* 2>/dev/null | wc -l)
    echo "  Found $count test result directories"
    echo "  To clean: rm -rf results/test_results_*"
else
    echo "  No test results found"
fi

# Quick start guide
echo -e "\n${GREEN}Quick Start:${NC}"
echo "1. Set up SSH keys:        ./setup_ssh_zorin.sh"
echo "2. Sync files to Zorin:    ./sync_to_zorin.sh"
echo "3. Run a quick test:       ./network_performance_test.sh -t ping -d 8.8.8.8 -p test"
echo "4. Run full test suite:    ./performance_test_suite.sh -p pre -c test_config.conf"
echo "5. Watch for changes:      ./sync_to_zorin.sh --watch"

echo -e "\n${YELLOW}For help with any script, use the -h flag${NC}"