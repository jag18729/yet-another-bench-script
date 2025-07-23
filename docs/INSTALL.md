# YABS Extended Installation Guide

## Quick Installation

Run as root or with sudo:

```bash
sudo ./setup_environment.sh
```

This will:
- Install all dependencies
- Set up directory structure
- Install systemd services
- Configure automatic monitoring
- Run initial tests

## Manual Installation

### 1. Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y curl wget git jq bc dnsutils net-tools iputils-ping traceroute iperf3 fio python3 python3-pip python3-matplotlib
```

**CentOS/RHEL:**
```bash
sudo yum install -y epel-release
sudo yum install -y curl wget git jq bc bind-utils net-tools iputils traceroute iperf3 fio python3 python3-pip python3-matplotlib
```

**macOS:**
```bash
brew install curl wget git jq coreutils bind iperf3 fio python3
pip3 install matplotlib pandas numpy
```

### 2. Create Directory Structure

```bash
sudo mkdir -p /opt/yabs/{scripts,results,bin}
sudo mkdir -p /var/log/yabs
```

### 3. Copy Scripts

```bash
sudo cp yabs.sh yabs_extended.sh network_test.sh /opt/yabs/
sudo cp scripts/*.sh /opt/yabs/scripts/
sudo chmod +x /opt/yabs/*.sh /opt/yabs/scripts/*.sh
```

### 4. Install Systemd Services (Linux only)

```bash
sudo cp systemd/*.service systemd/*.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now yabs-monitor.timer yabs-healthcheck.timer
```

## Usage

### Run Tests Manually

```bash
# Run all tests
/opt/yabs/yabs_extended.sh

# Run only network tests
/opt/yabs/yabs_extended.sh -Y

# Run with specific phase
/opt/yabs/yabs_extended.sh -p pre
/opt/yabs/yabs_extended.sh -p post

# Skip specific tests
/opt/yabs/yabs_extended.sh -T  # Skip traceroute
/opt/yabs/yabs_extended.sh -D  # Skip DNS tests
```

### View Results

```bash
# Latest results
ls -la /opt/yabs/results/

# View logs
tail -f /var/log/yabs/monitor.log
journalctl -u yabs-monitor -f

# Check service status
systemctl status yabs-monitor.timer
systemctl status yabs-healthcheck.timer
```

### SSH to Remote Server

If testing from Mac to Zorin VM:

```bash
# Run on remote server
ssh zorin0 "/opt/yabs/yabs_extended.sh -p test"

# Copy results back
scp -r zorin0:/opt/yabs/results/* ./results/
```

## Configuration

Edit `/opt/yabs/yabs.conf` to customize:
- Test targets
- Ping count
- DNS servers
- Log retention
- Notification settings

## Troubleshooting

### Check Dependencies
```bash
/opt/yabs/scripts/healthcheck.sh
```

### Verify Network Connectivity
```bash
ping -c 4 8.8.8.8
dig @8.8.8.8 google.com
```

### Check Disk Space
```bash
df -h /opt/yabs
```

### View Service Logs
```bash
journalctl -u yabs-monitor --since "1 hour ago"
journalctl -u yabs-healthcheck --since "1 hour ago"
```

## Uninstall

```bash
# Stop services
sudo systemctl disable --now yabs-monitor.timer yabs-healthcheck.timer

# Remove files
sudo rm -rf /opt/yabs
sudo rm -rf /var/log/yabs
sudo rm /etc/systemd/system/yabs-*

# Reload systemd
sudo systemctl daemon-reload
```