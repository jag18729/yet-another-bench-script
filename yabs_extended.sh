#!/bin/bash

# Extended YABS Script - Wrapper for YABS + Additional Network Tests
# Purpose: Run standard YABS benchmarks plus extended network performance tests

YABS_EXTENDED_VERSION="v1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions if available
if [ -f "$SCRIPT_DIR/lib/common_functions.sh" ]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
RUN_YABS=true
RUN_NETWORK=true
RUN_DNS=true
RUN_TRACE=true
RUN_NETINFO=true
TEST_PHASE="test"
YABS_ARGS=""

# Parse arguments
while getopts 'hYNDTIp:y:' flag; do
    case "${flag}" in
        h) # Help
            echo "Extended YABS Script - $YABS_EXTENDED_VERSION"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -h         Show this help message"
            echo "  -Y         Skip standard YABS tests"
            echo "  -N         Skip extended network tests"
            echo "  -D         Skip DNS tests"
            echo "  -T         Skip traceroute tests"
            echo "  -I         Skip network info lookup (prevents hanging)"
            echo "  -p PHASE   Set test phase (pre/test/post)"
            echo "  -y ARGS    Pass additional arguments to YABS"
            echo ""
            echo "Examples:"
            echo "  $0                    # Run all tests"
            echo "  $0 -p pre             # Run all tests with 'pre' phase"
            echo "  $0 -Y                 # Skip YABS, run only network tests"
            echo "  $0 -y '-r -i'         # Pass -r -i flags to YABS"
            exit 0
            ;;
        Y) RUN_YABS=false ;;
        N) RUN_NETWORK=false ;;
        D) RUN_DNS=false ;;
        T) RUN_TRACE=false ;;
        I) RUN_NETINFO=false ;;
        p) TEST_PHASE="${OPTARG}" ;;
        y) YABS_ARGS="${OPTARG}" ;;
        *) exit 1 ;;
    esac
done

# Header
echo -e "${BLUE}# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #${NC}"
echo -e "${BLUE}#            Extended YABS Benchmark Suite            #${NC}"
echo -e "${BLUE}#                   $YABS_EXTENDED_VERSION                            #${NC}"
echo -e "${BLUE}# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #${NC}"
echo ""
echo -e "Test Phase: ${YELLOW}$TEST_PHASE${NC}"
echo -e "Start Time: $(date)"
echo ""

# Create results directory
RESULTS_DIR="${RESULTS_DIR:-$SCRIPT_DIR/results/${TEST_PHASE}_$(date +%b-%d-%Y_%H-%M-%S)-Extended-Test-Suite-Results}"
mkdir -p "$RESULTS_DIR"

# Detect operating system
OS_TYPE="$(uname)"
IS_MACOS=false
if [[ "$OS_TYPE" == "Darwin" ]] || [[ "$YABS_MACOS" == "1" ]]; then
    IS_MACOS=true
fi

