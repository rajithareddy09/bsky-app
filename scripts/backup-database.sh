#!/bin/bash

# =============================================================================
# Bluesky Database Backup Script
# =============================================================================
# This script creates backups of your Bluesky database

set -e

echo "💾 Creating Bluesky database backup..."
echo ""

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

# Backup settings
BACKUP_DIR="backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/bluesky_backup_${DATE}.sql"
COMPRESSED_BACKUP="${BACKUP_FILE}.gz"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to check database connection
check_db_connection() {
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to get database size
get_db_size() {
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" | xargs
}

# Function to get table information
get_table_info() {
    echo "Database tables and sizes:"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT 
        schemaname,
        tablename,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
    FROM pg_tables 
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
}

# Check database connection
echo "🔍 Checking database connection..."
if ! check_db_connection; then
    echo "❌ Cannot connect to database. Please ensure PostgreSQL is running and credentials are correct."
    exit 1
fi
echo "✅ Database connection successful"

# Get database information
echo "📊 Database information:"
DB_SIZE=$(get_db_size)
echo "Database size: $DB_SIZE"
echo ""

# Show table information
get_table_info
echo ""

# Create backup
echo "💾 Creating backup..."
echo "Backup file: $BACKUP_FILE"

# Create the backup
if PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    --verbose \
    --clean \
    --if-exists \
    --create \
    --no-owner \
    --no-privileges \
    --format=custom \
    --file="$BACKUP_FILE"; then
    
    echo "✅ Database backup created successfully"
    
    # Compress the backup
    echo "🗜️ Compressing backup..."
    if gzip "$BACKUP_FILE"; then
        echo "✅ Backup compressed: $COMPRESSED_BACKUP"
        BACKUP_SIZE=$(du -h "$COMPRESSED_BACKUP" | cut -f1)
        echo "Backup size: $BACKUP_SIZE"
    else
        echo "⚠️ Failed to compress backup, keeping uncompressed version"
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        echo "Backup size: $BACKUP_SIZE"
    fi
    
else
    echo "❌ Failed to create database backup"
    exit 1
fi

# Create a backup manifest
echo "📝 Creating backup manifest..."
MANIFEST_FILE="${BACKUP_DIR}/backup_manifest_${DATE}.txt"

cat > "$MANIFEST_FILE" << EOF
Bluesky Database Backup Manifest
================================
Backup Date: $(date)
Backup File: $(basename "$COMPRESSED_BACKUP")
Database: $DB_NAME
Database Size: $DB_SIZE
Backup Size: $BACKUP_SIZE
Host: $DB_HOST:$DB_PORT
User: $DB_USER

Backup Contents:
- Complete database schema
- All data tables
- Indexes and constraints
- Sequences and functions

Restore Command:
pg_restore -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME --clean --if-exists $COMPRESSED_BACKUP

Or for SQL format:
gunzip -c $COMPRESSED_BACKUP | psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME

Created by: Bluesky Self-Hosted Backup Script
EOF

echo "✅ Backup manifest created: $MANIFEST_FILE"

# Clean up old backups (keep last 10)
echo "🧹 Cleaning up old backups..."
cd "$BACKUP_DIR"
ls -t bluesky_backup_*.sql.gz 2>/dev/null | tail -n +11 | xargs -r rm -f
ls -t backup_manifest_*.txt 2>/dev/null | tail -n +11 | xargs -r rm -f
cd ..

# Show backup summary
echo ""
echo "📋 Backup Summary:"
echo "=================================="
echo "✅ Database backup completed"
echo "📁 Backup location: $BACKUP_DIR"
echo "📄 Backup file: $(basename "$COMPRESSED_BACKUP")"
echo "📊 Backup size: $BACKUP_SIZE"
echo "📝 Manifest: $(basename "$MANIFEST_FILE")"
echo "🗓️ Backup date: $(date)"
echo ""

# List all backups
echo "📚 Available backups:"
echo "=================================="
if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR")" ]; then
    ls -lah "$BACKUP_DIR"/bluesky_backup_*.sql.gz 2>/dev/null | while read -r line; do
        echo "$line"
    done
else
    echo "No previous backups found"
fi

echo ""
echo "🔄 Restore Instructions:"
echo "=================================="
echo "To restore from this backup:"
echo ""
echo "1. Stop the Bluesky services:"
echo "   sudo systemctl stop bluesky-pds"
echo "   sudo systemctl stop bluesky-appview"
echo "   sudo systemctl stop bluesky-ozone"
echo "   sudo systemctl stop bluesky-bsync"
echo ""
echo "2. Restore the database:"
echo "   gunzip -c $COMPRESSED_BACKUP | psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"
echo ""
echo "3. Restart the services:"
echo "   sudo systemctl start bluesky-pds"
echo "   sudo systemctl start bluesky-appview"
echo "   sudo systemctl start bluesky-ozone"
echo "   sudo systemctl start bluesky-bsync"
echo ""
echo "⚠️  Warning: Restoring will overwrite existing data!"
echo ""

# Optional: Create a scheduled backup script
echo "⏰ Setting up automated backups:"
echo "=================================="
echo "To set up automated daily backups, add to crontab:"
echo "sudo crontab -e"
echo ""
echo "Add this line for daily backups at 2 AM:"
echo "0 2 * * * cd $(pwd) && ./scripts/backup-database.sh >> logs/backup.log 2>&1"
echo ""
echo "Or for weekly backups on Sundays at 2 AM:"
echo "0 2 * * 0 cd $(pwd) && ./scripts/backup-database.sh >> logs/backup.log 2>&1"
echo ""

echo "🎉 Backup process completed successfully!"
