# Network Performance Testing Suite

A comprehensive testing framework designed to measure and compare network performance before and after infrastructure or service changes. Built upon the foundation of YABS (Yet-Another-Bench-Script) with extensive network, DNS, and data transfer testing capabilities.

## 🎯 Purpose

When making network infrastructure changes, switching ISPs, or evaluating service plans, it's crucial to measure the actual performance impact. This suite provides automated testing and comparison tools to:

- Measure network latency, throughput, and reliability
- Test DNS performance across different servers
- Evaluate data transfer speeds using multiple protocols
- Generate visual comparisons and detailed reports
- Make data-driven decisions about network changes

This suite extends [YABS](https://github.com/masonr/yet-another-bench-script) with specialized network testing capabilities for comprehensive performance evaluation.

## 🚀 Quick Start

### 1. Clone and Setup
```bash
# Clone the repository
git clone <repository-url>
cd yet-another-bench-script

# Make scripts executable
chmod +x *.sh

# Check dependencies
./performance_test_suite.sh -h
```

### 2. Run Pre-Change Tests
```bash
# Option 1: Run all tests with defaults
./performance_test_suite.sh -p pre

# Option 2: Use a configuration file (recommended)
cp test_config_template.conf my_config.conf
# Edit my_config.conf with your test targets
./performance_test_suite.sh -p pre -c my_config.conf
```

### 3. Make Your Service Changes
Switch your network configuration, ISP, or service plan.

### 4. Run Post-Change Tests
```bash
# Run the same tests with 'post' phase
./performance_test_suite.sh -p post -c my_config.conf
```

### 5. Analyze Results
```bash
# Generate comparison report
python3 process_results.py test_results_* -r

# Create visual charts
python3 visualize_results.py test_results_* -s
```

## 📊 What Gets Tested

### System Performance (via YABS)
- CPU benchmarks (Geekbench)
- Memory performance
- Disk I/O speeds

### Network Performance
- **Latency**: Round-trip times to specified destinations
- **Packet Loss**: Network reliability metrics
- **Throughput**: Bandwidth testing with iperf3
- **Path Analysis**: Traceroute to identify routing changes

### DNS Performance
- Query response times
- DNS server comparison
- Success rates under load

### Data Transfer
- HTTP/HTTPS download speeds (wget, curl)
- SSH-based transfers (SCP, rsync)
- Protocol efficiency comparison

## 🛠️ Configuration

Create a custom configuration file to define your test parameters:

```bash
# Network targets
DESTINATION_IP=8.8.8.8          # Ping/traceroute target
IPERF_SERVER=192.168.1.100      # Your iperf3 server

# DNS servers to test
DNS_SERVER=8.8.8.8              # Primary DNS server

# Transfer test settings
REMOTE_HOST=server.example.com  # SSH server for SCP/rsync
REMOTE_USER=username
DOWNLOAD_URL=http://speedtest.tele2.net/100MB.zip
```

## 📈 Understanding Results

### Visual Dashboard
The suite generates a comprehensive dashboard showing:
- 🟢 **Green**: Performance improvements
- 🔴 **Red**: Performance degradations  
- 🟡 **Yellow**: Minimal change (±5%)

### Key Metrics
- **Latency**: Lower is better (ms)
- **Throughput**: Higher is better (Mbps)
- **DNS Response**: Lower is better (ms)
- **Transfer Speed**: Higher is better (MB/s)

### Example Output
```
Performance Test Results Comparison
===================================
### Network Performance ###
Ping RTT Change: -15.2%        ✅ Improvement
Throughput Change: +23.5%      ✅ Improvement

### DNS Performance ###
Response Time Change: -8.7%    ✅ Improvement
```

## 🔧 Advanced Usage

### Run Specific Tests Only
```bash
# Network tests only
./network_performance_test.sh -t all -d 8.8.8.8 -p pre

# DNS tests only
./dns_performance_test.sh -s 8.8.8.8 -p pre

# Skip certain test types
./performance_test_suite.sh -p pre -Y  # Skip YABS
./performance_test_suite.sh -p pre -N  # Skip network tests
```

### Parallel Testing with Git Worktrees
```bash
# Run tests in an isolated environment
./performance_test_suite.sh -p pre -w feature-test

# Tests run in a separate git worktree
# Useful for testing multiple configurations simultaneously
```

### Parallel Execution
```bash
# Run all tests concurrently (requires GNU parallel)
./performance_test_suite.sh -p pre -P
```

## 📋 Requirements

### Essential
- Bash 4.0+
- Basic Unix utilities (ping, dig, bc)
- Python 3.6+ (for analysis)

### Recommended
- **iperf3**: For bandwidth testing
- **matplotlib**: For visualizations (`pip install matplotlib`)
- **GNU parallel**: For concurrent test execution
- **jq**: For JSON processing

### Optional
- **dnsperf**: Advanced DNS testing
- **aria2c**: Parallel download testing

## 🏗️ Project Structure
```
├── performance_test_suite.sh    # Master orchestrator
├── network_performance_test.sh  # Ping, traceroute, iperf
├── dns_performance_test.sh      # DNS query testing
├── data_transfer_test.sh        # File transfer speeds
├── yabs.sh                      # System benchmarking
├── process_results.py           # Result comparison
├── visualize_results.py         # Chart generation
├── test_config_template.conf    # Configuration template
└── CLAUDE.md                    # Development notes
```

## 📝 Common Use Cases

### Network Service Change Testing
```bash
# Before changing network service/configuration
./performance_test_suite.sh -p pre -c network_config.conf

# After making changes
./performance_test_suite.sh -p post -c network_config.conf

# Compare results
python3 process_results.py test_results_* -r -o comparison.csv
```

### Multi-Region Comparison
```bash
# Test different regions using git worktrees
./performance_test_suite.sh -p pre -w us-east-1 -c us-east-1.conf
./performance_test_suite.sh -p pre -w eu-west-1 -c eu-west-1.conf
```

### Continuous Monitoring
```bash
# Run tests hourly and track trends
while true; do
    ./performance_test_suite.sh -p monitoring
    sleep 3600
done
```

## ❓ Troubleshooting

### "Command not found"
Install missing dependencies or skip those tests:
```bash
# Skip iperf tests if iperf3 not available
./performance_test_suite.sh -p pre -N
```

### "Permission denied"
```bash
chmod +x *.sh
```

### "Connection refused"
- Check firewall rules
- Verify test targets are accessible
- Ensure iperf3 server is running

### No visualization output
```bash
pip install matplotlib
```

## 🤝 Contributing

This suite is designed to be extensible. To add new tests:

1. Create a test script that outputs JSON results
2. Update the master script to include your test
3. Extend the Python processors for your data format
4. Document the new metrics in this README

## 📜 Acknowledgements

This project extends [YABS (Yet-Another-Bench-Script)](https://github.com/masonr/yet-another-bench-script) by Mason Rowe, adding specialized network performance testing capabilities for comprehensive infrastructure evaluation.

## 📄 License

This project extends YABS and maintains the same permissive license for network performance testing purposes.

---

**Need Help?** Check [CLAUDE.md](CLAUDE.md) for development notes and detailed testing procedures.
