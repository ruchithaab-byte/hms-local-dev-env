# Build Requirements

## Prerequisites

Before building services with Docker, you must build and install the common library to your local Maven repository.

### Step 1: Build Common Library

```bash
cd /Users/macbook/hms-platform-libraries
mvn clean install -DskipTests
```

This installs `hms-common-lib:1.0.0-SNAPSHOT` to `~/.m2/repository/com/hms/platform/hms-common-lib/1.0.0-SNAPSHOT/`

### Step 2: Start Docker Stack (Automatic Build Context Preparation)

The startup script automatically prepares the build context:

```bash
cd /Users/macbook/hms-local-dev-env
./start-service-and-ngrok.sh
```

This script will:
1. ✅ Check Docker and ngrok
2. ✅ Build and install common library (if needed)
3. ✅ Run `prepare-build-context.sh` to copy common lib JAR to service `libs/` directories
4. ✅ Start infrastructure
5. ✅ Build and start services with Docker
6. ✅ Start Kong Gateway
7. ✅ Start ngrok tunnel

## How It Works

### Build Context Preparation

The `prepare-build-context.sh` script:
1. Locates the common library JAR in `~/.m2/repository`
2. Creates `libs/` directories in each service
3. Copies the JAR to `hms-auth-bff/libs/` and `hms-onboarding-workflow/libs/`
4. Ensures the directories exist for Docker COPY commands

### Docker Build Process

Each service's Dockerfile:
1. Copies `libs/` directory into the build container
2. Installs the common lib JAR to the container's Maven repository using `mvn install:install-file`
3. Resolves dependencies (now including `hms-common-lib`)
4. Builds the service JAR
5. Creates the final runtime image

### Benefits

✅ **Portable**: Works on any machine with the common lib installed  
✅ **Fast**: Uses BuildKit cache mounts for Maven dependencies  
✅ **Reliable**: No network dependencies for local SNAPSHOT artifacts  
✅ **Clean**: `libs/` directories are gitignored

## Manual Build Context Preparation

If you need to prepare the build context manually:

```bash
cd /Users/macbook/hms-local-dev-env
./prepare-build-context.sh
```

Then build services:

```bash
docker-compose build hms-auth-bff hms-onboarding-workflow
```

## Future Improvements

For production, consider:
1. Publishing `hms-common-lib` to a Maven repository (Nexus, Artifactory, or Maven Central)
2. Using a private Docker registry for base images
3. Implementing a proper artifact management strategy

## Port Conflicts

If you encounter port conflicts:
- **Kafka (9092)**: Changed to **9093** in `docker-compose.yml` to avoid conflicts
- Services inside Docker use `kafka:9092` (internal DNS)
- External connections use `localhost:9093`

