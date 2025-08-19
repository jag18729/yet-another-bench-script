# 🚀 Yet Another Bench Script - Extended Performance Testing Suite

> 📌 **Note**: This is part of the [DNS Performance Testing Suite](../README.md). For DNS migration testing, see [DNS Performance Testing Tool](../DNS-Performance-Testing/README.md).

A comprehensive network and system performance testing suite that extends the original [YABS (Yet Another Bench Script)](https://github.com/masonr/yet-another-bench-script) with advanced network testing capabilities.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
- [Test Components](#test-components)
- [Configuration](#configuration)
- [Advanced Usage](#advanced-usage)
- [Results & Analysis](#results--analysis)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Contributing](#contributing)

## 🎯 Overview

This performance testing suite provides comprehensive benchmarking capabilities for:
- **System Performance**: CPU, memory, disk I/O (via YABS)
- **Network Performance**: Latency, throughput, path analysis
- **DNS Performance**: Query response times, reliability
- **Data Transfer**: Download/upload speeds, transfer protocols

Perfect for:
- 🔄 Evaluating service plan changes
- 📊 Baseline performance documentation
- 🚨 Troubleshooting performance issues
- 📈 Capacity planning
- 🔍 Network diagnostics

## ✨ Features

- **Comprehensive Testing**: System, network, DNS, and data transfer tests
- **Pre/Post Comparison**: Compare performance before and after changes
- **Automated Analysis**: JSON output with visualization tools
- **Parallel Execution**: Run multiple tests simultaneously
- **Git Worktree Support**: Isolated test environments
- **Cross-Platform**: Works on Linux and macOS
- **Modular Design**: Run individual tests or complete suite

## 🚀 Quick Start

### Recommended Tests by Time

```bash
# 1-Minute Quick Check
./test.sh quick -Y -T --time 5

# 5-Minute Recommended Test (with iPerf3 server at 192.168.2.10)
./scripts/core/performance_test_suite.sh -q -c configs/test_config.conf

# 15-Minute Comprehensive Test
./scripts/core/performance_test_suite.sh --full -c configs/test_config.conf
```

See [QUICK_TEST_GUIDE.md](QUICK_TEST_GUIDE.md) for detailed test scenarios.

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/yet-another-bench-script.git
cd yet-another-bench-script

# 2. Run setup (installs dependencies)
./scripts/setup/setup_client.sh

# 3. Run a complete test
./scripts/core/performance_test_suite.sh -p pre

# 4. Make your system changes...

# 5. Run post-change test
./scripts/core/performance_test_suite.sh -p post

# 6. Analyze results
python3 scripts/utils/process_results.py results/
```

## 📦 Installation

### Automated Installation

Choose the appropriate setup based on your needs:

```bash
# For test clients (your local machine)
./scripts/setup/client/setup_client.sh        # Linux/macOS general
./scripts/setup/client/setup_macos_local.sh   # macOS optimized

# For test servers (remote endpoints)
./scripts/setup/server/setup_server.sh        # General server setup
./scripts/setup/server/setup_ssh_zorin.sh     # Zorin/Ubuntu VM setup

# For complete environment (all-in-one)
./scripts/setup/environment/setup_environment.sh
```

📁 **Setup Directory Structure:**
- `scripts/setup/client/` - Scripts for machines running tests
- `scripts/setup/server/` - Scripts for test target servers  
- `scripts/setup/environment/` - Complete environment setup

See [Setup Documentation](./scripts/setup/README.md) for detailed information.

### Manual Installation

<details>
<summary>Ubuntu/Debian</summary>

```bash
sudo apt update
sudo apt install -y curl wget git bc jq dnsutils iputils-ping \
                    traceroute iperf3 python3 python3-pip

pip3 install matplotlib pandas numpy requests
```
</details>

<details>
<summary>RHEL/CentOS/Fedora</summary>

```bash
sudo yum install -y curl wget git bc jq bind-utils iputils \
                    traceroute iperf3 python3 python3-pip

pip3 install matplotlib pandas numpy requests
```
</details>

<details>
<summary>macOS</summary>

```bash
# Install Homebrew first if not present
brew install wget jq iperf3 python3

pip3 install matplotlib pandas numpy requests
```
</details>

### Dependency Check

```bash
# Check all dependencies
./scripts/utils/check_dependencies.sh
```

## 📖 Usage

### Basic Usage

```bash
# Run all tests (pre-change baseline)
./scripts/core/performance_test_suite.sh -p pre

# Run specific tests only
./scripts/core/network_performance_test.sh -t ping -d 8.8.8.8
./scripts/core/dns_performance_test.sh -s 1.1.1.1
./scripts/core/data_transfer_test.sh -t wget -d http://speedtest.tele2.net/100MB.zip
```

### Master Script Options

```bash
./scripts/core/performance_test_suite.sh [options]

Options:
  -p <phase>     Test phase: pre, post, or test (default: pre)
  -c <config>    Configuration file path
  -Y             Skip YABS system tests
  -N             Skip network tests
  -D             Skip DNS tests
  -T             Skip transfer tests
  -P             Enable parallel execution
  -w <name>      Use git worktree
  -h             Show help
```

### Configuration File

Create a custom configuration file:

```bash
cp configs/test_config_template.conf configs/my_config.conf
# Edit my_config.conf with your settings

# Use the configuration
./scripts/core/performance_test_suite.sh -p pre -c configs/my_config.conf
```

## 🧪 Test Components

### 1. System Performance (YABS)
- **CPU**: Single and multi-core benchmarks
- **Memory**: Speed and latency tests
- **Disk I/O**: Sequential and random read/write
- **Network Speed**: Speedtest.net integration

### 2. Network Performance
- **Ping Tests**: Latency and packet loss measurement
- **Traceroute**: Network path analysis
- **iPerf3**: Throughput testing (requires server)

### 3. DNS Performance
- **Query Speed**: Response time measurement
- **Reliability**: Success rate tracking
- **Multiple Servers**: Test various DNS providers

### 4. Data Transfer
- **HTTP Downloads**: wget/curl speed tests
- **Protocol Testing**: Various transfer methods
- **Large File Transfers**: Bandwidth utilization

## ⚙️ Configuration

### Configuration File Format

```bash
# Network test configuration
DESTINATION_IP=8.8.8.8
IPERF_SERVER=192.168.1.100

# DNS test configuration
DNS_SERVER=1.1.1.1

# Data transfer configuration
DOWNLOAD_URL=http://speedtest.tele2.net/100MB.zip
```

### Environment Variables

```bash
# Set custom results directory
export PERF_TEST_RESULTS_DIR=/custom/path/to/results

# Enable debug output
export PERF_TEST_DEBUG=1
```

## 🔧 Advanced Usage

### macOS Compatibility

The test suite includes macOS compatibility features:

- **YABS Tests**: Automatically uses macOS-compatible wrapper that skips Linux-specific tests
- **Network Tests**: All network tests (ping, traceroute, iperf3) work on macOS
- **DNS Tests**: Fully compatible with macOS
- **Data Transfer**: wget/curl tests work normally

**Note**: Some YABS features (disk I/O, memory tests) are limited on macOS. For comprehensive testing, use a Linux system.

### Parallel Execution

```bash
# Run tests in parallel (requires GNU parallel)
./scripts/core/performance_test_suite.sh -p pre -P
```

### Git Worktree Isolation

```bash
# Create isolated test environment
./scripts/core/performance_test_suite.sh -p pre -w feature-test
```

### Custom Test Selection

```bash
# Run only network and DNS tests
./scripts/core/performance_test_suite.sh -p pre -Y -T
```

### Scheduled Testing

```bash
# Add to crontab for regular testing
0 */6 * * * /path/to/scripts/core/performance_test_suite.sh -p test -c /path/to/config.conf
```

## 📊 Results & Analysis

### Results Location

```
results/
├── test_results_YYYY-MM-DD_HH-MM-SS/
│   ├── test_summary_*.txt
│   └── yabs_output.txt
├── network_test_results/
│   ├── *_ping_*.json
│   └── *_traceroute_*.json
├── dns_test_results/
│   └── *_dns_*.json
└── data_transfer_results/
    └── *_transfer_*.json
```

### Analysis Tools

```bash
# Generate comparison report
python3 scripts/utils/process_results.py results/

# Visualize results (requires matplotlib)
python3 scripts/utils/visualize_results.py results/comparison_results.csv
```

### JSON Output Format

All tests produce JSON output for easy parsing:

```json
{
  "test": "ping",
  "target": "8.8.8.8",
  "timestamp": "2024-01-15_10-30-45",
  "avg_rtt": "15.234",
  "packet_loss": "0%"
}
```

## 🔍 Troubleshooting

### Common Issues

**Missing Dependencies**
```bash
./scripts/utils/check_dependencies.sh
# Follow installation suggestions
```

**Permission Errors**
```bash
chmod +x scripts/**/*.sh
chmod +x *.sh
```

**Network Test Failures**
- Ensure firewall allows ICMP, DNS queries
- Check network connectivity
- Verify DNS server accessibility

**iPerf3 Server Required**
```bash
# Start iperf3 server on another machine
iperf3 -s

# Update configuration with server IP
IPERF_SERVER=192.168.1.100
```

### Debug Mode

```bash
# Enable verbose output
export PERF_TEST_DEBUG=1
./scripts/core/performance_test_suite.sh -p test
```

## 👨‍💻 Development

### Project Structure

```
yet-another-bench-script/
├── scripts/
│   ├── core/           # Main test scripts
│   ├── setup/          # Installation scripts
│   └── utils/          # Utility scripts
├── configs/            # Configuration files
├── lib/               # Shared libraries
├── results/           # Test results (gitignored)
├── docs/              # Documentation
└── systemd/           # Service files
```

### Development Guidelines

1. **Code Style**: Follow existing patterns, use shellcheck
2. **Error Handling**: Always check command success
3. **Output**: Support both human-readable and JSON formats
4. **Modularity**: Keep functions focused and reusable
5. **Documentation**: Update docs with new features

### Testing

```bash
# Run basic functionality tests
./scripts/core/network_performance_test.sh -t ping -d 8.8.8.8 -p test

# Test with invalid inputs
./scripts/core/dns_performance_test.sh -s 999.999.999.999 -p test

# Check JSON output
cat results/network_test_results/*.json | jq .
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project extends [YABS](https://github.com/masonr/yet-another-bench-script) and maintains the same open-source spirit.

## 🙏 Acknowledgments

- Original [YABS](https://github.com/masonr/yet-another-bench-script) by masonr
- Network testing inspired by various open-source tools
- Community contributions and feedback

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/yet-another-bench-script/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/yet-another-bench-script/discussions)
- **Documentation**: [Full Docs](./docs/)

---

Made with ❤️ for the benchmarking community