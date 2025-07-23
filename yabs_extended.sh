#!/bin/bash

# Extended YABS Script - Wrapper for YABS + Additional Network Tests
# Purpose: Run standard YABS benchmarks plus extended network performance tests

YABS_EXTENDED_VERSION="v1.0.0"

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
TEST_PHASE="test"
YABS_ARGS=""

# Parse arguments
while getopts 'hYNDTp:y:' flag; do
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
        p) TEST_PHASE="${OPTARG}" ;;
        y) YABS_ARGS="${OPTARG}" ;;
        *) exit 1 ;;
    esac
done

# Header
echo -e "${BLUE}# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #${NC}"
echo -e "${BLUE}#            Extended YABS Benchmark Suite            #${NC}"
echo -e "${BLUE}#                  $YABS_EXTENDED_VERSION                     #${NC}"
echo -e "${BLUE}# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #${NC}"
echo ""
echo -e "Test Phase: ${YELLOW}$TEST_PHASE${NC}"
echo -e "Start Time: $(date)"
echo ""

# Create results directory
RESULTS_DIR="benchmark_results_${TEST_PHASE}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Run standard YABS if not skipped
if [ "$RUN_YABS" = true ]; then
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
    echo ""
fi

# Run extended network tests if not skipped
if [ "$RUN_NETWORK" = true ]; then
    echo -e "${GREEN}=== Running Extended Network Tests ===${NC}"
    
    # Check if network_test.sh exists
    if [ -f "./network_test.sh" ]; then
        ./network_test.sh "$TEST_PHASE" 2>&1 | tee "$RESULTS_DIR/network_test_output.txt"
        
        # Copy network test results to main results directory
        if [ -d "network_test_results" ]; then
            cp -r network_test_results/* "$RESULTS_DIR/" 2>/dev/null
        fi
        
        echo ""
        echo -e "${GREEN}✓ Network tests completed${NC}"
    else
        echo -e "${YELLOW}⚠ network_test.sh not found, using inline tests${NC}"
        
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
                for server in 8.8.8.8 1.1.1.1 9.9.9.9; do
                    echo -e "\nTesting DNS server $server..."
                    dig @"$server" google.com +stats > "$RESULTS_DIR/${TEST_PHASE}_dns_${server}.txt" 2>&1
                    query_time=$(grep "Query time:" "$RESULTS_DIR/${TEST_PHASE}_dns_${server}.txt" | awk '{print $4}')
                    if [ -n "$query_time" ]; then
                        echo -e "${GREEN}✓${NC} $server: Query time = ${query_time}ms"
                    else
                        echo -e "${RED}✗${NC} $server: Failed"
                    fi
                done
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