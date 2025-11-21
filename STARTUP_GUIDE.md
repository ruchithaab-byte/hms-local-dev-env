# 🚀 HMS Platform Startup Guide

Complete step-by-step instructions for starting all HMS services in Docker.

---

## 📋 Prerequisites

Before starting, ensure you have:

1. **Docker Desktop** running (check: `docker ps`)
2. **Java 17+** installed (`java -version`)
3. **Maven 3.9+** installed (`mvn -version`)
4. **All repositories cloned** as siblings:
   ```
   ~/workspace/
   ├── hms-platform-libraries/
   ├── hms-auth-bff/
   ├── hms-onboarding-workflow/
   ├── hms-api-contracts/
   └── hms-local-dev-env/  ← You are here
   ```

---

## 🎯 Quick Start (Automated)

**For experienced users - one command to start everything:**

```bash
cd /Users/macbook/hms-local-dev-env
./start-service-and-ngrok.sh
```

This script will:
1. ✅ Build platform libraries
2. ✅ Copy dependencies to services
3. ✅ Start all Docker containers
4. ✅ Initialize Kuma service mesh
5. ✅ Start ngrok tunnel

**Skip to [Verification](#-verification) section below.**

---

## 📖 Manual Step-by-Step Process

Follow these steps to understand what happens behind the scenes:

### Step 1: Build Platform Libraries

The `hms-common-lib` must be built and installed to your local Maven repository before services can use it.

```bash
# Navigate to platform libraries
cd /Users/macbook/hms-platform-libraries

# Build and install to local Maven repo (~/.m2/repository)
mvn clean install -DskipTests
```

**Expected output:**
```
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
```

**What this does:**
- Compiles `hms-common-lib` (context propagation, security, audit, etc.)
- Installs JAR to `~/.m2/repository/com/hms/platform/hms-common-lib/1.0.0-SNAPSHOT/`
- Makes it available for other services to import

---

### Step 2: Prepare Build Context

This step copies the built libraries and API contracts into each service's directory so Docker can access them during the build.

```bash
# Navigate to local dev environment
cd /Users/macbook/hms-local-dev-env

# Run the build preparation script
./build-local.sh
```

**What this script does:**
1. ✅ Verifies `hms-common-lib` was built
2. ✅ Copies JAR to `hms-auth-bff/libs/` and `hms-onboarding-workflow/libs/`
3. ✅ Copies API contracts to `*/api-contracts/` for OpenAPI code generation
4. ✅ Creates necessary directories

**Expected output:**
```
╔══════════════════════════════════════════════════════════════╗
║     🏗️  BUILDING PLATFORM LIBRARIES                          ║
╚══════════════════════════════════════════════════════════════╝

📦 Building hms-common-lib...
✅ Platform libraries built successfully

╔══════════════════════════════════════════════════════════════╗
║     📦 DISTRIBUTING LIBRARIES TO SERVICES                    ║
╚══════════════════════════════════════════════════════════════╝

   📋 Copying libraries to hms-auth-bff...
      ✅ hms-auth-bff/lib/ prepared
   📋 Copying libraries to hms-onboarding-workflow...
      ✅ hms-onboarding-workflow/lib/ prepared

╔══════════════════════════════════════════════════════════════╗
║     📄 COPYING API CONTRACTS                                  ║
╚══════════════════════════════════════════════════════════════╝

   📋 Copying API contracts to services...
      ✅ hms-auth-bff/api-contracts/ prepared
      ✅ hms-onboarding-workflow/api-contracts/ prepared
```

---

### Step 3: Start Infrastructure Services

Start the foundational services (database, cache, message queue) first:

```bash
cd /Users/macbook/hms-local-dev-env

# Start infrastructure
docker-compose up -d postgres redis zookeeper kafka

# Wait for them to be healthy
sleep 10
```

**What starts:**
- **Postgres** (port 5432): Databases for BFF, Workflow, Projector
- **Redis** (port 6379): Session storage
- **Zookeeper** (port 2181): Kafka coordination
- **Kafka** (port 9093): Message queue

**Verify:**
```bash
docker-compose ps
```

You should see all 4 services with status "Up".

---

### Step 4: Start Kuma Service Mesh

Kuma provides mTLS, retries, circuit breaking, and observability:

```bash
# Start Kuma Control Plane
docker-compose up -d kuma-cp

# Wait for it to be ready
sleep 10

# Initialize mesh configuration
cd kuma
./init-kuma.sh
cd ..
```

**What this does:**
- Starts Kuma Control Plane (port 5681 for API/GUI, 5678 for dataplane connections)
- Creates the `default` mesh
- Applies traffic policies (retry, circuit breaker, timeout, tracing)

**Verify:**
```bash
# Check Kuma GUI
open http://localhost:5681/gui/

# Or check API
curl http://localhost:5681/
```

---

### Step 5: Generate Kuma Dataplane Tokens

Each service sidecar needs a token to authenticate with Kuma CP:

```bash
cd /Users/macbook/hms-local-dev-env/kuma

# Generate tokens for all services
./generate-tokens-kumactl.sh
```

**What this does:**
- Retrieves admin token from Kuma CP
- Generates dataplane tokens for:
  - `hms-auth-bff`
  - `hms-onboarding-workflow`
  - `hms-dashboard-projector`
- Saves tokens to `kuma/tokens/`

**Expected output:**
```
╔══════════════════════════════════════════════════════════════╗
║     🔑 GENERATING KUMA DATAPLANE TOKENS (kumactl)            ║
╚══════════════════════════════════════════════════════════════╝

🔐 Retrieving admin token from Kuma CP...
⚙️  Configuring kumactl with admin token...
✅ Connected to Kuma CP (authenticated)

🔑 Generating token for hms-auth-bff...
   ✅ Token saved to tokens/hms-auth-bff-token
🔑 Generating token for hms-onboarding-workflow...
   ✅ Token saved to tokens/hms-onboarding-workflow-token
🔑 Generating token for hms-dashboard-projector...
   ✅ Token saved to tokens/hms-dashboard-projector-token
```

---

### Step 6: Build and Start Application Services

Now build and start the Java microservices:

```bash
cd /Users/macbook/hms-local-dev-env

# Build and start services (this will run mvn install inside Docker)
docker-compose up -d --build hms-auth-bff hms-onboarding-workflow
```

**What happens during `--build`:**
1. Docker reads each service's `Dockerfile`
2. Copies `libs/` and `api-contracts/` into the build context
3. Runs `mvn install:install-file` to install local dependencies
4. Runs `mvn clean package -DskipTests` to build the service
5. Creates a Docker image with the compiled service
6. Starts the container

**This is equivalent to:**
```bash
# For each service (hms-auth-bff, hms-onboarding-workflow):
cd ../hms-auth-bff
mvn clean install -DskipTests  # Builds the service
# Then Docker packages it into an image
```

**Wait for services to start:**
```bash
# Watch logs
docker-compose logs -f hms-auth-bff hms-onboarding-workflow

# Or check status
docker-compose ps
```

Look for:
- ✅ `Started ServicenameApplication` in logs
- ✅ Status "Up" in `docker-compose ps`

---

### Step 7: Start Kuma Sidecars

Start the service mesh sidecars for each service:

```bash
docker-compose up -d hms-auth-bff-sidecar hms-onboarding-workflow-sidecar
```

**What this does:**
- Starts Envoy proxy sidecars
- Connects to Kuma CP using the generated tokens
- Enables mTLS, retries, circuit breaking for service-to-service traffic

**Verify sidecars are connected:**
```bash
# Check Kuma GUI
open http://localhost:5681/gui/

# Navigate to: Meshes → default → Dataplanes
# You should see hms-auth-bff and hms-onboarding-workflow listed
```

---

### Step 8: Start Kong API Gateway

Kong provides unified entry point, routing, and rate limiting:

```bash
docker-compose up -d kong
```

**What this does:**
- Starts Kong Gateway (port 8000 for traffic, 8001 for admin API)
- Loads routes from `kong/kong.yml`
- Routes `/api/auth/*` → `hms-auth-bff`
- Routes `/api/v1/onboarding/*` → `hms-onboarding-workflow`

**Verify:**
```bash
# Check Kong health
curl http://localhost:8001/status

# Test routing
curl http://localhost:8000/api/auth/actuator/health
```

---

### Step 9: Start ngrok (Optional - for Webhooks)

If you need to expose services to the internet (e.g., for ScaleKit webhooks):

```bash
# Kill any existing ngrok
pkill -f "[n]grok http" 2>/dev/null || true

# Start ngrok pointing to Kong
ngrok http 8000 --log=stdout > /tmp/ngrok.log 2>&1 &

# Get the public URL
sleep 5
curl -s http://localhost:4040/api/tunnels | \
  python3 -c "import sys, json; data = json.load(sys.stdin); \
  tunnels = data.get('tunnels', []); \
  https_tunnel = next((t for t in tunnels if 'https://' in t.get('public_url', '')), None); \
  print(https_tunnel['public_url'] if https_tunnel else 'Not ready yet')"
```

**Expected output:**
```
https://abc123.ngrok-free.app
```

Use this URL in ScaleKit dashboard for webhook endpoints.

---

## ✅ Verification

### Check All Services Are Running

```bash
cd /Users/macbook/hms-local-dev-env
docker-compose ps
```

**Expected output:**
```
NAME                              STATUS
postgres                          Up
redis                             Up
zookeeper                         Up
kafka                             Up
kuma-cp                           Up
hms-auth-bff                      Up
hms-auth-bff-sidecar              Up
hms-onboarding-workflow           Up
hms-onboarding-workflow-sidecar   Up
kong                              Up
```

### Test Service Health

```bash
# BFF via Kong
curl http://localhost:8000/api/auth/actuator/health

# Workflow via Kong
curl http://localhost:8000/api/v1/onboarding/actuator/health

# Direct access (bypassing Kong)
curl http://localhost:8080/actuator/health  # BFF
```

**Expected response:**
```json
{"status":"UP"}
```

### Check Kuma Service Mesh

```bash
# Open Kuma GUI
open http://localhost:5681/gui/

# Or check via API
curl http://localhost:5681/meshes/default/dataplanes
```

You should see dataplanes registered for your services.

### Check Kong Gateway

```bash
# Kong Admin API
curl http://localhost:8001/services

# Kong routes
curl http://localhost:8001/routes
```

---

## 🔧 Troubleshooting

### Issue: "Cannot find artifact hms-common-lib"

**Solution:**
```bash
# Rebuild platform libraries
cd /Users/macbook/hms-platform-libraries
mvn clean install -DskipTests

# Re-run build preparation
cd /Users/macbook/hms-local-dev-env
./build-local.sh

# Rebuild Docker images
docker-compose build --no-cache hms-auth-bff hms-onboarding-workflow
docker-compose up -d hms-auth-bff hms-onboarding-workflow
```

### Issue: "Database does not exist"

**Solution:**
```bash
# Check if databases were created
docker exec postgres psql -U postgres -l

# If missing, create manually
docker exec postgres psql -U postgres -c "CREATE DATABASE bff_db;"
docker exec postgres psql -U postgres -c "CREATE DATABASE workflow_db;"
docker exec postgres psql -U postgres -c "CREATE DATABASE projector_db;"
```

### Issue: "Service won't start"

**Solution:**
```bash
# Check logs
docker-compose logs hms-auth-bff
docker-compose logs hms-onboarding-workflow

# Check if dependencies are healthy
docker-compose ps postgres redis kafka

# Restart service
docker-compose restart hms-auth-bff
```

### Issue: "Kuma sidecar not connecting"

**Solution:**
```bash
# Regenerate tokens
cd /Users/macbook/hms-local-dev-env/kuma
./generate-tokens-kumactl.sh

# Restart sidecars
cd ..
docker-compose restart hms-auth-bff-sidecar hms-onboarding-workflow-sidecar

# Check sidecar logs
docker-compose logs hms-auth-bff-sidecar
```

### Issue: "Port already in use"

**Solution:**
```bash
# Find what's using the port
lsof -i :8080
lsof -i :8000
lsof -i :5432

# Stop conflicting services or change ports in docker-compose.yml
```

---

## 🛑 Stopping Services

### Stop Everything

```bash
cd /Users/macbook/hms-local-dev-env

# Stop all containers
docker-compose down

# Stop ngrok
pkill -f "[n]grok http"
```

### Stop Specific Service

```bash
# Stop a service
docker-compose stop hms-auth-bff

# Stop and remove
docker-compose rm -f hms-auth-bff
```

### Clean Everything (Nuclear Option)

```bash
# Stop and remove all containers, networks, volumes
docker-compose down -v

# Remove all images
docker-compose down --rmi all
```

---

## 📊 Service Ports Reference

| Service | Port | Purpose |
|---------|------|---------|
| **Kong Gateway** | 8000 | Public API entry point |
| **Kong Admin** | 8001 | Kong management API |
| **BFF** | 8080 | Direct access (bypass Kong) |
| **Workflow** | 8081 | Direct access (bypass Kong) |
| **Postgres** | 5432 | Database |
| **Redis** | 6379 | Cache/Sessions |
| **Kafka** | 9093 | Message queue |
| **Kuma CP API** | 5681 | Service mesh API/GUI |
| **Kuma CP DP** | 5678 | Dataplane connections |
| **ngrok Dashboard** | 4040 | Tunnel management |

---

## 🎓 Understanding the Architecture

### Request Flow

```
User Request
    ↓
Kong Gateway (port 8000)
    ↓
Kuma Sidecar (mTLS, retries, circuit breaking)
    ↓
Spring Boot Service (port 8080)
    ↓
Database / Kafka / Other Services
```

### Build Process

```
1. Build hms-common-lib → ~/.m2/repository/
2. Copy JAR to service/libs/
3. Copy API contracts to service/api-contracts/
4. Docker build:
   a. Install local JARs into container Maven repo
   b. Generate OpenAPI code from contracts
   c. Run mvn package
   d. Create Docker image
5. Start container
```

---

## 📚 Next Steps

After all services are running:

1. **Test the API:**
   ```bash
   curl -X POST http://localhost:8000/api/auth/onboarding/start \
     -H "Content-Type: application/json" \
     -d '{"tenantName":"Acme Corp","adminEmail":"admin@acme.com"}'
   ```

2. **View Logs:**
   ```bash
   docker-compose logs -f hms-auth-bff
   ```

3. **Monitor Service Mesh:**
   - Open http://localhost:5681/gui/
   - View dataplanes, policies, metrics

4. **Configure ScaleKit:**
   - Use ngrok URL for webhook endpoints
   - Configure OAuth redirect URIs

---

## 💡 Tips

- **Always run `./build-local.sh`** after changing `hms-common-lib`
- **Check logs first** when services fail: `docker-compose logs <service>`
- **Use `docker-compose ps`** to see service status
- **Kuma GUI** is your friend for debugging service mesh issues
- **Kong Admin API** (port 8001) for routing debugging

---

**Need help?** Check logs, verify prerequisites, and ensure all repositories are cloned correctly.

