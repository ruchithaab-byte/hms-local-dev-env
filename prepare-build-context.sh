#!/bin/bash
# Prepare build context for services by copying common library JAR and POMs
# This script must be run before docker-compose build

set -e

COMMON_LIB_DIR="$HOME/.m2/repository/com/hms/platform/hms-common-lib/1.0.0-SNAPSHOT"
COMMON_LIB_JAR="$COMMON_LIB_DIR/hms-common-lib-1.0.0-SNAPSHOT.jar"
COMMON_LIB_POM="$COMMON_LIB_DIR/hms-common-lib-1.0.0-SNAPSHOT.pom"
PARENT_POM_DIR="$HOME/.m2/repository/com/hms/platform/hms-platform-libraries/1.0.0-SNAPSHOT"
PARENT_POM="$PARENT_POM_DIR/hms-platform-libraries-1.0.0-SNAPSHOT.pom"

BFF_LIBS_DIR="../hms-auth-bff/libs"
WORKFLOW_LIBS_DIR="../hms-onboarding-workflow/libs"

echo "🔧 Preparing build context for Docker builds..."

# Check if common lib exists
if [ ! -f "$COMMON_LIB_JAR" ]; then
    echo "❌ Common library JAR not found at: $COMMON_LIB_JAR"
    echo "   Please build it first:"
    echo "   cd /Users/macbook/hms-platform-libraries && mvn clean install -DskipTests"
    exit 1
fi

if [ ! -f "$COMMON_LIB_POM" ]; then
    echo "❌ Common library POM not found at: $COMMON_LIB_POM"
    exit 1
fi

if [ ! -f "$PARENT_POM" ]; then
    echo "❌ Parent POM not found at: $PARENT_POM"
    exit 1
fi

echo "✅ Found common library: $COMMON_LIB_JAR"
echo "✅ Found common library POM: $COMMON_LIB_POM"
echo "✅ Found parent POM: $PARENT_POM"

# Create libs directories
mkdir -p "$BFF_LIBS_DIR"
mkdir -p "$WORKFLOW_LIBS_DIR"

# Copy common lib JAR and POM to both services
cp "$COMMON_LIB_JAR" "$BFF_LIBS_DIR/"
cp "$COMMON_LIB_POM" "$BFF_LIBS_DIR/"
cp "$PARENT_POM" "$BFF_LIBS_DIR/"

# Also copy to workflow
cp "$COMMON_LIB_JAR" "$WORKFLOW_LIBS_DIR/"
cp "$COMMON_LIB_POM" "$WORKFLOW_LIBS_DIR/"
cp "$PARENT_POM" "$WORKFLOW_LIBS_DIR/"

# Copy API contracts for OpenAPI code generation
API_CONTRACTS_DIR="../hms-api-contracts"
API_SPEC="$API_CONTRACTS_DIR/openapi/workflow-service/v1/api.yaml"
BFF_CONTRACTS_DIR="../hms-auth-bff/api-contracts"

if [ -f "$API_SPEC" ]; then
    echo "✅ Found API contract: $API_SPEC"
    mkdir -p "$BFF_CONTRACTS_DIR/openapi/workflow-service/v1"
    cp "$API_SPEC" "$BFF_CONTRACTS_DIR/openapi/workflow-service/v1/api.yaml"
    echo "✅ Copied API contract to build context"
else
    echo "⚠️  API contract not found at: $API_SPEC"
    echo "   OpenAPI code generation will fail. Please ensure hms-api-contracts is cloned."
fi

# Create .gitkeep to ensure directory structure is preserved
touch "$BFF_LIBS_DIR/.gitkeep"
touch "$WORKFLOW_LIBS_DIR/.gitkeep"

echo ""
echo "✅ Copied common library artifacts to:"
echo "   - $BFF_LIBS_DIR/"
echo "   - $WORKFLOW_LIBS_DIR/"
echo ""
echo "✅ Build context prepared. You can now run: docker-compose build"
