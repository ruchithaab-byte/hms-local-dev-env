# ⚡ Quick Start Reference

## One-Command Startup

```bash
cd /Users/macbook/hms-local-dev-env
./start-service-and-ngrok.sh
```

---

## Manual Process (3 Steps)

### 1️⃣ Build Platform Libraries
```bash
cd /Users/macbook/hms-platform-libraries
mvn clean install -DskipTests
```

### 2️⃣ Prepare Build Context
```bash
cd /Users/macbook/hms-local-dev-env
./build-local.sh
```

### 3️⃣ Start Everything
```bash
docker-compose up -d --build
```

---

## What Gets Built?

| Step | What Happens | Where |
|------|-------------|-------|
| **mvn install** (Platform) | Compiles `hms-common-lib` | `~/.m2/repository/` |
| **build-local.sh** | Copies JARs to services | `*/libs/` |
| **docker-compose build** | Runs `mvn package` inside Docker | Creates Docker images |

---

## Service Startup Order

```
1. Infrastructure (Postgres, Redis, Kafka)
   ↓
2. Kuma Control Plane
   ↓
3. Generate Kuma Tokens
   ↓
4. Application Services (BFF, Workflow)
   ↓
5. Kuma Sidecars
   ↓
6. Kong Gateway
```

---

## Verify Everything Works

```bash
# Check all services
docker-compose ps

# Test BFF
curl http://localhost:8000/api/auth/actuator/health

# Test Workflow
curl http://localhost:8000/api/v1/onboarding/actuator/health

# View Kuma GUI
open http://localhost:5681/gui/
```

---

## Common Issues

| Problem | Solution |
|---------|----------|
| "Cannot find hms-common-lib" | Run `mvn install` in `hms-platform-libraries` |
| "Database does not exist" | Check `postgres/init/01-create-databases.sql` |
| "Port already in use" | `lsof -i :8080` to find what's using it |
| "Sidecar not connecting" | Regenerate tokens: `cd kuma && ./generate-tokens-kumactl.sh` |

---

**📖 Full Guide:** See [STARTUP_GUIDE.md](./STARTUP_GUIDE.md) for detailed instructions.

