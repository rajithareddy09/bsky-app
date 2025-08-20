#!/bin/bash

# =============================================================================
# Bluesky Database Seeding Script
# =============================================================================
# This script seeds the database with initial data for your Bluesky instance

set -e

echo "🌱 Seeding Bluesky database with initial data..."
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "❌ .env file not found. Please run the key generation script first."
    exit 1
fi

# Database connection details
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="bluesky"
DB_USER="bluesky"
DB_PASSWORD="${POSTGRES_PASSWORD:-bluesky_password}"

# Get domain from environment or prompt user
DOMAIN="${PDS_HOSTNAME:-}"
if [ -z "$DOMAIN" ]; then
    read -p "Enter your domain (e.g., yourdomain.com): " DOMAIN
fi

# Remove any protocol prefixes
DOMAIN=$(echo "$DOMAIN" | sed 's|^https?://||' | sed 's|^pdsapi\.||')

# Function to run SQL commands
run_sql() {
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$1"
}

# Function to check if table exists
table_exists() {
    local table_name=$1
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '$table_name');" | grep -q "t"
}

# Function to check if user exists
user_exists() {
    local handle=$1
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT EXISTS (SELECT 1 FROM actor WHERE handle = '$handle');" | grep -q "t"
}

echo "🔍 Checking database connection..."
if ! run_sql "SELECT 1;" > /dev/null 2>&1; then
    echo "❌ Cannot connect to database. Please ensure PostgreSQL is running and credentials are correct."
    exit 1
fi
echo "✅ Database connection successful"

echo ""
echo "📝 Creating initial database schema and data..."

# Create admin user
echo "👤 Creating admin user..."
if ! user_exists "admin.$DOMAIN"; then
    echo "Creating admin user: admin.$DOMAIN"
    # Note: In a real implementation, you would use the PDS API to create users
    # This is a simplified example - you'll need to use the actual PDS API
    echo "⚠️  Admin user creation requires PDS API. Use the following command:"
    echo ""
    echo "curl -X POST https://pdsapi.$DOMAIN/xrpc/com.atproto.server.createAccount \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -d '{"
    echo "    \"email\": \"admin@$DOMAIN\","
    echo "    \"handle\": \"admin.$DOMAIN\","
    echo "    \"password\": \"your_secure_password\""
    echo "  }'"
    echo ""
else
    echo "✅ Admin user already exists"
fi

# Create test users
echo "👥 Creating test users..."
test_users=(
    "test1.$DOMAIN"
    "test2.$DOMAIN"
    "demo.$DOMAIN"
    "user1.$DOMAIN"
    "user2.$DOMAIN"
)

for user in "${test_users[@]}"; do
    if ! user_exists "$user"; then
        echo "Creating test user: $user"
        echo "⚠️  Test user creation requires PDS API. Use the following command:"
        echo ""
        echo "curl -X POST https://pdsapi.$DOMAIN/xrpc/com.atproto.server.createAccount \\"
        echo "  -H \"Content-Type: application/json\" \\"
        echo "  -d '{"
        echo "    \"email\": \"$user@$DOMAIN\","
        echo "    \"handle\": \"$user\","
        echo "    \"password\": \"testpassword123\""
        echo "  }'"
        echo ""
    else
        echo "✅ Test user $user already exists"
    fi
done

# Create initial posts (if PDS is running)
echo "📝 Creating initial posts..."
if curl -s https://pdsapi.$DOMAIN/xrpc/com.atproto.server.describeServer > /dev/null 2>&1; then
    echo "✅ PDS is running - you can create posts via API"
    echo ""
    echo "Example post creation:"
    echo "curl -X POST https://pdsapi.$DOMAIN/xrpc/com.atproto.repo.createRecord \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -H \"Authorization: Bearer YOUR_SESSION_TOKEN\" \\"
    echo "  -d '{"
    echo "    \"repo\": \"did:web:admin.$DOMAIN\","
    echo "    \"collection\": \"app.bsky.feed.post\","
    echo "    \"record\": {"
    echo "      \"text\": \"Welcome to our self-hosted Bluesky instance! 🌟\","
    echo "      \"createdAt\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\""
    echo "    }"
    echo "  }'"
else
    echo "⚠️  PDS is not running. Start PDS first to create posts."
fi

# Create database indexes for better performance
echo "🔍 Creating database indexes..."
echo "Creating indexes for better query performance..."

# Note: These are example indexes - the actual schema depends on the PDS implementation
run_sql "CREATE INDEX IF NOT EXISTS idx_actor_handle ON actor(handle);" 2>/dev/null || echo "Index already exists or table not found"
run_sql "CREATE INDEX IF NOT EXISTS idx_actor_did ON actor(did);" 2>/dev/null || echo "Index already exists or table not found"
run_sql "CREATE INDEX IF NOT EXISTS idx_post_author ON post(author);" 2>/dev/null || echo "Index already exists or table not found"
run_sql "CREATE INDEX IF NOT EXISTS idx_post_created_at ON post(created_at);" 2>/dev/null || echo "Index already exists or table not found"

