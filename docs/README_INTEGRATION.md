# YABS Extended - Network Performance Integration

## Overview

This project extends YABS (Yet Another Bench Script) with comprehensive network performance testing capabilities.

## Components

### 1. Main Scripts

- **`yabs.sh`** - Original YABS benchmark script
- **`yabs_extended.sh`** - Wrapper that integrates YABS with network tests
- **`network_test.sh`** - Standalone network performance tests (ping, DNS, traceroute)

### 2. Setup Scripts

- **`setup_environment.sh`** - Full automated setup for Linux servers (requires sudo)
- **`setup_macos_local.sh`** - Local setup for macOS development
- **`scripts/healthcheck.sh`** - Self-healing health check script

### 3. Systemd Services (Linux)

- **`systemd/yabs-monitor.service`** - Runs tests every 6 hours
- **`systemd/yabs-healthcheck.service`** - Health checks every 15 minutes

## Quick Start

### On macOS (Local Testing)

```bash
# Install dependencies and set up locally
./setup_macos_local.sh

# Run tests
./yabs_extended.sh              # All tests
./yabs_extended.sh -Y            # Network tests only
./yabs_extended.sh -p pre        # Pre-change testing
```

### On Linux Server (Production)

```bash
# Full setup with systemd services
sudo ./setup_environment.sh

# Or manual testing
./yabs_extended.sh -p test
```

### Remote Testing (Mac to Zorin VM)

```bash
# Copy scripts to server
scp *.sh zorin0:/home/rjgarcia/performance-tests/

# Run on server
ssh zorin0 "cd /home/rjgarcia/performance-tests && ./yabs_extended.sh -p test"

# View results
ssh zorin0 "ls -la /home/rjgarcia/performance-tests/benchmark_results_*"
```

## Usage Options

### yabs_extended.sh Options

```bash
-h         Show help message
-Y         Skip standard YABS tests
-N         Skip extended network tests
-D         Skip DNS tests
-T         Skip traceroute tests
-p PHASE   Set test phase (pre/test/post)
-y ARGS    Pass additional arguments to YABS
```

### Examples

```bash
# Run only network tests, skip traceroute
./yabs_extended.sh -Y -T

# Run YABS with reduced network tests
./yabs_extended.sh -y '-r'

# Pre and post comparison
./yabs_extended.sh -p pre
# ... make network changes ...
./yabs_extended.sh -p post
```

## Test Phases

1. **pre** - Baseline before changes
2. **test** - During testing
3. **post** - After changes

Results are organized by phase and timestamp for easy comparison.

## Results

Results are saved in timestamped directories:
- `benchmark_results_PHASE_TIMESTAMP/`
- Individual test results in JSON and text format
- Summary report in `summary.txt`

## Network Tests Included

1. **Ping Tests**
   - Latency to multiple DNS servers
   - Packet loss statistics
   - Min/avg/max RTT

2. **DNS Tests**
   - Query response times
   - Success rates
   - Multiple DNS server comparison

3. **Traceroute Tests**
   - Network path analysis
   - Hop count
   - Route changes detection

4. **YABS Standard Tests**
   - CPU benchmarks (Geekbench)
   - Disk I/O (fio)
   - Network speed (iperf3)

## Troubleshooting

### Missing Dependencies

```bash
# Check what's missing
which ping dig iperf3 fio

# Install on macOS
brew install iperf3 bind fio

# Install on Ubuntu/Debian
sudo apt-get install iperf3 dnsutils fio
```

### Permission Issues

```bash
# Make scripts executable
chmod +x *.sh

# For systemd services (Linux)
sudo systemctl status yabs-monitor.timer
```

### View Logs

```bash
# On Linux with systemd
journalctl -u yabs-monitor -f

# Local results
ls -la benchmark_results_*/
```

## Future Enhancements

See `CLAUDE.md` for planned features including:
- Systemd services with self-healing
- Automated dependency installation
- Real-time monitoring
- Cloud storage integration
- API endpoints for remote triggering