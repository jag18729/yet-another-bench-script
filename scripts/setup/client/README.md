# 🖥️ Client Setup Scripts

Scripts for setting up machines that will run performance tests.

## 📋 Available Scripts

### `setup_client.sh`
General client setup script that works on both Linux and macOS.

**What it installs:**
- Network tools: `ping`, `traceroute`, `dig`, `iperf3`
- Data transfer tools: `curl`, `wget`, `rsync`
- Analysis tools: `jq`, `bc`, `python3`
- Python packages: `matplotlib`, `pandas`, `numpy`

**Usage:**
```bash
./setup_client.sh
```

### `setup_macos_local.sh`
macOS-specific setup script with additional optimizations.

**What it does:**
- Installs Homebrew (if not present)
- Installs all required tools via Homebrew
- Sets up Python environment
- Configures macOS-specific network settings
- Optional: Installs GUI tools for monitoring

**Usage:**
```bash
./setup_macos_local.sh
```

## 🎯 Which Script to Use?

- **Linux Users**: Use `setup_client.sh`
- **macOS Users**: Use `setup_macos_local.sh` for best results
- **Minimal Setup**: Use `setup_client.sh` with `--minimal` flag

## ⚡ Quick Setup

```bash
# Check what's missing first
../../../utils/check_dependencies.sh

# Run appropriate setup
./setup_client.sh        # Linux
./setup_macos_local.sh   # macOS
```

## 🔧 Manual Installation

If you prefer manual installation:

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y curl wget git bc jq dnsutils \
                    iputils-ping traceroute iperf3 \
                    python3 python3-pip
pip3 install matplotlib pandas numpy
```

### macOS
```bash
brew install wget jq iperf3 python3
pip3 install matplotlib pandas numpy
```

## 📝 Notes

- Scripts require sudo/admin privileges for system packages
- Python packages install to user directory by default
- Network tools may require firewall adjustments
- Some tools (like iperf3) need corresponding servers to test against