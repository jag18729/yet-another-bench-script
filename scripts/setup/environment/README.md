# 🌍 Environment Setup Scripts

Complete environment setup scripts that configure everything needed for the performance testing suite.

## 📋 Available Scripts

### `setup_environment.sh`
All-in-one setup script that configures a complete testing environment.

**What it does:**
- Detects OS (Linux/macOS)
- Installs all client dependencies
- Optionally installs server components
- Configures Python environment
- Sets up directory structure
- Verifies installation

**Features:**
- Interactive mode with prompts
- Non-interactive mode for automation
- Minimal vs full installation options
- Automatic OS detection
- Rollback on failure

**Usage:**
```bash
# Interactive setup
./setup_environment.sh

# Non-interactive client setup
./setup_environment.sh --client --non-interactive

# Full setup (client + server)
./setup_environment.sh --full

# Minimal setup (essential tools only)
./setup_environment.sh --minimal
```

## 🎯 Installation Modes

### Minimal Mode
Installs only essential tools:
- Basic network tools (ping, dig)
- Core dependencies (curl, wget)
- No Python packages
- No server components

### Client Mode (Default)
Installs everything needed to run tests:
- All network testing tools
- Python and analysis packages
- Visualization libraries
- No server components

### Full Mode
Installs everything:
- All client tools
- Server components (iperf3, nginx)
- Development tools
- Documentation builders

## 🔄 Usage Examples

```bash
# Check what would be installed
./setup_environment.sh --dry-run

# Install for macOS client
./setup_environment.sh --client --os macos

# Install for Ubuntu server
./setup_environment.sh --full --os ubuntu

# Minimal install for testing
./setup_environment.sh --minimal
```

## ⚙️ Configuration Options

The script accepts environment variables:

```bash
# Skip Python packages
SKIP_PYTHON=1 ./setup_environment.sh

# Use specific package manager
PACKAGE_MANAGER=apt ./setup_environment.sh

# Install to custom prefix
PREFIX=/opt/perftest ./setup_environment.sh
```

## 📦 What Gets Installed

### System Packages
- **Network**: ping, traceroute, dig, iperf3
- **Transfer**: curl, wget, rsync, scp
- **Analysis**: jq, bc, awk, sed
- **Python**: python3, pip3

### Python Packages
- **Data**: pandas, numpy
- **Visualization**: matplotlib
- **Network**: requests
- **Utilities**: json, datetime

### Optional Components
- **Server**: nginx, bind9, iperf3-server
- **Monitoring**: htop, iotop, nethogs
- **Development**: git, make, gcc

## 🚨 Pre-Installation Checklist

1. **Permissions**: Need sudo access for system packages
2. **Internet**: Active connection required
3. **Space**: At least 500MB free
4. **Python**: Version 3.6 or higher

## 🔍 Verification

After installation:
```bash
# Run dependency check
../../utils/check_dependencies.sh

# Test basic functionality
../../utils/quick_test.sh

# Verify Python packages
python3 -c "import matplotlib, pandas, numpy; print('All packages OK')"
```

## 🛠️ Troubleshooting

**Permission Denied:**
```bash
# Run with sudo
sudo ./setup_environment.sh
```

**Package Manager Not Found:**
```bash
# Specify manually
PACKAGE_MANAGER=brew ./setup_environment.sh
```

**Python Package Failures:**
```bash
# Use virtual environment
python3 -m venv venv
source venv/bin/activate
./setup_environment.sh
```

## 🔄 Uninstallation

To remove installed components:
```bash
# Create uninstall script
./setup_environment.sh --generate-uninstall

# Run uninstall
./uninstall_environment.sh
```

## 📝 Notes

- Script creates backups before modifying system files
- Logs are saved to `setup_environment.log`
- Can be run multiple times safely (idempotent)
- Supports offline installation with cached packages