# Run standard YABS if not skipped
if [ "$RUN_YABS" = true ]; then
    if [ "$IS_MACOS" = true ]; then
        echo -e "${GREEN}=== Running macOS System Information ===${NC}"
        echo ""
        
        # macOS System Information
        echo "Basic System Information:"
        echo "---------------------------------"
        echo "Uptime     : $(uptime | sed 's/.*up //' | awk -F',' '{print $1 $2}')"
        echo "Processor  : $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")"
        echo "CPU cores  : $(sysctl -n hw.physicalcpu 2>/dev/null || echo "Unknown") physical, $(sysctl -n hw.logicalcpu 2>/dev/null || echo "Unknown") logical"
        echo "CPU Speed  : $(sysctl -n hw.cpufrequency_max 2>/dev/null | awk '{printf "%.2f GHz", $1/1000000000}' || echo "Unknown")"
        echo "RAM        : $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 / 1024 )) GB"
        echo "Swap       : $(sysctl -n vm.swapusage 2>/dev/null | awk '{gsub(/M/, "MB"); print $3 " total, " $6 " used, " $9 " free"}' || echo "Unknown")"
        echo "Disk       : $(df -h / | awk 'NR==2 {print $2 " total, " $3 " used (" $5 ")"}')"
        echo "OS         : $(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
        echo "Kernel     : $(uname -r)"
        echo "Arch       : $(uname -m)"
        echo ""
        
        # Network Information
        if [ "$RUN_NETINFO" = true ]; then
            echo "Network Information:"
            echo "---------------------------------"
            # Add timeout and better error handling
            IP_INFO=$(curl -s --max-time 5 https://ipinfo.io/json 2>/dev/null)
            CURL_EXIT=$?
            if [ $CURL_EXIT -eq 0 ] && [ -n "$IP_INFO" ]; then
                PUBLIC_IP=$(echo "$IP_INFO" | grep -o '"ip":"[^"]*' | cut -d'"' -f4)
                if [ -n "$PUBLIC_IP" ]; then
                    echo "Public IP  : $PUBLIC_IP"
                    ISP=$(echo "$IP_INFO" | grep -o '"org":"[^"]*' | cut -d'"' -f4)
                    [ -n "$ISP" ] && echo "ISP        : $ISP"
                    CITY=$(echo "$IP_INFO" | grep -o '"city":"[^"]*' | cut -d'"' -f4)
                    REGION=$(echo "$IP_INFO" | grep -o '"region":"[^"]*' | cut -d'"' -f4)
                    [ -n "$CITY" ] && [ -n "$REGION" ] && echo "Location   : $CITY, $REGION"
                    COUNTRY=$(echo "$IP_INFO" | grep -o '"country":"[^"]*' | cut -d'"' -f4)
                    [ -n "$COUNTRY" ] && echo "Country    : $COUNTRY"
                else
                    echo "Public IP  : Unable to determine (timeout/network issue)"
                fi
            else
                echo "Public IP  : Unable to determine (timeout/network issue)"
            fi
            echo ""
        fi
        
        # Basic disk speed test for macOS
        echo "Disk Speed Test (dd):"
        echo "---------------------------------"
        echo "Testing write speed..."
        WRITE_SPEED=$(timeout 10 dd if=/dev/zero of=/tmp/yabs_test bs=1024k count=1024 2>&1 | awk '/bytes/{print $(NF-1) " " $NF}' | tail -1)
        DD_EXIT=$?
        rm -f /tmp/yabs_test
        if [ $DD_EXIT -eq 0 ] && [ -n "$WRITE_SPEED" ]; then
            echo "Write Speed: $WRITE_SPEED"
        else
            echo "Write Speed: Test skipped (timeout/error)"
        fi
        echo ""
        
        # Save output
        {
            echo "macOS System Information"
            echo "========================"
            echo "Processor  : $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")"
            echo "CPU cores  : $(sysctl -n hw.physicalcpu 2>/dev/null || echo "Unknown") physical, $(sysctl -n hw.logicalcpu 2>/dev/null || echo "Unknown") logical"
            echo "RAM        : $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 / 1024 )) GB"
            echo "Disk       : $(df -h / | awk 'NR==2 {print $2 " total, " $3 " used (" $5 ")"}')"
        } > "$RESULTS_DIR/yabs_output.txt"
        
        echo -e "${GREEN}✓ macOS system tests completed${NC}"
    else
        echo -e "${GREEN}=== Running Standard YABS Benchmarks ===${NC}"
        echo -e "Command: ./yabs.sh $YABS_ARGS"
        echo ""
        
        # Check if yabs.sh exists
        if [ -f "./yabs.sh" ]; then
            # Run YABS and capture output
            ./yabs.sh $YABS_ARGS 2>&1 | tee "$RESULTS_DIR/yabs_output.txt"
            echo ""
            echo -e "${GREEN}✓ YABS tests completed${NC}"
        else
            echo -e "${RED}✗ yabs.sh not found in current directory${NC}"
        fi
    fi
    echo ""
fi

