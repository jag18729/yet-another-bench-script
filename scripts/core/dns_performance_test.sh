#!/bin/bash

# DNS Performance Test Script
# Tests DNS query response times using dig and optionally dnsperf
# Part of the comprehensive performance testing suite

SCRIPT_VERSION="v1.0.0"
TIMESTAMP=$(date '+%b-%d-%Y_%H-%M-%S')
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
source "$PROJECT_ROOT/lib/common_functions.sh"

echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e '#            DNS Performance Test Script             #'
echo -e '#                   '$SCRIPT_VERSION'                  #'
echo -e '# ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## #'
echo -e

# Default values
DEFAULT_QUERY_COUNT=100
DEFAULT_TIMEOUT=5
OUTPUT_DIR="${RESULTS_DIR:-$PROJECT_ROOT/results/${PRE_POST}_${TIMESTAMP}-Extended-Test-Suite-Results}"
DNS_SERVER=""
DOMAIN_LIST=""
QUERY_COUNT=$DEFAULT_QUERY_COUNT
TIMEOUT=$DEFAULT_TIMEOUT
PRE_POST=""
USE_DNSPERF=false
QUERY_TYPE="A"

# Default domains to test if no list provided
DEFAULT_DOMAINS=(
    "google.com"
    "cloudflare.com"
    "amazon.com"
    "facebook.com"
    "youtube.com"
    "twitter.com"
    "linkedin.com"
    "github.com"
    "wikipedia.org"
    "netflix.com"
)

# Function to display usage
usage() {
    echo "Usage: $0 -s <dns_server> [-d <domain_list>] [-c <query_count>] [-t <timeout>] [-q <query_type>] [-p <pre|post>] [-f]"
    echo ""
    echo "Options:"
    echo "  -s <dns_server>      DNS server IP to test"
    echo "  -d <domain_list>     File containing list of domains (one per line)"
    echo "  -c <query_count>     Number of queries per domain (default: 100)"
    echo "  -t <timeout>         Query timeout in seconds (default: 5)"
    echo "  -q <query_type>      DNS query type: A, AAAA, MX, TXT, etc. (default: A)"
    echo "  -p <pre|post>        Test phase: pre or post (for result naming)"
    echo "  -f                   Use dnsperf if available (requires domain list file)"
    echo "  -h                   Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s 8.8.8.8 -p pre"
    echo "  $0 -s 1.1.1.1 -d domains.txt -c 50 -p post"
    echo "  $0 -s 192.168.1.1 -f -d domains.txt"
    exit 1
}

# Parse command line arguments
while getopts "s:d:c:t:q:p:fh" opt; do
    case ${opt} in
        s )
            DNS_SERVER=$OPTARG
            ;;
        d )
            DOMAIN_LIST=$OPTARG
            ;;
        c )
            QUERY_COUNT=$OPTARG
            ;;
        t )
            TIMEOUT=$OPTARG
            ;;
        q )
            QUERY_TYPE=$OPTARG
            ;;
        p )
            PRE_POST=$OPTARG
            ;;
        f )
            USE_DNSPERF=true
            ;;
        h )
            usage
            ;;
        \? )
            echo "Invalid option: -$OPTARG" 1>&2
            usage
            ;;
        : )
            echo "Option -$OPTARG requires an argument." 1>&2
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$DNS_SERVER" ]; then
    echo "Error: DNS server is required (-s)"
    usage
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Set file prefix based on pre/post
FILE_PREFIX=""
if [ ! -z "$PRE_POST" ]; then
    FILE_PREFIX="${PRE_POST}_"
fi

