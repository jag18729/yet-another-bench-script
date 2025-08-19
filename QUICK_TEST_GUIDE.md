# Quick Performance Test Guide

## Recommended Test Commands by Duration

All examples assume:
- iPerf3 server is running on the same host (192.168.2.10)
- DNS server is 1.1.1.1 (Cloudflare)
- You have the config file at `configs/test_config.conf`

---

## 🚀 1-Minute Test (Ultra Quick)
**Best for:** Quick connectivity check, basic network health

```bash
# Option 1: Minimal test with just ping and DNS
./scripts/core/performance_test_suite.sh -q -Y -T \
  --server 192.168.2.10 \
  --ping-count 5 \
  --queries 5 \
  --time 3

# Option 2: Using config file (even faster)
./test.sh quick -Y -T
```

**What it tests:**
- 5 ping packets to 1.1.1.1
- 5 DNS queries
- 3-second iPerf3 test (TCP only)
- Total time: ~45-60 seconds

---

## ⚡ 5-Minute Test (Recommended Quick Test)
**Best for:** Daily checks, pre/post change validation

```bash
# Option 1: Balanced quick test
./scripts/core/performance_test_suite.sh -q \
  -c configs/test_config.conf \
  --time 10 \
  --ping-count 20

# Option 2: Network-focused quick test
./scripts/core/performance_test_suite.sh \
  --network-only \
  --server 192.168.2.10 \
  --time 10 \
  --parallel 4
```

**What it tests:**
- System info (CPU, RAM, Disk)
- 20 ping packets
- DNS performance (10 queries)
- 10-second iPerf3 (TCP + UDP)
- 1MB download test
- Total time: ~4-5 minutes

---

## 📊 15-Minute Test (Comprehensive)
**Best for:** Baseline establishment, thorough testing, troubleshooting

```bash
# Option 1: Full test with standard duration
./scripts/core/performance_test_suite.sh \
  -c configs/test_config.conf \
  --time 30 \
  --parallel 8 \
  --queries 50

# Option 2: Full test with reverse mode
./scripts/core/performance_test_suite.sh \
  -c configs/test_config.conf \
  --time 30 \
  --reverse \
  --parallel 4 \
  --ping-count 100
```

**What it tests:**
- Complete YABS benchmark
- 100 ping packets with statistics
- 50 DNS queries to multiple domains
- 30-second iPerf3 tests (TCP + UDP)
- Parallel streams (4-8)
- Both directions (with --reverse)
- 100MB download test
- Full traceroute
- Total time: ~12-15 minutes

---

## 🎯 Custom Quick Commands

### Network Only (2-3 minutes)
```bash
./test.sh network --server 192.168.2.10 --time 10
```

### DNS Focus (1-2 minutes)
```bash
./test.sh dns --queries 100
```

### iPerf3 Stress Test (5 minutes)
```bash
./scripts/core/performance_test_suite.sh \
  -Y -D -T \
  --server 192.168.2.10 \
  --time 60 \
  --parallel 16 \
  --reverse
```

---

## 📋 Pre-configured Test Scenarios

### 1. Quick Health Check (1 min)
```bash
# Just verify everything is working
./test.sh quick -Y -T --time 5
```

### 2. Before/After Comparison (5 min each)
```bash
# Before changes
./scripts/core/performance_test_suite.sh -p pre -q -c configs/test_config.conf

# Make your changes...

# After changes
./scripts/core/performance_test_suite.sh -p post -q -c configs/test_config.conf

# Compare results
./test.sh compare
```

### 3. Bandwidth Focus (3 min)
```bash
# Test maximum throughput
./scripts/core/performance_test_suite.sh \
  -Y -D \
  --server 192.168.2.10 \
  --time 20 \
  --parallel 8
```

### 4. Latency Focus (2 min)
```bash
# Test network responsiveness
./scripts/core/performance_test_suite.sh \
  -Y -T \
  --ping-count 100 \
  --queries 50
```

---

## ⚙️ Config File for All Tests

Create `configs/test_config.conf`:
```bash
# Optimized for local iPerf3 server
DESTINATION_IP=1.1.1.1
IPERF_SERVER=192.168.2.10
DNS_SERVER=1.1.1.1
DOWNLOAD_URL=http://speedtest.tele2.net/10MB.zip

# Quick mode adjustments
PING_COUNT=20
TRACE_HOPS=20
DNS_QUERIES=20
IPERF_TIME=10
```

---

## 🏃 Speed vs Thoroughness Guide

| Test Duration | Use Case | What You Get |
|--------------|----------|--------------|
| **1 minute** | Quick check | Basic connectivity, minimal metrics |
| **5 minutes** | Daily testing | Good balance of speed and data |
| **15 minutes** | Troubleshooting | Comprehensive metrics, multiple samples |

---

## 💡 Pro Tips

1. **For automated testing**, use the 5-minute test:
   ```bash
   ./scripts/core/performance_test_suite.sh -q -c configs/test_config.conf
   ```

2. **For CI/CD pipelines**, use the 1-minute test:
   ```bash
   ./test.sh quick -Y -T --time 3
   ```

3. **For baseline establishment**, use the 15-minute test:
   ```bash
   ./scripts/core/performance_test_suite.sh --full -c configs/test_config.conf
   ```

4. **Skip hanging tests** in environments with issues:
   ```bash
   ./scripts/core/performance_test_suite.sh -q -Y -I  # Skip YABS and network info
   ```

---

## 📊 Expected Output Times

- **System Info**: 2-3 seconds
- **Ping (20 packets)**: 20 seconds
- **DNS (20 queries)**: 10-15 seconds
- **iPerf3 (10 sec)**: 25 seconds (TCP + UDP)
- **Download (1MB)**: 2-5 seconds
- **Traceroute**: 10-20 seconds

Choose your test based on available time and required detail level!