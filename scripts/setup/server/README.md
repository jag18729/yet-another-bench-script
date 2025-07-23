# 🖧 Server Setup Scripts

Scripts for setting up dedicated test servers that clients connect to.

## 📋 Available Scripts

### `setup_server.sh`
Comprehensive server setup script for creating a test endpoint.

**What it installs:**
- **iperf3 server**: For bandwidth testing
- **nginx**: For HTTP transfer tests
- **DNS servers**: bind9/dnsmasq for DNS testing
- **SSH server**: Configured for secure transfers
- **Monitoring tools**: For server-side metrics

**Features:**
- Configures systemd services
- Sets up auto-start on boot
- Configures firewall rules
- Creates test files for transfers

**Usage:**
```bash
sudo ./setup_server.sh
```

### `setup_ssh_zorin.sh`
Specialized setup for Zorin OS (or Ubuntu-based) VMs.

**What it does:**
- Configures SSH for key-based authentication
- Sets up Zorin-specific optimizations
- Configures VM network settings
- Enables performance monitoring
- Sets up shared folders (if in VM)

**Usage:**
```bash
./setup_ssh_zorin.sh
```

## 🚀 Quick Server Setup

```bash
# 1. Basic server setup
sudo ./setup_server.sh

# 2. Verify services are running
systemctl status iperf3
systemctl status nginx

# 3. Test connectivity
iperf3 -s  # Starts iperf3 server
```

## 🔐 Security Considerations

- Scripts configure basic firewall rules
- SSH is set to key-only authentication
- Services bind to all interfaces by default
- Consider restricting to specific IPs in production

## 📡 Default Ports

- **iperf3**: 5201
- **HTTP/nginx**: 80
- **HTTPS/nginx**: 443
- **SSH**: 22
- **DNS**: 53

## 🛠️ Post-Setup Configuration

### iperf3 Service
```bash
# Start/stop/restart
sudo systemctl start iperf3
sudo systemctl stop iperf3
sudo systemctl restart iperf3

# Enable auto-start
sudo systemctl enable iperf3
```

### Test Files for Transfer Tests
```bash
# Create test files of various sizes
sudo mkdir -p /var/www/html/test
sudo dd if=/dev/zero of=/var/www/html/test/10MB.bin bs=1M count=10
sudo dd if=/dev/zero of=/var/www/html/test/100MB.bin bs=1M count=100
sudo dd if=/dev/zero of=/var/www/html/test/1GB.bin bs=1M count=1024
```

### Firewall Rules
```bash
# Allow iperf3
sudo ufw allow 5201/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow DNS
sudo ufw allow 53/udp
```

## 📊 Monitoring

After setup, monitor server performance:
```bash
# Check service status
systemctl status iperf3 nginx

# Monitor connections
ss -tunap | grep -E '(5201|80|443)'

# View logs
journalctl -u iperf3 -f
tail -f /var/log/nginx/access.log
```

## 🔧 Troubleshooting

**iperf3 won't start:**
- Check if port 5201 is already in use
- Verify systemd service file exists
- Check logs: `journalctl -u iperf3`

**Can't connect from client:**
- Verify firewall rules
- Check server is listening: `ss -tlnp | grep 5201`
- Test locally first: `iperf3 -c localhost`