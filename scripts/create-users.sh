#!/bin/bash

# =============================================================================
# Bluesky User Creation Script
# =============================================================================
# This script creates users via the PDS API for your Bluesky instance

set -e

echo "👥 Creating users for your Bluesky instance..."
echo ""

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "❌ .env file not found. Please run the key generation script first."
    exit 1
fi

# PDS API endpoint
PDS_URL=https://pdsapi.sfproject.net

# Function to check if PDS is running
check_pds() {
    if curl -s "$PDS_URL/xrpc/com.atproto.server.describeServer" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to create user
create_user() {
    local email=$1
    local handle=$2
    local password=$3
    
    echo "Creating user: $handle"
    
    response=$(curl -s -w "%{http_code}" -X POST "$PDS_URL/xrpc/com.atproto.server.createAccount" \
        -H "Content-Type: application/json" \
        -d "{
            \"email\": \"$email\",
            \"handle\": \"$handle\",
            \"password\": \"$password\"
        }")
    
    http_code="${response: -3}"
    response_body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo "✅ Successfully created user: $handle"
        echo "$response_body" | jq -r '.accessJwt' > "tokens/${handle}.token" 2>/dev/null || echo "Could not save token"
        return 0
    else
        echo "❌ Failed to create user: $handle (HTTP $http_code)"
        echo "Response: $response_body"
        return 1
    fi
}

# Function to create a post
create_post() {
    local handle=$1
    local token_file=$2
    local content=$3
    
    if [ ! -f "$token_file" ]; then
        echo "⚠️  No token file found for $handle, skipping post creation"
        return 1
    fi
    
    local token=$(cat "$token_file")
    local did="did:web:$handle"
    
    echo "Creating post for $handle: $content"
    
    response=$(curl -s -w "%{http_code}" -X POST "$PDS_URL/xrpc/com.atproto.repo.createRecord" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -d "{
            \"repo\": \"$did\",
            \"collection\": \"app.bsky.feed.post\",
            \"record\": {
                \"text\": \"$content\",
                \"createdAt\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\"
            }
        }")
    
    http_code="${response: -3}"
    response_body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo "✅ Successfully created post for: $handle"
        return 0
    else
        echo "❌ Failed to create post for: $handle (HTTP $http_code)"
        echo "Response: $response_body"
        return 1
    fi
}

# Check if PDS is running
echo "🔍 Checking if PDS is running..."
if ! check_pds; then
    echo "❌ PDS is not running. Please start the PDS service first:"
    echo "   sudo systemctl start bluesky-pds"
    echo ""
    echo "Then wait a moment and try again."
    exit 1
fi
echo "✅ PDS is running"

# Create tokens directory
mkdir -p tokens

# Get domain from environment or prompt user
DOMAIN=pdsapi.sfproject.net


# Remove any protocol prefixes
DOMAIN=$(echo "$DOMAIN" | sed 's|^https?://||' | sed 's|^pdsapi\.||')

# Define users to create
declare -A users=(
    ["admin.$DOMAIN"]="admin@$DOMAIN:adminpassword123"
    ["test1.$DOMAIN"]="test1@$DOMAIN:testpassword123"
    ["test2.$DOMAIN"]="test2@$DOMAIN:testpassword123"
    ["demo.$DOMAIN"]="demo@$DOMAIN:demopassword123"
    ["user1.$DOMAIN"]="user1@$DOMAIN:userpassword123"
    ["user2.$DOMAIN"]="user2@$DOMAIN:userpassword123"
)

# Create users
echo ""
echo "👤 Creating users..."
successful_users=()

for handle in "${!users[@]}"; do
    IFS=':' read -r email password <<< "${users[$handle]}"
    
    if create_user "$email" "$handle" "$password"; then
        successful_users+=("$handle")
    fi
    
    echo ""
done

# Create initial posts for successful users
if [ ${#successful_users[@]} -gt 0 ]; then
    echo "📝 Creating initial posts..."
    
    # Welcome posts for each user
    declare -A welcome_posts=(
        ["admin.$DOMAIN"]="Welcome to our self-hosted Bluesky instance! 🌟 I'm the admin and I'm excited to see you here."
        ["test1.$DOMAIN"]="Hello everyone! This is test1 checking in. The AT Protocol is amazing! 🚀"
        ["test2.$DOMAIN"]="Hey there! Test2 here. Loving this decentralized social media experience! ✨"
        ["demo.$DOMAIN"]="Welcome to the demo! This is what a self-hosted Bluesky instance looks like. 🎉"
        ["user1.$DOMAIN"]="Hi friends! User1 here. Excited to be part of this community! 👋"
        ["user2.$DOMAIN"]="Greetings! User2 checking in. The future of social media is decentralized! 🌐"
    )
    
    for handle in "${successful_users[@]}"; do
        if [ -n "${welcome_posts[$handle]}" ]; then
            create_post "$handle" "tokens/${handle}.token" "${welcome_posts[$handle]}"
        fi
        echo ""
    done
    
    # Create some additional posts for admin
    if [[ " ${successful_users[@]} " =~ " admin.$DOMAIN " ]]; then
        additional_posts=(
            "This instance is running on the AT Protocol, which means you own your data! 🔐"
            "You can customize this instance, add features, and make it your own. 🛠️"
            "The AT Protocol enables true decentralization and user control. 💪"
            "Feel free to explore and experiment with the features! 🎯"
        )
        
        for post in "${additional_posts[@]}"; do
            create_post "admin.$DOMAIN" "tokens/admin.$DOMAIN.token" "$post"
            echo ""
        done
    fi
fi

echo ""
echo "🎉 User creation completed!"
echo ""
echo "📋 Summary:"
echo "=================================="
echo "✅ PDS connection verified"
echo "✅ Created ${#successful_users[@]} users"
echo "✅ Created initial posts"
echo "✅ Tokens saved to tokens/ directory"
echo ""
echo "👥 Created Users:"
echo "=================================="
for user in "${successful_users[@]}"; do
    echo "• $user"
done
echo ""
echo "🔐 Login Information:"
echo "=================================="
for handle in "${!users[@]}"; do
    IFS=':' read -r email password <<< "${users[$handle]}"
    echo "Handle: $handle"
    echo "Email: $email"
    echo "Password: $password"
    echo "---"
done
echo ""
echo "🌐 Access Your Instance:"
echo "=================================="
echo "Web App:           https://app.$DOMAIN"
echo "Moderation:        https://ozone.$DOMAIN"
echo "API Documentation: https://introspect.$DOMAIN"
echo ""
echo "📝 Next Steps:"
echo "=================================="
echo "1. Visit https://app.$DOMAIN"
echo "2. Log in with any of the created accounts"
echo "3. Start posting and interacting!"
echo "4. Customize your instance settings"
echo "5. Invite more users to join"
echo ""
echo "🔒 Security Notes:"
echo "=================================="
echo "• Change default passwords after first login"
echo "• Tokens are stored in tokens/ directory - keep them secure"
echo "• Consider setting up additional security measures"
echo "• Regularly backup your database"
echo ""
echo "📊 Token Files:"
echo "=================================="
if [ -d "tokens" ] && [ "$(ls -A tokens)" ]; then
    ls -la tokens/
else
    echo "No token files created"
fi
