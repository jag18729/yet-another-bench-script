# 🛠️ Setup Scripts

This directory contains all installation and setup scripts organized by purpose.

## 📁 Directory Structure

```
setup/
├── client/          # Scripts for setting up test clients
│   ├── README.md
│   ├── setup_client.sh       # Cross-platform client setup
│   └── setup_macos_local.sh  # macOS-specific optimizations
├── server/          # Scripts for setting up test servers
│   ├── README.md
│   ├── setup_server.sh       # General server setup
│   └── setup_ssh_zorin.sh    # Zorin/Ubuntu VM setup
└── environment/     # Complete environment setup
    ├── README.md
    └── setup_environment.sh  # All-in-one setup
```

## 🎯 Which Setup Do I Need?

### I want to run performance tests
→ Use **client** setup scripts

### I need a test target/endpoint
→ Use **server** setup scripts

### I want everything configured
→ Use **environment** setup script

## 🚀 Quick Start Guide

### 1️⃣ Test Client Setup (Most Common)

For machines that will **run** the performance tests:

```bash
# Linux users
cd client/
./setup_client.sh

# macOS users (recommended)
cd client/
./setup_macos_local.sh
```

### 2️⃣ Test Server Setup (Optional)

Only needed if setting up a dedicated test server:

```bash
# General server setup
cd server/
sudo ./setup_server.sh

# For Zorin/Ubuntu VMs
cd server/
./setup_ssh_zorin.sh
```

### 3️⃣ Complete Environment (All-in-One)

Installs everything - both client and server components:

```bash
cd environment/
./setup_environment.sh --full
```

## 📋 What Gets Installed

- **Client Setup**: Testing tools (iperf3, dig, curl, wget), Python dependencies
- **Server Setup**: Server components (iperf3 server, nginx, DNS servers)
- **Environment Setup**: All dependencies for both client and server roles

## 💡 Tips

1. Always run the dependency checker first:
   ```bash
   ../../utils/check_dependencies.sh
   ```

2. Client setup is usually sufficient for most testing scenarios

3. Server setup is only needed if you're setting up a dedicated test server

4. Environment setup is comprehensive and includes everything