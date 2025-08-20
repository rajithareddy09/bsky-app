#!/bin/bash

# =============================================================================
# Bluesky Health Check Script
# =============================================================================
# This script checks the health of all Bluesky services

set -e

echo "🏥 Bluesky Health Check"
echo "======================"
echo ""

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "❌ .env file not found. Please run the key generation script first."
    exit 1
fi

# Get domain from environment or prompt user
DOMAIN="${PDS_HOSTNAME:-}"
if [ -z "$DOMAIN" ]; then
    read -p "Enter your domain (e.g., yourdomain.com): " DOMAIN
fi

# Remove any protocol prefixes
DOMAIN=$(echo "$DOMAIN" | sed 's|^https?://||' | sed 's|^pdsapi\.||')

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Function to check if a service is running
check_service() {
    local service_name=$1
    local display_name=$2
    
    if systemctl is-active --quiet "$service_name"; then
        print_status "OK" "$display_name is running"
        return 0
    else
        print_status "ERROR" "$display_name is not running"
        return 1
    fi
}

# Function to check if a port is listening
check_port() {
    local port=$1
    local service_name=$2
    
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        print_status "OK" "$service_name is listening on port $port"
        return 0
    else
        print_status "ERROR" "$service_name is not listening on port $port"
        return 1
    fi
}

# Function to check HTTP endpoint
check_http_endpoint() {
    local url=$1
    local service_name=$2
    local timeout=${3:-5}
    
    if curl -s --max-time "$timeout" "$url" > /dev/null 2>&1; then
        print_status "OK" "$service_name is responding at $url"
        return 0
    else
        print_status "ERROR" "$service_name is not responding at $url"
        return 1
    fi
}

# Function to check database connection
check_database() {
    local db_host="localhost"
    local db_port="5432"
    local db_name="bluesky"
    local db_user="bluesky"
    local db_password="${POSTGRES_PASSWORD:-bluesky_password}"
    
    if PGPASSWORD="$db_password" psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -c "SELECT 1;" > /dev/null 2>&1; then
        print_status "OK" "Database connection is working"
        return 0
    else
        print_status "ERROR" "Database connection failed"
        return 1
    fi
}

# Function to check Redis connection
check_redis() {
    if redis-cli ping | grep -q "PONG"; then
        print_status "OK" "Redis connection is working"
        return 0
    else
        print_status "ERROR" "Redis connection failed"
        return 1
    fi
}

# Function to get service status details
get_service_details() {
    local service_name=$1
    local display_name=$2
    
    echo ""
    print_status "INFO" "$display_name Details:"
    
    # Check if service exists
    if systemctl list-unit-files | grep -q "$service_name"; then
        # Get service status
        local status=$(systemctl is-active "$service_name")
        local enabled=$(systemctl is-enabled "$service_name")
        
        echo "  Status: $status"
        echo "  Enabled: $enabled"
        
        # Get recent logs
        echo "  Recent logs:"
        journalctl -u "$service_name" --no-pager -n 3 --no-hostname | sed 's/^/    /'
    else
        echo "  Service not found"
    fi
}

# Function to check disk space
check_disk_space() {
    local usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$usage" -lt 80 ]; then
        print_status "OK" "Disk space usage: ${usage}%"
    elif [ "$usage" -lt 90 ]; then
        print_status "WARNING" "Disk space usage: ${usage}%"
    else
        print_status "ERROR" "Disk space usage: ${usage}% (critical)"
    fi
}

# Function to check memory usage
check_memory() {
    local total=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local used=$(free -m | awk 'NR==2{printf "%.0f", $3}')
    local usage=$((used * 100 / total))
    
    if [ "$usage" -lt 80 ]; then
        print_status "OK" "Memory usage: ${usage}% (${used}MB/${total}MB)"
    elif [ "$usage" -lt 90 ]; then
        print_status "WARNING" "Memory usage: ${usage}% (${used}MB/${total}MB)"
    else
        print_status "ERROR" "Memory usage: ${usage}% (${used}MB/${total}MB) (critical)"
    fi
}

