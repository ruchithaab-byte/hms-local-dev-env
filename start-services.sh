#!/bin/bash

# HMS Services Startup Script
# This script starts all services in the correct order with health checks

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=========================================="
echo "HMS Services Startup Script"
echo "=========================================="
echo ""

# Step 1: Check Docker
echo -e "${YELLOW}Step 1: Checking Docker...${NC}"
if ! docker ps > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running!${NC}"
    echo "   Please start Docker Desktop and try again."
    echo "   On macOS: open -a Docker"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"
echo ""

# Step 2: Verify .env
echo -e "${YELLOW}Step 2: Verifying environment configuration...${NC}"
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env file not found!${NC}"
    exit 1
fi

# Quick check for required variables
if ! grep -q "^PERMIT_API_KEY=" .env; then
    echo -e "${RED}❌ PERMIT_API_KEY not found in .env${NC}"
    exit 1
fi

if ! grep -q "^PERMIT_ENVIRONMENT=" .env; then
    echo -e "${RED}❌ PERMIT_ENVIRONMENT not found in .env${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Environment variables configured${NC}"
echo ""

# Step 3: Start Infrastructure
echo -e "${YELLOW}Step 3: Starting infrastructure services...${NC}"
docker-compose up -d postgres redis kuma-cp

echo "   Waiting for infrastructure to be healthy..."
sleep 10

# Check health
if docker-compose ps postgres | grep -q "healthy"; then
    echo -e "${GREEN}✅ PostgreSQL is healthy${NC}"
else
    echo -e "${YELLOW}⚠️  PostgreSQL may still be starting...${NC}"
fi

if docker-compose ps redis | grep -q "healthy"; then
    echo -e "${GREEN}✅ Redis is healthy${NC}"
else
    echo -e "${YELLOW}⚠️  Redis may still be starting...${NC}"
fi
echo ""

# Step 4: Start Permit.io PDPs
echo -e "${YELLOW}Step 4: Starting Permit.io PDP containers...${NC}"
docker-compose up -d permit-pdp-kong permit-pdp-workflow permit-pdp-bff

echo "   Waiting for PDPs to be healthy..."
sleep 5

# Check PDP health
PDP_COUNT=0
for pdp in permit-pdp-kong permit-pdp-workflow permit-pdp-bff; do
    if docker-compose ps $pdp | grep -q "healthy\|Up"; then
        echo -e "${GREEN}✅ $pdp is running${NC}"
        PDP_COUNT=$((PDP_COUNT + 1))
    else
        echo -e "${YELLOW}⚠️  $pdp may still be starting...${NC}"
    fi
done
echo ""

# Step 5: Start Application Services
echo -e "${YELLOW}Step 5: Starting hms-auth-bff service...${NC}"
docker-compose up -d hms-auth-bff

echo "   Waiting for application to start (this may take 30-60 seconds)..."
sleep 15

# Step 6: Check Status
echo ""
echo -e "${YELLOW}Step 6: Checking service status...${NC}"
docker-compose ps

echo ""
echo -e "${YELLOW}Step 7: Checking application logs...${NC}"
echo "   Looking for initialization messages..."
sleep 5

# Check for Permit.io initialization
if docker-compose logs hms-auth-bff 2>&1 | grep -qi "Permit.*initialized\|PermitSyncService"; then
    echo -e "${GREEN}✅ Permit.io services initialized${NC}"
else
    echo -e "${YELLOW}⚠️  Permit.io initialization not yet visible in logs${NC}"
fi

# Check for errors
ERROR_COUNT=$(docker-compose logs hms-auth-bff 2>&1 | grep -ic "error\|exception" || true)
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $ERROR_COUNT error(s) in logs (check with: docker-compose logs hms-auth-bff)${NC}"
else
    echo -e "${GREEN}✅ No critical errors found${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Startup process completed!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Check logs: docker-compose logs -f hms-auth-bff"
echo "  2. Test health: curl http://localhost:8080/actuator/health"
echo "  3. View all services: docker-compose ps"
echo ""
echo "To stop services: docker-compose down"
echo ""

