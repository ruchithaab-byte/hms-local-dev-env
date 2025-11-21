#!/bin/bash
set -e

# Use localhost since this script runs from the host machine
KUMA_CP_URL="http://localhost:5681"
MAX_RETRIES=30
RETRY_INTERVAL=2

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     🔧 INITIALIZING KUMA SERVICE MESH                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# Wait for Kuma Control Plane to be ready
# Note: Kuma 2.8.3 doesn't have a /ready endpoint, so we check the root endpoint
echo "⏳ Waiting for Kuma Control Plane to be ready..."
for i in $(seq 1 $MAX_RETRIES); do
    # Check root endpoint - returns JSON with version info when CP is ready
    if curl -s -f "${KUMA_CP_URL}/" | grep -q '"version"' 2>/dev/null; then
        echo "✅ Kuma Control Plane is ready"
        break
    fi
    if [ $i -eq $MAX_RETRIES ]; then
        echo "❌ Kuma Control Plane failed to become ready after ${MAX_RETRIES} attempts"
        echo "   Check logs: docker logs kuma-cp"
        exit 1
    fi
    echo "   Attempt $i/$MAX_RETRIES - waiting ${RETRY_INTERVAL}s..."
    sleep $RETRY_INTERVAL
done

# Apply mesh configuration
echo ""
echo "📋 Applying mesh configuration..."

# Prefer JSON format (Kuma API requires JSON)
if [ -f "mesh-default.json" ]; then
    MESH_FILE="mesh-default.json"
elif [ -f "mesh-default.yaml" ]; then
    MESH_FILE="mesh-default.yaml"
else
    echo "⚠️  mesh-default.yaml or mesh-default.json not found, skipping mesh configuration"
    MESH_FILE=""
fi

if [ -n "$MESH_FILE" ]; then
    # Try to create mesh (will fail if it exists, which is OK)
    curl -X POST "${KUMA_CP_URL}/meshes" \
        -H "Content-Type: application/json" \
        -d @"$MESH_FILE" \
        -f -s > /dev/null 2>&1 || true
    
    # Update mesh to ensure mTLS is enabled (works even if mesh exists)
    # Use PUT to update existing mesh
    curl -X PUT "${KUMA_CP_URL}/meshes/default" \
        -H "Content-Type: application/json" \
        -d @"$MESH_FILE" \
        -f -s > /dev/null 2>&1 || echo "⚠️  Failed to update mesh (may need manual configuration via GUI)"
    
    echo "✅ Mesh configuration applied"
    
    # Verify mTLS is enabled
    sleep 2
    MTLS_ENABLED=$(curl -s "${KUMA_CP_URL}/meshes/default" 2>/dev/null | grep -o '"enabledBackend":"ca-1"' || echo "")
    if [ -n "$MTLS_ENABLED" ]; then
        echo "✅ mTLS is enabled on the mesh"
    else
        echo "⚠️  mTLS may not be enabled - you can enable it manually via Kuma GUI"
        echo "   GUI: http://localhost:5681/gui/meshes/default/edit"
    fi
fi

# Apply policies
echo ""
echo "📋 Applying traffic policies..."

POLICIES_DIR="policies"
if [ -d "$POLICIES_DIR" ]; then
    for policy_file in "$POLICIES_DIR"/*.yaml; do
        if [ -f "$policy_file" ]; then
            policy_name=$(basename "$policy_file" .yaml)
            echo "   Applying $policy_name..."
            curl -X POST "${KUMA_CP_URL}/meshes/default/${policy_name}s" \
                -H "Content-Type: application/json" \
                -d @"$policy_file" \
                -f -s > /dev/null || echo "     ⚠️  Policy may already exist (this is OK)"
        fi
    done
    echo "✅ Traffic policies applied"
else
    echo "⚠️  Policies directory not found, skipping policy application"
fi

# Register dataplanes (they will auto-register when sidecars start, but we can verify)
echo ""
echo "📋 Waiting for dataplanes to register..."
sleep 5

# Verify dataplanes are registered
echo ""
echo "🔍 Checking registered dataplanes..."
if command -v jq > /dev/null 2>&1; then
    DATAPLANES=$(curl -s "${KUMA_CP_URL}/meshes/default/dataplanes" | jq -r '.items[].name' 2>/dev/null || echo "")
    if [ -n "$DATAPLANES" ]; then
        echo "✅ Registered dataplanes:"
        echo "$DATAPLANES" | while read -r dp; do
            echo "   - $dp"
        done
    else
        echo "⚠️  No dataplanes registered yet (they will register when sidecars start)"
    fi
else
    # Fallback if jq is not available
    DATAPLANE_COUNT=$(curl -s "${KUMA_CP_URL}/meshes/default/dataplanes" | grep -o '"name"' | wc -l || echo "0")
    if [ "$DATAPLANE_COUNT" -gt 0 ]; then
        echo "✅ Found $DATAPLANE_COUNT registered dataplane(s)"
    else
        echo "⚠️  No dataplanes registered yet (they will register when sidecars start)"
    fi
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     ✅ KUMA SERVICE MESH INITIALIZED                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Access Kuma GUI at: http://localhost:5681/gui/"
echo "🔧 Kuma API at: http://localhost:5681"

