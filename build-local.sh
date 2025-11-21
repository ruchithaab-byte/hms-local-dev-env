#!/bin/bash
# Build All Script - Local CI Pipeline Simulation
# This script builds the platform libraries and distributes them to all services
# before starting the Docker stack. Ensures consistency across the entire platform.

set -e # Stop on error

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     🏗️  BUILDING PLATFORM LIBRARIES                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Build Platform Libraries
PLATFORM_LIBS_DIR="../hms-platform-libraries"

if [ ! -d "$PLATFORM_LIBS_DIR" ]; then
    echo "❌ Platform libraries directory not found: $PLATFORM_LIBS_DIR"
    echo "   Please ensure hms-platform-libraries is cloned as a sibling to hms-local-dev-env"
    exit 1
fi

cd "$PLATFORM_LIBS_DIR"
echo "📦 Building hms-common-lib..."
mvn clean install -DskipTests
cd - > /dev/null

echo ""
echo "✅ Platform libraries built successfully"
echo ""

# Step 2: Distribute Libraries to Services
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     📦 DISTRIBUTING LIBRARIES TO SERVICES                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

COMMON_LIB_JAR="$PLATFORM_LIBS_DIR/hms-common-lib/target/hms-common-lib-1.0.0-SNAPSHOT.jar"
COMMON_LIB_POM="$HOME/.m2/repository/com/hms/platform/hms-common-lib/1.0.0-SNAPSHOT/hms-common-lib-1.0.0-SNAPSHOT.pom"
PARENT_POM="$HOME/.m2/repository/com/hms/platform/hms-platform-libraries/1.0.0-SNAPSHOT/hms-platform-libraries-1.0.0-SNAPSHOT.pom"

if [ ! -f "$COMMON_LIB_JAR" ]; then
    echo "❌ Common library JAR not found: $COMMON_LIB_JAR"
    exit 1
fi

# Define services that depend on the common library
SERVICES=("hms-auth-bff" "hms-onboarding-workflow")

for SERVICE in "${SERVICES[@]}"; do
    SERVICE_DIR="../$SERVICE"
    
    if [ -d "$SERVICE_DIR" ]; then
        echo "   📋 Copying libraries to $SERVICE..."
        mkdir -p "$SERVICE_DIR/libs"
        
        # Copy JAR
        cp "$COMMON_LIB_JAR" "$SERVICE_DIR/libs/"
        
        # Copy POMs (if available from Maven repo)
        if [ -f "$COMMON_LIB_POM" ]; then
            cp "$COMMON_LIB_POM" "$SERVICE_DIR/libs/"
        fi
        if [ -f "$PARENT_POM" ]; then
            cp "$PARENT_POM" "$SERVICE_DIR/libs/"
        fi
        
        echo "      ✅ $SERVICE/lib/ prepared"
    else
        echo "   ⚠️  Warning: $SERVICE directory not found. Skipping."
    fi
done

# Step 3: Copy API Contracts (for OpenAPI code generation)
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     📄 COPYING API CONTRACTS                                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

API_CONTRACTS_DIR="../hms-api-contracts"
API_SPEC="$API_CONTRACTS_DIR/openapi/workflow-service/v1/api.yaml"

# Always create api-contracts directories (even if empty) so Docker COPY doesn't fail
if [ -d "../hms-auth-bff" ]; then
    mkdir -p "../hms-auth-bff/api-contracts"
    touch "../hms-auth-bff/api-contracts/.gitkeep"
fi

if [ -d "../hms-onboarding-workflow" ]; then
    mkdir -p "../hms-onboarding-workflow/api-contracts"
    touch "../hms-onboarding-workflow/api-contracts/.gitkeep"
fi

if [ -f "$API_SPEC" ]; then
    echo "   📋 Copying API contracts to services..."
    
    # Copy to BFF (for Feign client generation)
    if [ -d "../hms-auth-bff" ]; then
        mkdir -p "../hms-auth-bff/api-contracts/openapi/workflow-service/v1"
        cp "$API_SPEC" "../hms-auth-bff/api-contracts/openapi/workflow-service/v1/api.yaml"
        echo "      ✅ hms-auth-bff/api-contracts/ prepared"
    fi
    
    # Copy to Workflow (for server interface generation)
    if [ -d "../hms-onboarding-workflow" ]; then
        mkdir -p "../hms-onboarding-workflow/api-contracts/openapi/workflow-service/v1"
        cp "$API_SPEC" "../hms-onboarding-workflow/api-contracts/openapi/workflow-service/v1/api.yaml"
        echo "      ✅ hms-onboarding-workflow/api-contracts/ prepared"
    fi
else
    echo "   ⚠️  Warning: API contracts not found at: $API_SPEC"
    echo "      OpenAPI code generation may fail. Ensure hms-api-contracts is cloned."
    echo "      Created empty api-contracts/ directories for Docker build."
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     ✅ BUILD CONTEXT PREPARED                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "🚀 Ready to start Docker stack. Run:"
echo "   docker-compose up -d --build"
echo ""
echo "   Or use the startup script:"
echo "   ./start-service-and-ngrok.sh"
echo ""

