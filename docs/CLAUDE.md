# Performance Test Suite - Project Overview

## Current Status
This project extends the existing YABS (Yet Another Bench Script) with comprehensive network performance testing capabilities for evaluating service plan changes (Local Priority vs Global Priority).

## Completed Components

### 1. Core Test Scripts
- ✅ **network_performance_test.sh**: Ping, traceroute, and iperf3 tests
- ✅ **dns_performance_test.sh**: DNS query performance testing with dig/dnsperf
- ✅ **data_transfer_test.sh**: SCP, rsync, wget, curl transfer speed tests
- ✅ **performance_test_suite.sh**: Master orchestration script with:
  - Pre/post test phase support
  - Configuration file support
  - Git worktree isolation capability
  - Parallel test execution option

### 2. Analysis Tools
- ✅ **process_results.py**: Parses JSON/text results and generates comparison reports
- ✅ **visualize_results.py**: Creates charts and dashboards for visual analysis
- ✅ **test_config_template.conf**: Configuration template for test parameters

## Next Objectives

### 1. Testing & Verification (Priority: HIGH)
- [ ] Test all scripts with various network configurations
- [ ] Verify JSON output parsing for all test types
- [ ] Test parallel execution mode with GNU parallel
- [ ] Validate git worktree functionality
- [ ] Test cross-platform compatibility (Linux/macOS)
- [ ] Error handling validation (network failures, missing tools)

### 2. Enhanced Features (Priority: MEDIUM)
- [ ] Add automatic dependency checking and installation script
- [ ] Implement real-time monitoring during long-running tests
- [ ] Add support for custom test intervals/scheduling
- [ ] Create automated report generation (PDF/HTML)
- [ ] Add cloud storage integration for results
- [ ] Implement test result history tracking

### 3. Documentation (Priority: MEDIUM)
- [ ] Create detailed troubleshooting guide
- [ ] Add example use cases for different scenarios
- [ ] Document interpretation of results
- [ ] Create video tutorials for setup and usage

### 4. Integration Features (Priority: LOW)
- [ ] REST API for remote test triggering
- [ ] Integration with monitoring systems (Prometheus/Grafana)
- [ ] Slack/email notifications for test completion
- [ ] Docker containerization for easy deployment
- [ ] Create systemd services for all test scripts with self-healing capabilities
- [ ] Add automatic environment setup and dependency installation
- [ ] Implement service health monitoring and auto-restart on failures

## Testing Checklist Before Implementation

### Basic Functionality Tests
```bash
# 1. Test individual components
./network_performance_test.sh -t ping -d 8.8.8.8 -p pre
./dns_performance_test.sh -s 8.8.8.8 -p pre
./data_transfer_test.sh -t wget -d http://speedtest.tele2.net/10MB.zip -p pre

# 2. Test master script with minimal config
./performance_test_suite.sh -p pre -Y -T  # Skip YABS and transfer tests

# 3. Test with full configuration
cp test_config_template.conf test_config.conf
# Edit test_config.conf with actual values
./performance_test_suite.sh -p pre -c test_config.conf
```

### Edge Case Tests
```bash
# 1. Test with missing dependencies
# Temporarily rename iperf3, test graceful fallback

# 2. Test with network failures
# Use invalid IPs/hostnames

# 3. Test with insufficient permissions
# Run without sudo where needed

# 4. Test result processing with incomplete data
python3 process_results.py test_results_dir/
```

### Performance Tests
```bash
# 1. Test parallel execution
./performance_test_suite.sh -p pre -P

# 2. Test with large file transfers
./data_transfer_test.sh -t wget -s 1G -p pre

# 3. Test extended duration
./network_performance_test.sh -t ping -c 1000 -d 8.8.8.8 -p pre
```

## Known Issues / Limitations

1. **Platform Specific**:
   - Some commands may need adjustment for different Unix variants
   - macOS vs Linux differences in stat, dd commands

2. **Dependencies**:
   - Not all systems have iperf3, dnsperf installed
   - Python matplotlib required for visualizations

3. **Network Requirements**:
   - Requires outbound connectivity for tests
   - Firewall rules may block some tests

## Quick Start for New Sessions

1. **Review current state**:
   ```bash
   ls -la *.sh *.py
   cat test_config_template.conf
   ```

2. **Run a quick test**:
   ```bash
   ./network_performance_test.sh -t ping -d 8.8.8.8 -p test
   ```

3. **Check for dependencies**:
   ```bash
   which iperf3 dig python3 jq parallel
   ```

## Development Guidelines

1. **JSON Output**: All test scripts should output JSON for automated processing
2. **Error Handling**: Scripts should fail gracefully with informative messages
3. **Modularity**: Each test type should be independently runnable
4. **Consistency**: Use consistent naming for output files: `{prefix}_{test}_{target}_{timestamp}.{ext}`

## Contact & Repository

- Original YABS: https://github.com/masonr/yet-another-bench-script
- This extension is designed for comprehensive network performance testing
- Setup includes Mac as client and Parallels Zorin VM as server
- Two new setup scripts added:
  - setup_server.sh: Configures Zorin VM with iperf3, SSH, nginx, DNS servers
  - setup_client.sh: Configures Mac with necessary tools and connectivity

## Session Notes

- All scripts are chmod +x and ready to run
- Python scripts require matplotlib for visualizations
- Configuration file is optional but recommended for consistency
- Git worktree support allows parallel testing in isolated environments