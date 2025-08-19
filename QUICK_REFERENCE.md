# 🎯 Quick Reference Card

## Most Common Commands

### 1️⃣ One-Minute Test
```bash
./test.sh quick -Y -T
```
- ✅ Network connectivity (ping)
- ✅ DNS response time
- ✅ Basic iPerf3 (3 seconds)
- ❌ No YABS, No downloads

### 5️⃣ Five-Minute Test (RECOMMENDED)
```bash
./scripts/core/performance_test_suite.sh -q -c configs/quick_test.conf
```
- ✅ Quick YABS system info
- ✅ Network tests (20 pings)
- ✅ DNS performance (10 queries)
- ✅ iPerf3 TCP/UDP (10 seconds)
- ✅ Small download test (10MB)

### 🔟 Full Test (15 minutes)
```bash
./scripts/core/performance_test_suite.sh -c configs/test_config.conf --time 30
```
- ✅ Complete YABS benchmark
- ✅ Extended network tests
- ✅ Comprehensive DNS tests
- ✅ 30-second iPerf3 tests
- ✅ Large file transfers

## Quick Options

| Flag | Effect | Time Saved |
|------|--------|------------|
| `-Y` | Skip YABS | ~2-3 min |
| `-T` | Skip transfers | ~1-2 min |
| `-D` | Skip DNS | ~30 sec |
| `-N` | Skip network | ~1-2 min |
| `-q` | Quick mode | ~10 min |

## Common Scenarios

### "Just test my connection to the server"
```bash
./scripts/core/performance_test_suite.sh -Y -D -T \
  --server 192.168.2.10 --time 10
```

### "Test everything but quickly"
```bash
./test.sh quick
```

### "Compare before/after a change"
```bash
# Before
./test.sh quick --phase pre

# After change
./test.sh quick --phase post

# See differences
./test.sh compare
```

### "Maximum network stress test"
```bash
./scripts/core/performance_test_suite.sh -Y -D -T \
  --server 192.168.2.10 \
  --time 30 \
  --parallel 16 \
  --reverse
```

## Config File Shortcuts

```bash
# Use quick config (5 min tests)
-c configs/quick_test.conf

# Use full config (15 min tests)  
-c configs/test_config.conf

# Create your own
./test.sh create-config
```

## Time Estimates

- System Info: 5 seconds
- Each ping: 1 second
- Each DNS query: 0.5 seconds
- iPerf3 TCP: duration + 5 seconds
- iPerf3 UDP: duration + 5 seconds
- Download 1MB: 2-5 seconds
- Download 100MB: 30-60 seconds

## 🚨 If Tests Hang

Add these flags:
- `-I` - Skip network info lookup
- `-Y` - Skip YABS completely
- `-T` - Skip file downloads

Example:
```bash
./scripts/core/performance_test_suite.sh -q -I -T
```