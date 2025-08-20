#!/bin/bash

# Script to replace all occurrences of public.api.bsky.app with bsky.sfproject.net

echo "🔍 Replacing all URLs from public.api.bsky.app to bsky.sfproject.net..."

# Replace in all TypeScript, JavaScript, HTML, Go, and env files
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.html" -o -name "*.go" -o -name "*.env" \) -exec sed -i 's|public\.api\.bsky\.app|bsky.sfproject.net|g' {} \;

echo "✅ URL replacement complete!"
echo ""
echo "📋 Files that were modified:"
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.html" -o -name "*.go" -o -name "*.env" \) -exec grep -l "bsky.sfproject.net" {} \;

echo ""
echo "🔍 Verifying replacement:"
grep -r "public\.api\.bsky\.app" . --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.html" --include="*.go" --include="*.env" || echo "✅ No remaining occurrences found!"
