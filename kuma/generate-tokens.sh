#!/bin/bash
set -e

# Generate Kuma Dataplane Tokens for Local Development
# This script generates tokens for all services in the mesh

KUMA_CP_URL="http://localhost:5681"
MESH="default"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     🔑 GENERATING KUMA DATAPLANE TOKENS                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Create tokens directory
mkdir -p tokens

# Method 1: Try to get admin token from inside the container (most reliable)
echo "📋 Attempting to retrieve admin token from Kuma CP container..."
ADMIN_TOKEN=$(docker exec kuma-cp sh -c 'wget -qO- http://localhost:5681/global-secrets/admin-user-token 2>/dev/null | grep -o "\"data\":\"[^\"]*" | cut -d\" -f4 | base64 -d 2>/dev/null' 2>/dev/null || echo "")

if [ -z "$ADMIN_TOKEN" ]; then
    echo "⚠️  Could not retrieve admin token from container."
    echo "   Trying alternative method..."
    # Method 2: Try from host (may require localhost admin access)
    ADMIN_TOKEN=$(curl -s http://localhost:5681/global-secrets/admin-user-token 2>/dev/null | python3 -c "import sys, json, base64; data = json.load(sys.stdin); print(base64.b64decode(data['data']).decode())" 2>/dev/null || echo "")
fi

if [ -z "$ADMIN_TOKEN" ]; then
    echo "❌ Failed to retrieve admin token."
    echo ""
    echo "💡 Alternative: Install kumactl locally and run:"
    echo "   kumactl config control-planes add --name=local --address=http://localhost:5681"
    echo "   kumactl generate dataplane-token --mesh=default --name=hms-auth-bff > tokens/hms-auth-bff-token"
    exit 1
fi

echo "✅ Admin token retrieved"
echo ""

# Generate tokens for each service
SERVICES=("hms-auth-bff" "hms-onboarding-workflow" "hms-dashboard-projector")

for SERVICE in "${SERVICES[@]}"; do
    echo "🔑 Generating token for $SERVICE..."
    TOKEN=$(curl -s -X POST "${KUMA_CP_URL}/tokens/dataplane" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -d "{\"mesh\":\"${MESH}\",\"name\":\"${SERVICE}\"}" 2>/dev/null | \
        python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('token', ''))" 2>/dev/null || echo "")
    
    if [ -n "$TOKEN" ]; then
        echo "$TOKEN" > "tokens/${SERVICE}-token"
        echo "   ✅ Token saved to tokens/${SERVICE}-token"
    else
        echo "   ❌ Failed to generate token for $SERVICE"
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     ✅ TOKEN GENERATION COMPLETE                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📝 Next steps:"
echo "   1. Update docker-compose.yml to mount token files in sidecars"
echo "   2. Update sidecar commands to use --dataplane-token-file"
echo "   3. Restart sidecars: docker-compose restart *-sidecar"

