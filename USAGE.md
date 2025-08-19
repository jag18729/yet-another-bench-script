# Performance Test Suite - Usage Guide

## Quick Start

The easiest way to run tests is using the `test.sh` wrapper:

```bash
# Quick 5-second test
./test.sh quick

# Full 30-second test  
./test.sh full

# Network tests only
./test.sh network

# DNS tests only
./test.sh dns

# Compare pre/post results
./test.sh compare
```

## Common Test Scenarios

### 1. Basic Testing with Custom iPerf Server

```bash
# Quick test with your server
./test.sh quick --server 192.168.1.100

# Full test with config file
./test.sh full --config configs/test_config.conf
```

### 2. Advanced Network Testing

```bash
# Reverse mode (server sends data to client)
./scripts/core/performance_test_suite.sh --server 192.168.1.100 --reverse

# Multiple parallel streams
./scripts/core/performance_test_suite.sh --server 192.168.1.100 --parallel 4

# Custom test duration
./scripts/core/performance_test_suite.sh --server 192.168.1.100 --time 30

# All network options combined
./scripts/core/performance_test_suite.sh \
  --server 192.168.1.100 \
  --reverse \
  --parallel 8 \
  --time 60
```

### 3. File Transfer Testing

```bash
# Test upload speed
./scripts/core/performance_test_suite.sh \
  --upload /path/to/large_file.bin \
  --remote server.example.com \
  --user myusername \
  --path /tmp

# Test download speed with custom URL
./scripts/core/performance_test_suite.sh \
  --download http://speedtest.yourserver.com/1GB.bin
```

### 4. DNS Performance Testing

```bash
# Test specific DNS server
./scripts/core/performance_test_suite.sh \
  --dns 8.8.8.8 \
  --queries 100

# Test multiple DNS servers
for dns in 1.1.1.1 8.8.8.8 9.9.9.9; do
  ./scripts/core/performance_test_suite.sh -N -T --dns $dns --queries 50
done
```

### 5. Pre/Post Comparison Workflow

```bash
# Before changes (pre test)
./scripts/core/performance_test_suite.sh -p pre -c configs/test_config.conf

# Make your network/system changes...

# After changes (post test)
./scripts/core/performance_test_suite.sh -p post -c configs/test_config.conf

# Compare results
./test.sh compare
```

## Configuration File

Create a configuration file to save your test parameters:

```bash
# Generate template
./test.sh create-config

# Edit the file
cat > my_config.conf <<EOF
# Network test configuration
DESTINATION_IP=1.1.1.1
IPERF_SERVER=192.168.2.10
IPERF_REVERSE=false
IPERF_PARALLEL=4
IPERF_TIME=30

# DNS test configuration  
DNS_SERVER=1.1.1.1
DNS_QUERIES=50

# File transfer configuration
REMOTE_HOST=myserver.com
REMOTE_USER=admin
DOWNLOAD_URL=http://speedtest.tele2.net/1GB.zip

# Test parameters
PING_COUNT=100
TRACE_HOPS=30
EOF

# Run with config
./scripts/core/performance_test_suite.sh -c my_config.conf
```

## Command Line Options Reference

### Basic Options
- `-p <pre|post>` - Test phase (default: pre)
- `-c <config_file>` - Configuration file
- `-h` - Display help
- `-v` - Verbose output
- `-q` - Quick mode (reduced iterations)

### Test Selection
- `-Y` - Skip YABS benchmark
- `-N` - Skip network tests
- `-D` - Skip DNS tests
- `-T` - Skip data transfer tests

### Network Test Options
- `--server <ip>` - iPerf3 server IP
- `--reverse` - Reverse mode (server sends)
- `--parallel <n>` - Parallel streams (default: 1)
- `--time <seconds>` - Test duration (default: 10)
- `--ping-count <n>` - Ping packets (default: 20)
- `--trace-hops <n>` - Max traceroute hops (default: 30)

### DNS Test Options
- `--dns <server>` - DNS server to test
- `--queries <n>` - Number of queries (default: 20)

### File Transfer Options
- `--upload <file>` - File to upload
- `--download <url>` - URL to download
- `--remote <host>` - Remote host
- `--user <username>` - Remote username
- `--path <path>` - Remote path

### Execution Options
- `-P` - Run tests in parallel
- `-w <worktree>` - Use git worktree

## Quick Commands

```bash
# Quick network check
./test.sh quick --server 192.168.1.100

# Full performance audit
./test.sh full --server 192.168.1.100 --parallel 4

# DNS server comparison
./test.sh dns --dns 1.1.1.1

# Upload speed test
./test.sh --upload /tmp/test_1GB.bin --server 192.168.1.100

# Custom duration test
./scripts/core/performance_test_suite.sh --server 192.168.1.100 --time 120
```

## Results

All results are saved in timestamped directories:
- Location: `results/Aug-04-2025-Extended-Test-Suite-Results/`
- Files include:
  - Raw output files (.txt)
  - JSON formatted results (.json)
  - Summary reports
  - YABS benchmark results

## Parallel Execution

For faster testing with GNU parallel installed:

```bash
# Run all tests in parallel
./scripts/core/performance_test_suite.sh -P -c configs/test_config.conf

# Parallel with specific tests
./scripts/core/performance_test_suite.sh -P --server 192.168.1.100 -Y
```

## Tips

1. **For Quick Testing**: Use `./test.sh quick` for rapid checks
2. **For Thorough Testing**: Use `./test.sh full` or custom durations
3. **For Automation**: Use config files to maintain consistent parameters
4. **For Comparison**: Always use the same config file for pre/post tests
5. **For Debugging**: Add `-v` for verbose output

## Examples by Use Case

### Home Network Testing
```bash
./test.sh quick --server 192.168.1.1 --dns 192.168.1.1
```

### Data Center Performance
```bash
./scripts/core/performance_test_suite.sh \
  --server 10.0.0.100 \
  --parallel 16 \
  --time 300 \
  --reverse
```

### ISP Speed Verification
```bash
./test.sh full \
  --download http://speedtest.net/10GB.bin \
  --server speedtest.myisp.com
```

### Cloud Instance Benchmarking
```bash
./scripts/core/performance_test_suite.sh \
  -c cloud_config.conf \
  -P \
  --time 60
```