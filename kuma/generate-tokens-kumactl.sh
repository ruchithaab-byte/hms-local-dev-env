#!/bin/bash
set -e

# Generate Kuma Dataplane Tokens using kumactl
# Prerequisites: kumactl must be installed (brew install kumactl)

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     🔑 GENERATING KUMA DATAPLANE TOKENS (kumactl)            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if kumactl is installed
if ! command -v kumactl &> /dev/null; then
    echo "❌ kumactl is not installed"
    echo ""
    echo "📦 Install kumactl:"
    echo "   macOS: brew install kumactl"
    echo "   Or download from: https://github.com/kumahq/kuma/releases"
    exit 1
fi

# Get admin token from Kuma CP container (localhost admin access)
echo "🔐 Retrieving admin token from Kuma CP..."
ADMIN_TOKEN=$(docker exec kuma-cp sh -c 'wget -qO- http://localhost:5681/global-secrets/admin-user-token 2>/dev/null' 2>/dev/null | \
    python3 -c "import sys, json, base64; data = json.load(sys.stdin); print(base64.b64decode(data['data']).decode())" 2>/dev/null || echo "")

if [ -z "$ADMIN_TOKEN" ]; then
    echo "❌ Failed to retrieve admin token from Kuma CP container"
    echo "   Make sure Kuma CP is running: docker-compose up -d kuma-cp"
    exit 1
fi

# Configure kumactl with admin token
echo "⚙️  Configuring kumactl with admin token..."
kumactl config control-planes add \
    --name=local \
    --address=http://localhost:5681 \
    --auth-type=tokens \
    --auth-conf token="$ADMIN_TOKEN" \
    --overwrite 2>/dev/null || true

# Verify connection
echo "🔍 Verifying connection to Kuma CP..."
if ! kumactl inspect control-planes &> /dev/null; then
    echo "❌ Cannot connect to Kuma CP at http://localhost:5681"
    echo "   Make sure Kuma CP is running: docker-compose up -d kuma-cp"
    exit 1
fi
echo "✅ Connected to Kuma CP (authenticated)"
echo ""

# Create tokens directory
mkdir -p tokens

# Generate tokens for each service
SERVICES=("hms-auth-bff" "hms-onboarding-workflow" "hms-dashboard-projector")

for SERVICE in "${SERVICES[@]}"; do
    echo "🔑 Generating token for $SERVICE..."
    # Note: kumactl 2.12.4+ requires --valid-for flag (e.g., 24h, 720h for 30 days)
    # Generate token and filter out WARNING messages (version mismatch warnings)
    # CRITICAL: Token must be a single line with no newlines
    TOKEN_OUTPUT=$(kumactl generate dataplane-token --mesh=default --name="$SERVICE" --valid-for=720h 2>&1 | grep -v "^WARNING" | head -1)
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ] && [ -n "$TOKEN_OUTPUT" ]; then
        # Remove all newlines, carriage returns, and whitespace, save as single line
        echo -n "$TOKEN_OUTPUT" | tr -d '\n\r\t ' > "tokens/${SERVICE}-token"
        echo "   ✅ Token saved to tokens/${SERVICE}-token"
    else
        echo "   ❌ Failed to generate token for $SERVICE"
        echo "   Error: $TOKEN_OUTPUT"
        exit 1
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     ✅ TOKEN GENERATION COMPLETE                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📝 Next steps:"
echo "   1. Tokens are already configured in docker-compose.yml"
echo "   2. Restart sidecars: docker-compose restart *-sidecar"
echo "   3. Verify in Kuma GUI: http://localhost:5681/gui/"

