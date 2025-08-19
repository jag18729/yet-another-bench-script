#!/bin/bash

# Color functions for performance test suite

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Performance thresholds
PING_EXCELLENT=10    # ms
PING_GOOD=25        # ms
PING_FAIR=50        # ms

PACKET_LOSS_EXCELLENT=0
PACKET_LOSS_GOOD=0.5
PACKET_LOSS_FAIR=2

IPERF_EXCELLENT=900  # Mbps
IPERF_GOOD=500      # Mbps
IPERF_FAIR=100      # Mbps

DNS_RESPONSE_EXCELLENT=20  # ms
DNS_RESPONSE_GOOD=50      # ms
DNS_RESPONSE_FAIR=100     # ms

DNS_SUCCESS_EXCELLENT=99.5  # %
DNS_SUCCESS_GOOD=98        # %
DNS_SUCCESS_FAIR=95        # %

DOWNLOAD_EXCELLENT=50   # MB/s
DOWNLOAD_GOOD=20       # MB/s
DOWNLOAD_FAIR=5        # MB/s

# Color functions
color_ping_rtt() {
    local rtt=$1
    if (( $(echo "$rtt < $PING_EXCELLENT" | bc -l) )); then
        echo -e "${GREEN}${rtt}ms${NC}"
    elif (( $(echo "$rtt < $PING_GOOD" | bc -l) )); then
        echo -e "${BLUE}${rtt}ms${NC}"
    elif (( $(echo "$rtt < $PING_FAIR" | bc -l) )); then
        echo -e "${YELLOW}${rtt}ms${NC}"
    else
        echo -e "${RED}${rtt}ms${NC}"
    fi
}

color_packet_loss() {
    local loss=$1
    if (( $(echo "$loss <= $PACKET_LOSS_EXCELLENT" | bc -l) )); then
        echo -e "${GREEN}${loss}%${NC}"
    elif (( $(echo "$loss <= $PACKET_LOSS_GOOD" | bc -l) )); then
        echo -e "${BLUE}${loss}%${NC}"
    elif (( $(echo "$loss <= $PACKET_LOSS_FAIR" | bc -l) )); then
        echo -e "${YELLOW}${loss}%${NC}"
    else
        echo -e "${RED}${loss}%${NC}"
    fi
}

color_throughput() {
    local mbps=$1
    if (( $(echo "$mbps >= $IPERF_EXCELLENT" | bc -l) )); then
        echo -e "${GREEN}${mbps} Mbps${NC}"
    elif (( $(echo "$mbps >= $IPERF_GOOD" | bc -l) )); then
        echo -e "${BLUE}${mbps} Mbps${NC}"
    elif (( $(echo "$mbps >= $IPERF_FAIR" | bc -l) )); then
        echo -e "${YELLOW}${mbps} Mbps${NC}"
    else
        echo -e "${RED}${mbps} Mbps${NC}"
    fi
}

color_dns_response() {
    local ms=$1
    if (( $(echo "$ms <= $DNS_RESPONSE_EXCELLENT" | bc -l) )); then
        echo -e "${GREEN}${ms}ms${NC}"
    elif (( $(echo "$ms <= $DNS_RESPONSE_GOOD" | bc -l) )); then
        echo -e "${BLUE}${ms}ms${NC}"
    elif (( $(echo "$ms <= $DNS_RESPONSE_FAIR" | bc -l) )); then
        echo -e "${YELLOW}${ms}ms${NC}"
    else
        echo -e "${RED}${ms}ms${NC}"
    fi
}

color_dns_success() {
    local rate=$1
    if (( $(echo "$rate >= $DNS_SUCCESS_EXCELLENT" | bc -l) )); then
        echo -e "${GREEN}${rate}%${NC}"
    elif (( $(echo "$rate >= $DNS_SUCCESS_GOOD" | bc -l) )); then
        echo -e "${BLUE}${rate}%${NC}"
    elif (( $(echo "$rate >= $DNS_SUCCESS_FAIR" | bc -l) )); then
        echo -e "${YELLOW}${rate}%${NC}"
    else
        echo -e "${RED}${rate}%${NC}"
    fi
}

color_download_speed() {
    local mbps=$1
    if (( $(echo "$mbps >= $DOWNLOAD_EXCELLENT" | bc -l) )); then
        echo -e "${GREEN}${mbps} MB/s${NC}"
    elif (( $(echo "$mbps >= $DOWNLOAD_GOOD" | bc -l) )); then
        echo -e "${BLUE}${mbps} MB/s${NC}"
    elif (( $(echo "$mbps >= $DOWNLOAD_FAIR" | bc -l) )); then
        echo -e "${YELLOW}${mbps} MB/s${NC}"
    else
        echo -e "${RED}${mbps} MB/s${NC}"
    fi
}

# Status indicators
print_status() {
    local status=$1
    case $status in
        "excellent")
            echo -e "${GREEN}●${NC} Excellent"
            ;;
        "good")
            echo -e "${BLUE}●${NC} Good"
            ;;
        "fair")
            echo -e "${YELLOW}●${NC} Fair"
            ;;
        "poor")
            echo -e "${RED}●${NC} Poor"
            ;;
    esac
}