# Function to check SSL certificates
check_ssl_certificates() {
    local domains=(
        "app.$DOMAIN"
        "bsky.$DOMAIN"
        "pdsapi.$DOMAIN"
        "ozone.$DOMAIN"
        "bsync.$DOMAIN"
    )
    
    echo ""
    print_status "INFO" "SSL Certificate Status:"
    
    for domain in "${domains[@]}"; do
        if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
            local expiry=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$domain/fullchain.pem" | cut -d= -f2)
            local expiry_date=$(date -d "$expiry" +%s)
            local current_date=$(date +%s)
            local days_left=$(( (expiry_date - current_date) / 86400 ))
            
            if [ "$days_left" -gt 30 ]; then
                print_status "OK" "$domain: expires in $days_left days"
            elif [ "$days_left" -gt 7 ]; then
                print_status "WARNING" "$domain: expires in $days_left days"
            else
                print_status "ERROR" "$domain: expires in $days_left days (renewal needed)"
            fi
        else
            print_status "ERROR" "$domain: certificate not found"
        fi
    done
}

# Initialize counters
total_checks=0
passed_checks=0

# System checks
echo "🔧 System Health:"
echo "================="
((total_checks++))
if check_disk_space; then ((passed_checks++)); fi

((total_checks++))
if check_memory; then ((passed_checks++)); fi

# Service checks
echo ""
echo "🚀 Service Health:"
echo "=================="

((total_checks++))
if check_service "postgresql" "PostgreSQL"; then ((passed_checks++)); fi

((total_checks++))
if check_service "redis-server" "Redis"; then ((passed_checks++)); fi

((total_checks++))
if check_service "nginx" "Nginx"; then ((passed_checks++)); fi

((total_checks++))
if check_service "bluesky-pds" "PDS Service"; then ((passed_checks++)); fi

((total_checks++))
if check_service "bluesky-appview" "AppView Service"; then ((passed_checks++)); fi

((total_checks++))
if check_service "bluesky-ozone" "Ozone Service"; then ((passed_checks++)); fi

((total_checks++))
if check_service "bluesky-bsync" "Bsync Service"; then ((passed_checks++)); fi

((total_checks++))
if check_service "bluesky-web" "Web Frontend"; then ((passed_checks++)); fi

# Port checks
echo ""
echo "🔌 Port Health:"
echo "==============="

((total_checks++))
if check_port "5432" "PostgreSQL"; then ((passed_checks++)); fi

((total_checks++))
if check_port "6379" "Redis"; then ((passed_checks++)); fi

((total_checks++))
if check_port "80" "Nginx HTTP"; then ((passed_checks++)); fi

((total_checks++))
if check_port "443" "Nginx HTTPS"; then ((passed_checks++)); fi

((total_checks++))
if check_port "2583" "PDS API"; then ((passed_checks++)); fi

((total_checks++))
if check_port "3000" "AppView API"; then ((passed_checks++)); fi

((total_checks++))
if check_port "3001" "Ozone API"; then ((passed_checks++)); fi

((total_checks++))
if check_port "3002" "Bsync API"; then ((passed_checks++)); fi

((total_checks++))
if check_port "8100" "Web Frontend"; then ((passed_checks++)); fi

# Database and Redis checks
echo ""
echo "🗄️ Database Health:"
echo "==================="

((total_checks++))
if check_database; then ((passed_checks++)); fi

((total_checks++))
if check_redis; then ((passed_checks++)); fi

# HTTP endpoint checks
echo ""
echo "🌐 HTTP Endpoint Health:"
echo "========================"

((total_checks++))
if check_http_endpoint "https://app.$DOMAIN" "Web App"; then ((passed_checks++)); fi

((total_checks++))
if check_http_endpoint "https://bsky.$DOMAIN/xrpc/com.atproto.server.describeServer" "AppView API"; then ((passed_checks++)); fi

((total_checks++))
if check_http_endpoint "https://pdsapi.$DOMAIN/xrpc/com.atproto.server.describeServer" "PDS API"; then ((passed_checks++)); fi

((total_checks++))
if check_http_endpoint "https://ozone.$DOMAIN/health" "Ozone API"; then ((passed_checks++)); fi

# SSL certificate checks
check_ssl_certificates

# Summary
echo ""
echo "📊 Health Check Summary:"
echo "========================"
echo "Total checks: $total_checks"
echo "Passed: $passed_checks"
echo "Failed: $((total_checks - passed_checks))"
echo "Success rate: $((passed_checks * 100 / total_checks))%"

if [ "$passed_checks" -eq "$total_checks" ]; then
    print_status "OK" "All health checks passed! Your Bluesky instance is healthy."
    exit 0
elif [ "$passed_checks" -gt $((total_checks * 8 / 10)) ]; then
    print_status "WARNING" "Most health checks passed, but some issues were found."
    exit 1
else
    print_status "ERROR" "Multiple health checks failed. Please review the issues above."
    exit 1
fi
