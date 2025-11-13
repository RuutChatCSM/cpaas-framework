#!/bin/bash

# =============================================================================
# Quick Fix Script for Deployment Issues
# =============================================================================

set -euo pipefail

echo "🔧 Fixing common deployment issues..."

# Fix 1: Remove obsolete version field from docker-compose.yml
echo "📝 Removing obsolete version field..."
if grep -q "^version:" docker-compose.yml; then
    sed -i '/^version:/d' docker-compose.yml
    echo "✅ Removed version field"
fi

# Fix 2: Fix RTP port ranges in FreeSWITCH services
echo "🔧 Fixing RTP port ranges..."
sed -i 's/16384-32768:16384-32768/16384-32767:16384-32767/g' docker-compose.yml
sed -i 's/32769-49152:16384-32768/32768-49151:16384-32767/g' docker-compose.yml
echo "✅ Fixed RTP port ranges"

# Fix 3: Check for undefined variables in .env
echo "🔍 Checking .env file for undefined variables..."
if [[ -f .env ]]; then
    # Remove any lines with undefined variables or fix common issues
    sed -i '/^k=/d' .env 2>/dev/null || true
    sed -i '/^\${k/d' .env 2>/dev/null || true
    
    # Ensure required variables are set
    if ! grep -q "^PUBLIC_IP=" .env; then
        echo "PUBLIC_IP=YOUR_SERVER_IP" >> .env
        echo "⚠️  Added PUBLIC_IP to .env - please update with your server's IP"
    fi
    
    if ! grep -q "^EXT_RTP_IP=" .env; then
        echo "EXT_RTP_IP=YOUR_SERVER_IP" >> .env
        echo "⚠️  Added EXT_RTP_IP to .env - please update with your server's IP"
    fi
    
    if ! grep -q "^EXT_SIP_IP=" .env; then
        echo "EXT_SIP_IP=YOUR_SERVER_IP" >> .env
        echo "⚠️  Added EXT_SIP_IP to .env - please update with your server's IP"
    fi
    
    echo "✅ Checked .env file"
else
    echo "⚠️  .env file not found - copying from .env.example"
    cp .env.example .env
    echo "📝 Please edit .env file with your configuration"
fi

# Fix 4: Validate docker-compose.yml syntax
echo "🔍 Validating docker-compose.yml syntax..."
if docker compose config > /dev/null 2>&1; then
    echo "✅ docker-compose.yml syntax is valid"
else
    echo "❌ docker-compose.yml has syntax errors. Running config check:"
    docker compose config
    exit 1
fi

echo ""
echo "🎉 All fixes applied successfully!"
echo ""
echo "Next steps:"
echo "1. Edit your .env file with correct values:"
echo "   - Set PUBLIC_IP to your server's public IP address"
echo "   - Set SOMLENG_DOMAIN to your domain name"
echo "   - Update database passwords and secrets"
echo ""
echo "2. Run the deployment:"
echo "   docker compose up -d"
echo ""
echo "3. Check service status:"
echo "   docker compose ps"
echo ""
echo "4. View logs if needed:"
echo "   docker compose logs -f"