#!/bin/bash

# Sync script to copy performance test files to Zorin VM
# This script can be run manually or via fswatch for automatic sync

# Configuration
REMOTE_HOST="zorin0"
REMOTE_USER="rjgarcia"
REMOTE_DIR="/home/rjgarcia/performance-tests"
LOCAL_DIR="$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Starting sync to Zorin VM...${NC}"

# First, try to set up SSH key if not already done
echo -e "${YELLOW}Checking SSH key setup...${NC}"
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 $REMOTE_HOST exit 2>/dev/null; then
    echo -e "${RED}SSH key authentication not set up. Please run:${NC}"
    echo "ssh-copy-id $REMOTE_HOST"
    echo "Or enter password when prompted for sync."
fi

# Create remote directory if it doesn't exist
ssh $REMOTE_HOST "mkdir -p $REMOTE_DIR" 2>/dev/null || {
    echo -e "${RED}Failed to create remote directory. Please check SSH access.${NC}"
    exit 1
}

# Files to sync
FILES_TO_SYNC=(
    "*.sh"
    "*.py"
    "*.conf"
    "CLAUDE.md"
    "README.md"
)

# Sync files using rsync
echo -e "${GREEN}Syncing files...${NC}"
for pattern in "${FILES_TO_SYNC[@]}"; do
    files=$(find "$LOCAL_DIR" -maxdepth 1 -name "$pattern" -type f 2>/dev/null)
    if [ -n "$files" ]; then
        for file in $files; do
            filename=$(basename "$file")
            echo "  - Syncing $filename"
            rsync -av "$file" "$REMOTE_HOST:$REMOTE_DIR/" || {
                echo -e "${RED}Failed to sync $filename${NC}"
            }
        done
    fi
done

# Make all scripts executable on remote
echo -e "${GREEN}Setting permissions on remote...${NC}"
ssh $REMOTE_HOST "cd $REMOTE_DIR && chmod +x *.sh 2>/dev/null"

echo -e "${GREEN}Sync completed!${NC}"
echo -e "Remote files are in: $REMOTE_HOST:$REMOTE_DIR"

# Optional: Set up automatic sync with fswatch
if [ "$1" == "--watch" ]; then
    if command -v fswatch >/dev/null 2>&1; then
        echo -e "${YELLOW}Starting file watch mode...${NC}"
        echo "Watching for changes in $LOCAL_DIR"
        echo "Press Ctrl+C to stop"
        
        fswatch -o "$LOCAL_DIR"/*.sh "$LOCAL_DIR"/*.py "$LOCAL_DIR"/*.conf | while read f; do
            echo -e "${YELLOW}Change detected, syncing...${NC}"
            "$0"  # Run this script again
        done
    else
        echo -e "${RED}fswatch not installed. Install with: brew install fswatch${NC}"
        echo "For automatic sync, run: brew install fswatch"
        echo "Then run: $0 --watch"
    fi
fi