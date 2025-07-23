#!/bin/bash

# Quick test of the integrated YABS network scripts

echo "=== Quick Network Performance Test ==="
echo "Testing basic functionality..."
echo

# Test 1: Basic ping
echo "1. Testing ping to 8.8.8.8..."
if ping -c 4 8.8.8.8 > /dev/null 2>&1; then
    avg_time=$(ping -c 4 8.8.8.8 | grep "avg" | awk -F'/' '{print $5}')
    echo "✓ Ping successful: avg RTT = ${avg_time}ms"
else
    echo "✗ Ping failed"
fi

# Test 2: DNS resolution
echo
echo "2. Testing DNS resolution..."
if command -v dig > /dev/null 2>&1; then
    query_time=$(dig @8.8.8.8 google.com +short +stats | grep "Query time:" | awk '{print $4}')
    if [ -n "$query_time" ]; then
        echo "✓ DNS query successful: ${query_time}ms"
    else
        # Fallback for different dig output
        dig @8.8.8.8 google.com > /tmp/dig_test.txt 2>&1
        if grep -q "ANSWER: [1-9]" /tmp/dig_test.txt; then
            echo "✓ DNS resolution successful"
        else
            echo "✗ DNS query failed"
        fi
    fi
else
    echo "⚠ dig not available"
fi

# Test 3: Check for iperf3
echo
echo "3. Checking iperf3..."
if command -v iperf3 > /dev/null 2>&1; then
    echo "✓ iperf3 installed: $(iperf3 --version | head -1)"
else
    echo "⚠ iperf3 not installed"
fi

# Test 4: Check scripts
echo
echo "4. Checking scripts..."
for script in yabs.sh yabs_extended.sh network_test.sh; do
    if [ -f "./$script" ] && [ -x "./$script" ]; then
        echo "✓ $script is present and executable"
    else
        echo "✗ $script not found or not executable"
    fi
done

# Test 5: Run minimal network test
echo
echo "5. Running minimal network test..."
if [ -x "./network_test.sh" ]; then
    # Create minimal test with reduced counts
    ./yabs_extended.sh -Y -T -p quick_test 2>&1 | grep -E "✓|✗|Running|completed"
else
    echo "✗ network_test.sh not executable"
fi

echo
echo "=== Quick test complete ==="