# Function to test DNS with dig
test_dns_with_dig() {
    local server=$1
    local output_file="${OUTPUT_DIR}/${FILE_PREFIX}dns_dig_${server}_${TIMESTAMP}.txt"
    local json_file="${OUTPUT_DIR}/${FILE_PREFIX}dns_dig_${server}_${TIMESTAMP}.json"
    local stats_file="${OUTPUT_DIR}/${FILE_PREFIX}dns_dig_${server}_${TIMESTAMP}_stats.txt"
    
    echo "Running DNS performance test using dig..."
    echo "DNS Server: $server"
    echo "Query Type: $QUERY_TYPE"
    echo ""
    
    # Check if dig is available
    if ! command -v dig >/dev/null 2>&1; then
        echo "Error: dig not found. Please install dnsutils/bind-utils."
        return 1
    fi
    
    # Prepare domains to test
    local domains=()
    if [ ! -z "$DOMAIN_LIST" ] && [ -f "$DOMAIN_LIST" ]; then
        mapfile -t domains < "$DOMAIN_LIST"
    else
        domains=("${DEFAULT_DOMAINS[@]}")
    fi
    
    # Initialize statistics
    local total_queries=0
    local successful_queries=0
    local failed_queries=0
    local total_time=0
    local min_time=999999
    local max_time=0
    
    # JSON array start
    echo "{" > "$json_file"
    echo "  \"test_type\": \"dns_dig\"," >> "$json_file"
    echo "  \"timestamp\": \"$TIMESTAMP\"," >> "$json_file"
    echo "  \"dns_server\": \"$server\"," >> "$json_file"
    echo "  \"query_type\": \"$QUERY_TYPE\"," >> "$json_file"
    echo "  \"queries\": [" >> "$json_file"
    
    # Test each domain
    for domain in "${domains[@]}"; do
        echo "Testing $domain..."
        
        local domain_total_time=0
        local domain_min_time=999999
        local domain_max_time=0
        local domain_successful=0
        
        for i in $(seq 1 $QUERY_COUNT); do
            # Run dig and capture output
            local dig_output=$(dig +time=$TIMEOUT +tries=1 +stats @"$server" "$domain" "$QUERY_TYPE" 2>&1)
            local query_time=$(echo "$dig_output" | grep "Query time:" | awk '{print $4}')
            
            if [ ! -z "$query_time" ] && [ "$query_time" -ne 0 ]; then
                # Successful query
                ((successful_queries++))
                ((domain_successful++))
                total_time=$((total_time + query_time))
                domain_total_time=$((domain_total_time + query_time))
                
                # Update min/max
                if [ "$query_time" -lt "$min_time" ]; then
                    min_time=$query_time
                fi
                if [ "$query_time" -gt "$max_time" ]; then
                    max_time=$query_time
                fi
                if [ "$query_time" -lt "$domain_min_time" ]; then
                    domain_min_time=$query_time
                fi
                if [ "$query_time" -gt "$domain_max_time" ]; then
                    domain_max_time=$query_time
                fi
            else
                # Failed query
                ((failed_queries++))
            fi
            
            ((total_queries++))
            
            # Progress indicator
            if [ $((i % 10)) -eq 0 ]; then
                echo -n "."
            fi
        done
        
        echo "" # New line after progress dots
        
        # Calculate domain statistics
        if [ "$domain_successful" -gt 0 ]; then
            local domain_avg_time=$((domain_total_time / domain_successful))
            echo "" # Space before domain result
            local success_rate=$(echo "scale=1; $domain_successful * 100 / $QUERY_COUNT" | bc)
            local avg_color="${GREEN}"
            [ $domain_avg_time -gt 100 ] && avg_color="${YELLOW}"
            [ $domain_avg_time -gt 200 ] && avg_color="${RED}"
            
            echo -e "  ${BOLD}$domain${NC}" | tee -a "$stats_file"
            echo -e "    ${BOLD}Average:${NC} ${avg_color}${domain_avg_time}ms${NC}  ${BOLD}Min:${NC} ${domain_min_time}ms  ${BOLD}Max:${NC} ${domain_max_time}ms" | tee -a "$stats_file"
            echo -e "    ${BOLD}Success:${NC} $domain_successful/$QUERY_COUNT (${GREEN}${success_rate}%${NC})" | tee -a "$stats_file"
            
            # Add to JSON
            if [ "$total_queries" -gt "$QUERY_COUNT" ]; then
                echo "," >> "$json_file"
            fi
            echo -n "    {\"domain\": \"$domain\", \"avg_ms\": $domain_avg_time, \"min_ms\": $domain_min_time, \"max_ms\": $domain_max_time, \"successful\": $domain_successful, \"total\": $QUERY_COUNT}" >> "$json_file"
        fi
    done
    
    # Close JSON arrays
    echo "" >> "$json_file"
    echo "  ]," >> "$json_file"
    
    # Calculate overall statistics
    if [ "$successful_queries" -gt 0 ]; then
        local avg_time=$((total_time / successful_queries))
        
        # Add summary to JSON
        echo "  \"summary\": {" >> "$json_file"
        echo "    \"total_queries\": $total_queries," >> "$json_file"
        echo "    \"successful_queries\": $successful_queries," >> "$json_file"
        echo "    \"failed_queries\": $failed_queries," >> "$json_file"
        echo "    \"success_rate\": $(echo "scale=2; $successful_queries * 100 / $total_queries" | bc)," >> "$json_file"
        echo "    \"avg_response_time_ms\": $avg_time," >> "$json_file"
        echo "    \"min_response_time_ms\": $min_time," >> "$json_file"
        echo "    \"max_response_time_ms\": $max_time" >> "$json_file"
        echo "  }" >> "$json_file"
        echo "}" >> "$json_file"
        
        # Calculate success rate
        local success_rate=$(echo "scale=2; $successful_queries * 100 / $total_queries" | bc)
        
        # Save summary to stats file
        {
            echo ""
            echo "DNS Performance Test Summary:"
            echo "=============================="
            echo "Total queries: $total_queries"
            echo "Successful: $successful_queries"
            echo "Failed: $failed_queries"
            echo "Success rate: ${success_rate}%"
            echo "Average response time: ${avg_time}ms"
            echo "Min response time: ${min_time}ms"
            echo "Max response time: ${max_time}ms"
        } >> "$stats_file"
        
        # Also print to console with formatting
        echo ""
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}  DNS PERFORMANCE SUMMARY - $DNS_SERVER${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}Total Queries:${NC}   $total_queries"
        echo -e "  ${BOLD}Successful:${NC}      ${GREEN}$successful_queries${NC} (${GREEN}${success_rate}%${NC})"
        echo -e "  ${BOLD}Failed:${NC}          ${RED}$failed_queries${NC}"
        echo ""
        local avg_color="${GREEN}"
        [ $avg_time -gt 100 ] && avg_color="${YELLOW}"
        [ $avg_time -gt 200 ] && avg_color="${RED}"
        echo -e "  ${BOLD}Response Times:${NC}"
        echo -e "    ${BOLD}Average:${NC}     ${avg_color}${avg_time}ms${NC}"
        echo -e "    ${BOLD}Minimum:${NC}     ${GREEN}${min_time}ms${NC}"
        echo -e "    ${BOLD}Maximum:${NC}     ${RED}${max_time}ms${NC}"
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Results saved to:"
        echo "  - Statistics: $stats_file"
        echo "  - JSON: $json_file"
    else
        echo "Error: All queries failed"
        echo "}" >> "$json_file"
    fi
}

