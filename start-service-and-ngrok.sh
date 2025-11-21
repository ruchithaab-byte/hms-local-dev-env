#!/bin/bash
# Start HMS stack with Kong Gateway and ngrok, then get the webhook URL
# Updated to use Kong Gateway (port 8000) as the unified entry point

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     🚀 STARTING HMS STACK WITH KONG GATEWAY & KUMA MESH    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check Docker
if ! docker ps > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi
echo "✅ Docker is running"

# Check ngrok authentication
if ! ngrok config check > /dev/null 2>&1; then
    echo ""
    echo "⚠️  ngrok needs authentication!"
    echo "   1. Visit: https://dashboard.ngrok.com/signup"
    echo "   2. Get token: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "   3. Run: ngrok config add-authtoken <your-token>"
    echo ""
    exit 1
fi
echo "✅ ngrok is authenticated"

# Start infrastructure and services
echo ""
echo "📦 Starting infrastructure (Postgres, Redis, Kafka)..."
cd /Users/macbook/hms-local-dev-env
docker-compose up -d postgres redis zookeeper kafka

echo "⏳ Waiting for infrastructure to be ready..."
sleep 5

# Start Kuma Control Plane
echo ""
echo "🔷 Starting Kuma Service Mesh Control Plane..."
docker-compose up -d kuma-cp

echo "⏳ Waiting for Kuma Control Plane to be ready..."
sleep 10

# Initialize Kuma (apply mesh config and policies)
echo ""
echo "🔧 Initializing Kuma Service Mesh..."
cd kuma
if [ -f "init-kuma.sh" ]; then
    ./init-kuma.sh
else
    echo "⚠️  init-kuma.sh not found, skipping Kuma initialization"
fi
cd ..

# Prepare build context (build libraries and copy to services)
echo ""
echo "🔧 Preparing build context for services..."
./build-local.sh

echo "📦 Starting microservices with Kuma sidecars (BFF, Workflow)..."
docker-compose up -d --build hms-auth-bff hms-onboarding-workflow \
    hms-auth-bff-sidecar hms-onboarding-workflow-sidecar

echo "⏳ Waiting for services and sidecars to start..."
sleep 15

# Check if BFF service is ready
if ! docker-compose ps hms-auth-bff | grep -q "Up"; then
    echo "⚠️  BFF service is not running"
    echo "   Check logs: docker-compose logs hms-auth-bff"
    exit 1
fi
echo "✅ BFF service is running"

# Start Kong Gateway
echo ""
echo "🌐 Starting Kong Gateway..."
docker-compose up -d kong

echo "⏳ Waiting for Kong Gateway to be ready..."
sleep 5

# Check if Kong is ready
if ! docker-compose ps kong | grep -q "Up"; then
    echo "⚠️  Kong Gateway is not running"
    echo "   Check logs: docker-compose logs kong"
    exit 1
fi

# Verify Kong health (DB-less mode compatible)
echo "🔍 Checking Kong status..."

# We check for 'server' block which exists in both DB and DB-less modes
KONG_HEALTH=$(curl -s http://localhost:8001/status 2>/dev/null | grep -o '"server":' || echo "")
if [ -z "$KONG_HEALTH" ]; then
    echo "⚠️  Kong Gateway API is not reachable"
    echo "   Check logs: docker-compose logs kong"
    exit 1
fi

# Verify Configuration is Loaded (Declarative Config check)
KONG_ROUTES=$(curl -s http://localhost:8001/routes 2>/dev/null | grep -o '"id":' | wc -l)
if [ "$KONG_ROUTES" -eq 0 ]; then
    echo "⚠️  Kong is running but has NO routes loaded (Declarative config failed)"
    echo "   Check logs: docker-compose logs kong"
    exit 1
fi

echo "✅ Kong Gateway is healthy (DB-less mode, $KONG_ROUTES routes loaded)"

# Verify Kong can route to BFF
echo ""
echo "🔍 Testing Kong routing..."
BFF_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/auth/login 2>/dev/null || echo "000")
if [ "$BFF_TEST" != "200" ] && [ "$BFF_TEST" != "401" ] && [ "$BFF_TEST" != "404" ]; then
    echo "⚠️  Kong routing test failed (HTTP $BFF_TEST)"
    echo "   This might be normal if the endpoint requires authentication"
else
    echo "✅ Kong routing is working (HTTP $BFF_TEST)"
fi

# Check if port 8000 is active (Kong Gateway)
if ! lsof -ti:8000 > /dev/null 2>&1; then
    echo "⚠️  Kong Gateway is not responding on port 8000"
    echo "   Check logs: docker-compose logs kong"
    exit 1
fi
echo "✅ Kong Gateway is running on port 8000"

# Kill any existing ngrok
pkill -f "[n]grok http" 2>/dev/null || true
sleep 1

# Start ngrok pointing to Kong Gateway (port 8000)
echo ""
echo "🌐 Starting ngrok (tunneling Kong Gateway on port 8000)..."
ngrok http 8000 --log=stdout > /tmp/ngrok.log 2>&1 &
NGROK_PID=$!
sleep 5

# Get the public URL
echo "⏳ Getting public URL..."
for i in {1..10}; do
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | \
        python3 -c "import sys, json; data = json.load(sys.stdin); tunnels = data.get('tunnels', []); \
        https_tunnel = next((t for t in tunnels if 'https://' in t.get('public_url', '')), None); \
        print(https_tunnel['public_url'] if https_tunnel else '')" 2>/dev/null)
    
    if [ -n "$NGROK_URL" ]; then
        break
    fi
    sleep 1
done

if [ -n "$NGROK_URL" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     ✅ HMS STACK READY (KONG + KUMA MESH)                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "🌐 NGROK PUBLIC URL:"
    echo "   $NGROK_URL"
    echo ""
    echo "📝 USE THIS IN SCALEKIT (Webhook Endpoint):"
    echo "   $NGROK_URL/api/webhooks/scalekit"
    echo ""
    echo "📋 SCALEKIT WEBHOOK CONFIGURATION:"
    echo "   Display Name: Julley"
    echo "   Endpoint URL: $NGROK_URL/api/webhooks/scalekit"
    echo "   Events: Enterprise SSO, SCIM Provisioning"
    echo ""
    echo "🔗 API ENDPOINTS (Through Kong Gateway):"
    echo "   • Authentication: $NGROK_URL/api/auth/*"
    echo "   • Webhooks: $NGROK_URL/api/webhooks/*"
    echo "   • Login: $NGROK_URL/login"
    echo "   • OAuth: $NGROK_URL/oauth2/*"
    echo "   • Workflow: $NGROK_URL/api/v1/onboarding/*"
    echo ""
    echo "💡 To view ngrok dashboard: http://localhost:4040"
    echo "💡 To view Kong Admin API: http://localhost:8001"
    echo "💡 To view Kuma GUI: http://localhost:5681/gui/"
    echo "💡 To view Kuma API: http://localhost:5681"
    echo "💡 To stop: pkill -f 'ngrok http' && docker-compose down"
    echo ""
    echo "✅ All services are running through Kong Gateway + Kuma Mesh!"
    echo ""
    echo "🔒 Service-to-Service Communication:"
    echo "   • mTLS: Enabled (permissive mode)"
    echo "   • Retries: Automatic on 5xx errors"
    echo "   • Circuit Breaking: Enabled"
    echo "   • Context Propagation: x-hms-* headers preserved"
else
    echo ""
    echo "⚠️  Could not get ngrok URL. Check manually:"
    echo "   http://localhost:4040"
    echo "   Or view logs: tail -f /tmp/ngrok.log"
fi
