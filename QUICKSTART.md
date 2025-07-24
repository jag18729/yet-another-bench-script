# 🚀 Quick Start & Common Tasks

## 📋 First Time Setup

```bash
# 1. Check what you need
./scripts/utils/check_dependencies.sh

# 2. Install dependencies (choose one)
./scripts/setup/client/setup_client.sh        # Linux/macOS client
./scripts/setup/client/setup_macos_local.sh   # macOS optimized
./scripts/setup/server/setup_server.sh        # Test server
./scripts/setup/environment/setup_environment.sh  # Everything

# 3. Verify setup
./scripts/utils/quick_test.sh
```

## 🎯 Common Test Commands

```bash
# Run everything (YABS + network + DNS + transfer)
./scripts/core/performance_test_suite.sh -p pre

# Run specific tests only
./yabs_extended.sh -Y              # Skip YABS, run network tests
./yabs_extended.sh -N              # Skip network tests
./yabs_extended.sh -Y -T           # Skip YABS and traceroute

# Individual test scripts
./scripts/core/network_performance_test.sh -t ping -d 8.8.8.8
./scripts/core/dns_performance_test.sh -s 1.1.1.1
./scripts/core/data_transfer_test.sh -t wget -d http://speedtest.tele2.net/100MB.zip

# With configuration file
./scripts/core/performance_test_suite.sh -p pre -c configs/test_config.conf
```

## 📊 Analyzing Results

```bash
# Process results (compare pre/post)
python3 scripts/utils/process_results.py results/

# Visualize results
python3 scripts/utils/visualize_results.py comparison_results.csv

# Quick summary
cat results/test_results_*/test_summary_*.txt
```

## 🛠️ Common Modifications

### Change Test Targets
Edit `configs/test_config_template.conf`:
```bash
DESTINATION_IP=8.8.8.8      # Change ping/traceroute target
DNS_SERVER=1.1.1.1          # Change DNS server
DOWNLOAD_URL=http://...     # Change download test URL
IPERF_SERVER=192.168.1.100  # Set iperf3 server
```

### Add Custom Test
1. Create script in `scripts/core/my_test.sh`
2. Add to `performance_test_suite.sh`:
```bash
# Add new function
run_my_test() {
    echo "=== Running My Test ==="
    bash "${SCRIPT_DIR}/my_test.sh" -p "$TEST_PHASE"
}

# Add to run_tests_sequential()
[ "$RUN_MY_TEST" = true ] && { run_my_test; echo ""; }
```

### Change Output Location
In any test script:
```bash
OUTPUT_DIR="$PROJECT_ROOT/results/my_custom_dir"
```

## 🔍 Debugging

```bash
# Enable debug mode
export PERF_TEST_DEBUG=1

# Check script paths
find . -name "*.sh" -type f | head -20

# Verify results directory
ls -la results/

# Check recent test outputs
ls -lt results/*_results/ | head -10
```

## 📁 Key Locations

```
Scripts:      ./scripts/core/           # Main test scripts
Setup:        ./scripts/setup/          # Installation scripts
Utils:        ./scripts/utils/          # Helper tools
Config:       ./configs/                # Configuration files
Results:      ./results/                # All test outputs
Docs:         ./docs/                   # Documentation
```

## ⚡ Quick Fixes

**"Script not found" error:**
```bash
# Make all scripts executable
chmod +x scripts/**/*.sh
chmod +x *.sh
```

**"Permission denied" error:**
```bash
# Check ownership
ls -la scripts/core/

# Fix permissions
sudo chown -R $USER:$USER .
```

**"Command not found" error:**
```bash
# Check dependencies
./scripts/utils/check_dependencies.sh

# Install missing tool (example)
brew install iperf3    # macOS
sudo apt install iperf3 # Ubuntu
```

## 🎨 Customization Examples

### Run Tests Every Hour
```bash
# Add to crontab
0 * * * * cd /path/to/project && ./scripts/core/performance_test_suite.sh -p test -Y
```

### Custom Test Sequence
```bash
#!/bin/bash
# my_custom_test.sh

# Only ping tests to multiple targets
for target in 8.8.8.8 1.1.1.1 9.9.9.9; do
    ./scripts/core/network_performance_test.sh -t ping -d $target -c 10
done

# Only DNS tests to multiple servers  
for server in 8.8.8.8 1.1.1.1; do
    ./scripts/core/dns_performance_test.sh -s $server -c 50
done
```

### Email Results
```bash
# After tests complete
./scripts/core/performance_test_suite.sh -p test
cat results/test_results_*/test_summary_*.txt | mail -s "Test Results" you@example.com
```

## 📞 Help

```bash
# Script help
./scripts/core/performance_test_suite.sh -h
./scripts/core/network_performance_test.sh -h

# Check project structure
cat docs/PROJECT_STRUCTURE.md

# View setup guides
ls scripts/setup/*/README.md
```

---
Remember: All paths are relative to the project root directory!