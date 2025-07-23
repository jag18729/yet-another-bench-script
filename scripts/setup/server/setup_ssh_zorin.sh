#!/bin/bash

# Setup SSH key authentication for Zorin VM

REMOTE_HOST="zorin0"
REMOTE_IP="10.211.55.4"
REMOTE_USER="rjgarcia"

echo "Setting up SSH key authentication for Zorin VM"
echo "============================================="
echo "Host: $REMOTE_HOST ($REMOTE_IP)"
echo "User: $REMOTE_USER"
echo

# Check if SSH key exists
if [ ! -f ~/.ssh/id_ed25519.pub ]; then
    echo "No SSH key found. Generating one..."
    ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)"
fi

echo "Your public key is:"
cat ~/.ssh/id_ed25519.pub
echo

echo "Attempting to copy SSH key to Zorin VM..."
echo "You will be prompted for the password."
ssh-copy-id -i ~/.ssh/id_ed25519.pub $REMOTE_HOST

# Test connection
echo
echo "Testing SSH connection..."
if ssh -o BatchMode=yes -o ConnectTimeout=5 $REMOTE_HOST "echo 'SSH key authentication successful!'" 2>/dev/null; then
    echo "✅ SSH key authentication is working!"
    echo
    echo "You can now run ./sync_to_zorin.sh to sync files"
    echo "Or run ./sync_to_zorin.sh --watch for automatic sync"
else
    echo "❌ SSH key authentication failed. Please check:"
    echo "  1. The password you entered was correct"
    echo "  2. SSH service is running on Zorin VM"
    echo "  3. Port 22 is accessible"
fi