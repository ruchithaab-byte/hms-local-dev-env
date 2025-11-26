#!/bin/bash

# Test script for permission management POC
# Tests ingress enforcement (Kong) and application-level enforcement

set -e

KONG_URL="http://localhost:8000"
WORKFLOW_URL="http://localhost:8080"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Testing Permission Management POC                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Request without JWT (should fail)
echo "Test 1: Request without JWT (should return 401)"
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${KONG_URL}/api/auth/onboarding/start" \
    -H "Content-Type: application/json" \
    -d '{"tenantName":"Test Corp","adminEmail":"test@example.com"}')

if [ "$response" == "401" ]; then
    echo -e "${GREEN}✓ PASS${NC}: Got 401 Unauthorized (expected)"
else
    echo -e "${RED}✗ FAIL${NC}: Expected 401, got $response"
fi
echo ""

# Test 2: Request with invalid JWT (should fail)
echo "Test 2: Request with invalid JWT (should return 401)"
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${KONG_URL}/api/auth/onboarding/start" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer invalid.jwt.token" \
    -d '{"tenantName":"Test Corp","adminEmail":"test@example.com"}')

if [ "$response" == "401" ]; then
    echo -e "${GREEN}✓ PASS${NC}: Got 401 Unauthorized (expected)"
else
    echo -e "${RED}✗ FAIL${NC}: Expected 401, got $response"
fi
echo ""

# Test 3: Request with valid JWT but insufficient permissions (should fail)
echo "Test 3: Request with valid JWT but insufficient permissions (should return 403)"
echo -e "${YELLOW}Note: This requires a valid JWT with 'viewer' role${NC}"
echo "Skipping (requires valid JWT token generation)"
echo ""

# Test 4: Request with valid JWT and correct permissions (should succeed)
echo "Test 4: Request with valid JWT and correct permissions (should return 202)"
echo -e "${YELLOW}Note: This requires a valid JWT with 'admin' role${NC}"
echo "Skipping (requires valid JWT token generation)"
echo ""

# Test 5: Direct service call (bypassing Kong) - should still enforce permissions
echo "Test 5: Direct service call with permission check"
echo -e "${YELLOW}Note: This tests application-level enforcement${NC}"
echo "Skipping (requires valid JWT token generation)"
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Test Summary                                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "To run full tests, you need:"
echo "1. Valid JWT tokens with different roles (admin, viewer, ai_agent)"
echo "2. Permit.io account configured with policies"
echo "3. Permit.io PDP sidecars running"
echo ""
echo "Example JWT generation (using ScaleKit or jwt.io):"
echo "  - Admin role: { 'sub': 'user123', 'org_id': 'org456', 'roles': ['admin'] }"
echo "  - Viewer role: { 'sub': 'user123', 'org_id': 'org456', 'roles': ['viewer'] }"
echo "  - Agent role: { 'sub': 'user123', 'org_id': 'org456', 'act': { 'sub': 'agent789' } }"
echo ""