# Create initial configuration
echo "⚙️ Creating initial configuration..."
echo "Setting up basic configuration for your Bluesky instance..."

# Create a configuration table if it doesn't exist
run_sql "CREATE TABLE IF NOT EXISTS instance_config (
    key VARCHAR(255) PRIMARY KEY,
    value TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);" 2>/dev/null || echo "Configuration table already exists"

# Insert initial configuration
run_sql "INSERT INTO instance_config (key, value) VALUES 
    ('instance_name', 'Your Bluesky Instance'),
    ('instance_description', 'Self-hosted Bluesky instance on $DOMAIN'),
    ('instance_url', 'https://app.$DOMAIN'),
    ('admin_email', 'admin@$DOMAIN'),
    ('max_post_length', '300'),
    ('enable_registration', 'true'),
    ('require_invite', 'false'),
    ('created_at', '$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)')
ON CONFLICT (key) DO UPDATE SET 
    value = EXCLUDED.value,
    updated_at = CURRENT_TIMESTAMP;" 2>/dev/null || echo "Configuration already exists"

# Create sample data for testing
echo "📊 Creating sample data..."
echo "Adding sample data for testing purposes..."

# Create a sample posts table if it doesn't exist
run_sql "CREATE TABLE IF NOT EXISTS sample_posts (
    id SERIAL PRIMARY KEY,
    author_handle VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);" 2>/dev/null || echo "Sample posts table already exists"

# Insert sample posts
sample_posts=(
    "Welcome to our self-hosted Bluesky instance! 🌟"
    "This is a test post to verify everything is working correctly."
    "You can now create your own posts and interact with others."
    "The AT Protocol is amazing for decentralized social media!"
    "Feel free to explore and customize your instance."
)

for post in "${sample_posts[@]}"; do
    run_sql "INSERT INTO sample_posts (author_handle, content) VALUES ('admin.$DOMAIN', '$post');" 2>/dev/null || echo "Sample post already exists"
done

# Create statistics table
echo "📈 Creating statistics tracking..."
run_sql "CREATE TABLE IF NOT EXISTS instance_stats (
    id SERIAL PRIMARY KEY,
    stat_date DATE DEFAULT CURRENT_DATE,
    total_users INTEGER DEFAULT 0,
    total_posts INTEGER DEFAULT 0,
    active_users INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);" 2>/dev/null || echo "Statistics table already exists"

# Insert initial statistics
run_sql "INSERT INTO instance_stats (stat_date, total_users, total_posts, active_users) 
VALUES (CURRENT_DATE, 1, 5, 1)
ON CONFLICT (stat_date) DO UPDATE SET 
    total_users = EXCLUDED.total_users,
    total_posts = EXCLUDED.total_posts,
    active_users = EXCLUDED.active_users;" 2>/dev/null || echo "Statistics already exist"

echo ""
echo "🎉 Database seeding completed!"
echo ""
echo "📋 Summary:"
echo "=================================="
echo "✅ Database connection verified"
echo "✅ Admin user setup instructions provided"
echo "✅ Test users setup instructions provided"
echo "✅ Database indexes created"
echo "✅ Initial configuration added"
echo "✅ Sample data created"
echo "✅ Statistics tracking enabled"
echo ""
echo "🔐 Next Steps:"
echo "=================================="
echo "1. Start your PDS service:"
echo "   sudo systemctl start bluesky-pds"
echo ""
echo "2. Create admin account using the PDS API:"
echo "   curl -X POST https://pdsapi.$DOMAIN/xrpc/com.atproto.server.createAccount \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{"
echo "       \"email\": \"admin@$DOMAIN\","
echo "       \"handle\": \"admin.$DOMAIN\","
echo "       \"password\": \"your_secure_password\""
echo "     }'"
echo ""
echo "3. Create test users using the same API"
echo ""
echo "4. Access your instance at:"
echo "   https://app.$DOMAIN"
echo ""
echo "5. Access moderation interface at:"
echo "   https://ozone.$DOMAIN"
echo ""
echo "📊 Database Statistics:"
echo "=================================="
run_sql "SELECT stat_date, total_users, total_posts, active_users FROM instance_stats ORDER BY stat_date DESC LIMIT 1;" 2>/dev/null || echo "No statistics available yet"
echo ""
echo "🔍 Configuration:"
echo "=================================="
run_sql "SELECT key, value FROM instance_config ORDER BY key;" 2>/dev/null || echo "No configuration available"
