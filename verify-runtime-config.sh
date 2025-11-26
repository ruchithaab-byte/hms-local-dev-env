#!/bin/bash

# Runtime Configuration Verification Script
# This script verifies that all required environment variables are set
# before starting the HMS services.

set -e

echo "=========================================="
echo "HMS Runtime Configuration Verification"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ ERROR: .env file not found!${NC}"
    echo "   Please create a .env file in hms-local-dev-env/ directory"
    echo "   You can copy from .env.example if it exists"
    exit 1
fi

echo -e "${GREEN}✅ .env file found${NC}"
echo ""

# Source the .env file
set -a
source .env
set +a

# Track missing variables
MISSING_VARS=0

# Function to check variable
check_var() {
    local var_name=$1
    local var_value=${!var_name}
    local description=$2
    local source=$3
    
    if [ -z "$var_value" ]; then
        echo -e "${RED}❌ MISSING: $var_name${NC}"
        echo "   Description: $description"
        echo "   Source: $source"
        echo ""
        MISSING_VARS=$((MISSING_VARS + 1))
    else
        # Mask sensitive values (show first 8 chars only)
        if [[ "$var_name" == *"SECRET"* ]] || [[ "$var_name" == *"KEY"* ]] || [[ "$var_name" == *"PASSWORD"* ]]; then
            masked_value="${var_value:0:8}...${var_value: -4}"
            echo -e "${GREEN}✅ $var_name${NC} = $masked_value"
        else
            echo -e "${GREEN}✅ $var_name${NC} = $var_value"
        fi
    fi
}

echo "Checking Permit.io Configuration..."
echo "-----------------------------------"
check_var "PERMIT_API_KEY" \
    "Permit.io API Key for SDK authentication" \
    "Permit.io Dashboard → Settings → API Keys → Create/View API Key"

check_var "PERMIT_ENVIRONMENT" \
    "Permit.io Environment name (e.g., 'dev', 'production')" \
    "Permit.io Dashboard → Environments → Select/Create Environment"

# PERMIT_PDP_URL is set in docker-compose.yml, but verify it's correct
if [ -z "$PERMIT_PDP_URL" ]; then
    echo -e "${YELLOW}⚠️  PERMIT_PDP_URL not set in .env (will use docker-compose.yml default: http://permit-pdp-bff:7000)${NC}"
else
    check_var "PERMIT_PDP_URL" \
        "Permit.io PDP URL (should be http://permit-pdp-bff:7000 for BFF service)" \
        "Set in docker-compose.yml or .env"
fi
echo ""

echo "Checking ScaleKit Configuration..."
echo "-----------------------------------"
check_var "SCALEKIT_ENVIRONMENT_URL" \
    "ScaleKit Environment URL (e.g., https://your-org.scalekit.com)" \
    "ScaleKit Dashboard → Settings → Environment URL"

check_var "SCALEKIT_CLIENT_ID" \
    "ScaleKit OAuth Client ID" \
    "ScaleKit Dashboard → Applications → Your Application → Client ID"

check_var "SCALEKIT_CLIENT_SECRET" \
    "ScaleKit OAuth Client Secret" \
    "ScaleKit Dashboard → Applications → Your Application → Client Secret"

check_var "SCALEKIT_WEBHOOK_SECRET" \
    "ScaleKit Webhook Secret for signature verification" \
    "ScaleKit Dashboard → Webhooks → Your Webhook → Secret"
echo ""

echo "Checking Database Configuration..."
echo "-----------------------------------"
# These are usually set in docker-compose.yml, but check if overridden
if [ -z "$POSTGRES_USER" ]; then
    echo -e "${YELLOW}⚠️  POSTGRES_USER not set (will use docker-compose.yml default: postgres)${NC}"
else
    check_var "POSTGRES_USER" "PostgreSQL username" "docker-compose.yml or .env"
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
    echo -e "${YELLOW}⚠️  POSTGRES_PASSWORD not set (will use docker-compose.yml default: postgres)${NC}"
else
    check_var "POSTGRES_PASSWORD" "PostgreSQL password" "docker-compose.yml or .env"
fi
echo ""

# Summary
echo "=========================================="
if [ $MISSING_VARS -eq 0 ]; then
    echo -e "${GREEN}✅ All required environment variables are configured!${NC}"
    echo ""
    echo "You can now start the services with:"
    echo "  docker-compose up -d"
    echo ""
    exit 0
else
    echo -e "${RED}❌ $MISSING_VARS required variable(s) are missing!${NC}"
    echo ""
    echo "Please add the missing variables to your .env file."
    echo "See RUNTIME_CONFIGURATION.md for detailed instructions."
    echo ""
    exit 1
fi

