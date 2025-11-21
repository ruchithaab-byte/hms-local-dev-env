# Docker Build Dependency Solution

## Problem Statement

**Docker Context Isolation**: Docker containers are isolated from the host filesystem. When building services that depend on `hms-common-lib:1.0.0-SNAPSHOT` (a local SNAPSHOT artifact), Docker cannot access your Mac's `~/.m2/repository` where the library is installed.

## Solution Architecture

### The "Local CI" Pattern

We've implemented a **"Build All"** script (`build-local.sh`) that simulates a CI pipeline locally:

1. **Build Platform Libraries** → Compiles `hms-common-lib` and installs to local Maven repo
2. **Distribute Libraries** → Copies JAR and POMs to each service's `libs/` directory
3. **Copy API Contracts** → Copies OpenAPI specs to each service's `api-contracts/` directory
4. **Docker Build** → Docker can now `COPY` these files into the image and install them

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  build-local.sh (Local CI Pipeline)                         │
│                                                              │
│  1. Build hms-common-lib                                     │
│     → ~/.m2/repository/com/hms/platform/...                 │
│                                                              │
│  2. Copy to Service Contexts                                │
│     → hms-auth-bff/libs/hms-common-lib-1.0.0-SNAPSHOT.jar  │
│     → hms-onboarding-workflow/libs/...                      │
│                                                              │
│  3. Copy API Contracts                                      │
│     → hms-auth-bff/api-contracts/openapi/...                 │
│     → hms-onboarding-workflow/api-contracts/...              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Dockerfile (Inside Container)                              │
│                                                              │
│  1. COPY libs/ /tmp/libs/                                   │
│  2. mvn install:install-file (install to container's Maven)│
│  3. mvn dependency:go-offline (now finds the library!)      │
│  4. COPY api-contracts/ (for OpenAPI generation)            │
│  5. mvn clean package (build succeeds!)                    │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Quick Start

```bash
cd /Users/macbook/hms-local-dev-env

# Build libraries and prepare all services
./build-local.sh

# Start the stack
docker-compose up -d --build
```

### Or Use the Startup Script

The `start-service-and-ngrok.sh` script automatically calls `build-local.sh`:

```bash
./start-service-and-ngrok.sh
```

## File Structure

```
hms-local-dev-env/
├── build-local.sh              # Main build script (Local CI)
├── prepare-build-context.sh    # Legacy (replaced by build-local.sh)
└── start-service-and-ngrok.sh  # Startup script (calls build-local.sh)

hms-auth-bff/
├── libs/                       # Copied by build-local.sh (gitignored)
│   ├── hms-common-lib-1.0.0-SNAPSHOT.jar
│   ├── hms-common-lib-1.0.0-SNAPSHOT.pom
│   └── hms-platform-libraries-1.0.0-SNAPSHOT.pom
├── api-contracts/              # Copied by build-local.sh (gitignored)
│   └── openapi/workflow-service/v1/api.yaml
└── Dockerfile                  # Uses libs/ and api-contracts/

hms-onboarding-workflow/
├── libs/                       # Same structure
├── api-contracts/              # Same structure
└── Dockerfile                  # Same approach
```

## Key Components

### 1. build-local.sh

**Purpose**: Simulates a CI pipeline locally
- Builds platform libraries
- Distributes artifacts to services
- Copies API contracts
- Ensures consistency across the platform

**When to Run**:
- After changing `hms-common-lib`
- Before Docker builds
- When setting up a fresh environment

### 2. Dockerfile Updates

**Key Changes**:
```dockerfile
# Copy local dependencies
COPY libs/ /tmp/libs/

# Install to container's Maven repo
RUN --mount=type=cache,target=/root/.m2 \
    mvn install:install-file \
        -Dfile=/tmp/libs/hms-common-lib-1.0.0-SNAPSHOT.jar \
        -DpomFile=/tmp/libs/hms-common-lib-1.0.0-SNAPSHOT.pom \
        ...

# Copy API contracts
COPY api-contracts/ /build/api-contracts/
```

### 3. pom.xml Updates

**OpenAPI Generator Path**:
```xml
<!-- Before (outside Docker context) -->
<inputSpec>${project.basedir}/../hms-api-contracts/openapi/workflow-service/v1/api.yaml</inputSpec>

<!-- After (inside Docker context) -->
<inputSpec>${project.basedir}/api-contracts/openapi/workflow-service/v1/api.yaml</inputSpec>
```

## Benefits

✅ **Portable**: Works on any machine with the same folder structure  
✅ **Fast**: Uses BuildKit cache mounts for Maven dependencies  
✅ **Reliable**: No network dependencies for local SNAPSHOT artifacts  
✅ **Clean**: `libs/` and `api-contracts/` are gitignored  
✅ **Automated**: Single script handles everything  
✅ **CI-Ready**: Pattern can be replicated in actual CI/CD pipelines

## Troubleshooting

### "Common library not found"

```bash
# Ensure hms-platform-libraries is cloned
cd /Users/macbook
ls -d hms-platform-libraries

# Build it manually if needed
cd hms-platform-libraries
mvn clean install -DskipTests
```

### "API contracts not found"

```bash
# Ensure hms-api-contracts is cloned
cd /Users/macbook
ls -d hms-api-contracts

# The build will continue, but OpenAPI generation will fail
```

### "Docker build still fails"

1. Check that `build-local.sh` ran successfully
2. Verify files exist:
   ```bash
   ls -la ../hms-auth-bff/libs/
   ls -la ../hms-auth-bff/api-contracts/
   ```
3. Rebuild with verbose output:
   ```bash
   docker-compose build --no-cache hms-auth-bff
   ```

## Future Improvements

For production, consider:
1. **Publish to Maven Repository**: Deploy `hms-common-lib` to Nexus/Artifactory
2. **Docker Multi-Stage with Library**: Include library build in Dockerfile
3. **Private Docker Registry**: Push base images with libraries pre-installed
4. **Buildpacks**: Use Cloud Native Buildpacks for automatic dependency resolution

## Summary

This solution solves the **Docker Context Isolation** problem by:
1. **Preparing the build context** outside Docker (on the host)
2. **Copying artifacts** into the Docker build context
3. **Installing them** inside the container during build

This is a **standard pattern** used in CI/CD pipelines and ensures your local development workflow matches production.