# Function to test DNS with dnsperf
test_dns_with_dnsperf() {
    local server=$1
    local output_file="${OUTPUT_DIR}/${FILE_PREFIX}dnsperf_${server}_${TIMESTAMP}.txt"
    local json_file="${OUTPUT_DIR}/${FILE_PREFIX}dnsperf_${server}_${TIMESTAMP}.json"
    
    echo "Running DNS performance test using dnsperf..."
    echo "DNS Server: $server"
    echo ""
    
    # Check if dnsperf is available
    if ! command -v dnsperf >/dev/null 2>&1; then
        echo "Warning: dnsperf not found. Falling back to dig method."
        return 1
    fi
    
    # Check if domain list file exists
    if [ -z "$DOMAIN_LIST" ] || [ ! -f "$DOMAIN_LIST" ]; then
        echo "Error: Domain list file required for dnsperf (-d option)"
        return 1
    fi
    
    # Prepare dnsperf input file
    local dnsperf_input="${OUTPUT_DIR}/dnsperf_input_${TIMESTAMP}.txt"
    while IFS= read -r domain; do
        echo "$domain $QUERY_TYPE" >> "$dnsperf_input"
    done < "$DOMAIN_LIST"
    
    # Run dnsperf
    echo "Running dnsperf (this may take a while)..."
    dnsperf -s "$server" -d "$dnsperf_input" -c 1 -t $TIMEOUT -Q $QUERY_COUNT > "$output_file" 2>&1
    
    # Parse dnsperf output and create JSON
    if grep -q "Queries sent:" "$output_file"; then
        local queries_sent=$(grep "Queries sent:" "$output_file" | awk '{print $3}')
        local queries_completed=$(grep "Queries completed:" "$output_file" | awk '{print $3}')
        local queries_lost=$(grep "Queries lost:" "$output_file" | awk '{print $3}')
        local avg_latency=$(grep "Average latency:" "$output_file" | awk '{print $3}')
        local min_latency=$(grep "Latency:" "$output_file" | grep "min" | awk '{print $3}')
        local max_latency=$(grep "Latency:" "$output_file" | grep "max" | awk '{print $7}')
        
        # Create JSON output
        cat > "$json_file" <<EOF
{
    "test_type": "dnsperf",
    "timestamp": "$TIMESTAMP",
    "dns_server": "$server",
    "query_type": "$QUERY_TYPE",
    "queries_sent": $queries_sent,
    "queries_completed": $queries_completed,
    "queries_lost": $queries_lost,
    "avg_latency_ms": $avg_latency,
    "min_latency_ms": $min_latency,
    "max_latency_ms": $max_latency
}
EOF
        
        echo ""
        echo "DNSPerf Test Summary:"
        echo "===================="
        cat "$output_file" | grep -E "(Queries sent:|Queries completed:|Queries lost:|Average latency:|Latency:)"
        echo ""
        echo "Results saved to:"
        echo "  - Raw output: $output_file"
        echo "  - JSON: $json_file"
    else
        echo "Error: Failed to parse dnsperf output"
    fi
    
    # Cleanup
    rm -f "$dnsperf_input"
}

# Main execution
echo "Starting DNS performance test..."
echo ""

if [ "$USE_DNSPERF" = true ] && command -v dnsperf >/dev/null 2>&1; then
    test_dns_with_dnsperf "$DNS_SERVER"
    if [ $? -ne 0 ]; then
        # Fallback to dig if dnsperf fails
        test_dns_with_dig "$DNS_SERVER"
    fi
else
    test_dns_with_dig "$DNS_SERVER"
fi

echo ""
echo "DNS performance test completed."