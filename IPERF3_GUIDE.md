# 🚀 iPerf3 Testing Guide

## Quick Start

### Prerequisites
1. **Install iPerf3 on both machines:**
   ```bash
   # macOS
   brew install iperf3
   
   # Linux
   sudo apt-get install iperf3  # Debian/Ubuntu
   sudo yum install iperf3      # RHEL/CentOS
   ```

2. **Start iPerf3 server on target machine:**
   ```bash
   # On the server machine (e.g., 192.168.2.10)
   iperf3 -s
   
   # Or with specific port
   iperf3 -s -p 5201
   ```

## Running iPerf3 Tests

### 1️⃣ Basic Test (TCP)
```bash
# Test to a specific server
./scripts/core/performance_test_suite.sh -Y -D -T \
  --server 192.168.2.10 \
  --time 10
```

### 2️⃣ Quick Network Test Only
```bash
# Just network tests (ping, traceroute, iperf3)
./test.sh network --server 192.168.2.10
```

### 3️⃣ Advanced iPerf3 Options

#### Reverse Mode (Server → Client)
```bash
./scripts/core/performance_test_suite.sh -Y -D -T \
  --server 192.168.2.10 \
  --reverse \
  --time 30
```

#### Parallel Streams
```bash
./scripts/core/performance_test_suite.sh -Y -D -T \
  --server 192.168.2.10 \
  --parallel 8 \
  --time 20
```

#### Maximum Performance Test
```bash
./scripts/core/performance_test_suite.sh -Y -D -T \
  --server 192.168.2.10 \
  --parallel 16 \
  --reverse \
  --time 60
```

### 4️⃣ Direct iPerf3 Script Usage
```bash
# Basic TCP test
./scripts/core/network_performance_test.sh \
  -t iperf \
  -s 192.168.2.10 \
  -i 10 \
  -p pre

# With reverse mode and parallel streams
./scripts/core/network_performance_test.sh \
  -t iperf \
  -s 192.168.2.10 \
  -i 30 \
  -R \
  -P 8 \
  -p pre
```

## Common Test Scenarios

### Local Network Test (1 minute)
```bash
# Quick LAN performance check
./scripts/core/performance_test_suite.sh -q \
  --server 192.168.1.1 \
  --time 5 \
  -Y -D -T
```

### Internet Speed Test (5 minutes)
```bash
# Test to public iPerf3 server
./scripts/core/performance_test_suite.sh \
  --server iperf.he.net \
  --time 30 \
  --parallel 4
```

### Before/After Comparison
```bash
# Before changes
./scripts/core/performance_test_suite.sh \
  --server 192.168.2.10 \
  --time 20 \
  -p pre \
  -Y -D

# After changes
./scripts/core/performance_test_suite.sh \
  --server 192.168.2.10 \
  --time 20 \
  -p post \
  -Y -D

# Compare results
./test.sh compare
```

## Public iPerf3 Servers

If you don't have your own server, use these public ones:

```bash
# Hurricane Electric (Multiple locations)
--server iperf.he.net

# Bouygues Telecom (Paris)
--server iperf.par2.as5410.net

# Online.net (France)
--server ping.online.net

# Example usage
./scripts/core/performance_test_suite.sh \
  --server iperf.he.net \
  --time 10 \
  -Y -D -T
```

## Understanding Results

### TCP Test Output
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  iPERF3 TCP RESULTS - 192.168.2.10
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Throughput:  940.2 Mbps          ← Network speed
  Duration:    10 seconds
  Mode:        Normal (Client → Server)
  Streams:     1 parallel
```

### UDP Test Output
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  iPERF3 UDP RESULTS - 192.168.2.10
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Throughput:  50.0 Mbps
  Jitter:      0.182ms             ← Network stability
  Packet Loss: 0.00%               ← Reliability
  Duration:    10 seconds
```

## Troubleshooting

### "Connection refused" Error
```bash
# Check if server is running
ssh user@192.168.2.10 'iperf3 -s -D'

# Or use a public server
--server iperf.he.net
```

### Firewall Issues
```bash
# Server needs port 5201 open
sudo ufw allow 5201/tcp  # Ubuntu
sudo firewall-cmd --add-port=5201/tcp --permanent  # RHEL
```

### Test Specific Direction
```bash
# Upload test (default)
--server 192.168.2.10

# Download test
--server 192.168.2.10 --reverse
```

## Quick Reference

| Time | Command | What it tests |
|------|---------|---------------|
| 30s | `./test.sh network --server IP --time 5` | Basic connectivity |
| 2min | `./scripts/core/performance_test_suite.sh -q --server IP` | Quick performance |
| 5min | `./scripts/core/performance_test_suite.sh --server IP --time 30` | Detailed performance |
| 10min | `./scripts/core/performance_test_suite.sh --server IP --time 60 --parallel 8` | Stress test |

## Config File Setup

Create a custom config with your iPerf3 server:

```bash
cat > my_iperf_config.conf << EOF
# My iPerf3 Configuration
IPERF_SERVER=192.168.2.10
IPERF_TIME=30
IPERF_PARALLEL=4
IPERF_REVERSE=false

# Other settings
DESTINATION_IP=1.1.1.1
DNS_SERVER=1.1.1.1
PING_COUNT=50
EOF

# Use it
./scripts/core/performance_test_suite.sh -c my_iperf_config.conf
```