# Run extended network tests if not skipped
if [ "$RUN_NETWORK" = true ]; then
    echo -e "${GREEN}=== Running Extended Network Tests ===${NC}"
    
    # Use the new network performance test script
    if [ -f "$SCRIPT_DIR/scripts/core/network_performance_test.sh" ]; then
        # Run comprehensive network tests
        "$SCRIPT_DIR/scripts/core/network_performance_test.sh" -t ping -d 8.8.8.8 -p "$TEST_PHASE" -c 20
        "$SCRIPT_DIR/scripts/core/network_performance_test.sh" -t ping -d 1.1.1.1 -p "$TEST_PHASE" -c 20
        "$SCRIPT_DIR/scripts/core/network_performance_test.sh" -t traceroute -d 8.8.8.8 -p "$TEST_PHASE"
        
        # Run DNS performance tests
        if [ "$RUN_DNS" = true ] && [ -f "$SCRIPT_DIR/scripts/core/dns_performance_test.sh" ]; then
            echo -e "\n${BLUE}=== Running DNS Performance Tests ===${NC}"
            # Use DNS server from environment or default to 1.1.1.1
            dns_server="${DNS_SERVER:-1.1.1.1}"
            "$SCRIPT_DIR/scripts/core/dns_performance_test.sh" -s "$dns_server" -p "$TEST_PHASE" -c 20
        fi
        
        echo ""
        echo -e "${GREEN}✓ Extended tests completed${NC}"
    else
        echo -e "${YELLOW}⚠ network_performance_test.sh not found, using inline tests${NC}"
        
        # Inline basic network tests
        echo -e "\n${BLUE}--- Basic Ping Tests ---${NC}"
        for target in 8.8.8.8 1.1.1.1 9.9.9.9; do
            echo -e "\nPinging $target..."
            ping -c 10 "$target" > "$RESULTS_DIR/${TEST_PHASE}_ping_${target}.txt" 2>&1
            if grep -q "0% packet loss" "$RESULTS_DIR/${TEST_PHASE}_ping_${target}.txt"; then
                avg_time=$(grep "avg" "$RESULTS_DIR/${TEST_PHASE}_ping_${target}.txt" | awk -F'/' '{print $5}')
                echo -e "${GREEN}✓${NC} $target: avg RTT = ${avg_time}ms"
            else
                echo -e "${RED}✗${NC} $target: Failed"
            fi
        done
        
        if [ "$RUN_TRACE" = true ]; then
            echo -e "\n${BLUE}--- Basic Traceroute Tests ---${NC}"
            for target in 8.8.8.8 google.com; do
                echo -e "\nTraceroute to $target..."
                if command -v traceroute >/dev/null 2>&1; then
                    traceroute -m 20 "$target" > "$RESULTS_DIR/${TEST_PHASE}_traceroute_${target}.txt" 2>&1
                    hops=$(grep -c "^ *[0-9]" "$RESULTS_DIR/${TEST_PHASE}_traceroute_${target}.txt")
                    echo -e "${GREEN}✓${NC} $target: $hops hops"
                else
                    echo -e "${YELLOW}⚠${NC} traceroute not available"
                fi
            done
        fi
        
        if [ "$RUN_DNS" = true ]; then
            echo -e "\n${BLUE}--- Basic DNS Tests ---${NC}"
            if command -v dig >/dev/null 2>&1; then
                # Use configured DNS server or default
                dns_server="${DNS_SERVER:-1.1.1.1}"
                echo -e "\nTesting DNS server $dns_server..."
                dig @"$dns_server" google.com +stats > "$RESULTS_DIR/${TEST_PHASE}_dns_${dns_server}.txt" 2>&1
                query_time=$(grep "Query time:" "$RESULTS_DIR/${TEST_PHASE}_dns_${dns_server}.txt" | awk '{print $4}')
                if [ -n "$query_time" ]; then
                    echo -e "${GREEN}✓${NC} $dns_server: Query time = ${query_time}ms"
                else
                    echo -e "${RED}✗${NC} $dns_server: Failed"
                fi
            else
                echo -e "${YELLOW}⚠${NC} dig not available for DNS tests"
            fi
        fi
    fi
    echo ""
fi

# Generate summary report
echo -e "${GREEN}=== Generating Summary Report ===${NC}"
SUMMARY_FILE="$RESULTS_DIR/summary.txt"

cat > "$SUMMARY_FILE" <<EOF
Extended YABS Benchmark Summary
==============================
Version: $YABS_EXTENDED_VERSION
Test Phase: $TEST_PHASE
Date: $(date)
Results Directory: $RESULTS_DIR

Tests Executed:
- Standard YABS: $([ "$RUN_YABS" = true ] && echo "Yes" || echo "No")
- Network Tests: $([ "$RUN_NETWORK" = true ] && echo "Yes" || echo "No")
- DNS Tests: $([ "$RUN_DNS" = true ] && echo "Yes" || echo "No")
- Traceroute Tests: $([ "$RUN_TRACE" = true ] && echo "Yes" || echo "No")

EOF

# Add YABS summary if available
if [ -f "$RESULTS_DIR/yabs_output.txt" ]; then
    echo -e "\nYABS Results Summary:" >> "$SUMMARY_FILE"
    echo "--------------------" >> "$SUMMARY_FILE"
    # Extract key metrics from YABS output
    grep -E "Single Core|Multi Core|iperf3|fio" "$RESULTS_DIR/yabs_output.txt" >> "$SUMMARY_FILE" 2>/dev/null || echo "No YABS metrics found" >> "$SUMMARY_FILE"
fi

# Add network test summary
echo -e "\nNetwork Test Summary:" >> "$SUMMARY_FILE"
echo "--------------------" >> "$SUMMARY_FILE"

# Summarize ping results
for file in "$RESULTS_DIR"/*ping*.txt; do
    if [ -f "$file" ]; then
        target=$(basename "$file" | sed 's/.*ping_\(.*\)\.txt/\1/')
        if grep -q "avg" "$file" 2>/dev/null; then
            avg_time=$(grep "avg" "$file" | awk -F'/' '{print $5}')
            echo "Ping $target: avg RTT = ${avg_time}ms" >> "$SUMMARY_FILE"
        fi
    fi
done

# Summary complete
echo -e "${GREEN}✓ Summary report generated${NC}"
echo ""

# Final output
echo -e "${BLUE}=== All Tests Completed ===${NC}"
echo -e "Results saved in: ${YELLOW}$RESULTS_DIR/${NC}"
echo -e "Summary report: ${YELLOW}$SUMMARY_FILE${NC}"
echo ""

# Show quick summary
echo -e "${BLUE}Quick Summary:${NC}"
cat "$SUMMARY_FILE" | tail -n 20

echo ""
echo -e "${GREEN}Done!${NC}"