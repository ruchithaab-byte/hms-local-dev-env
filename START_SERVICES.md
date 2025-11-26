# Starting HMS Services - Step-by-Step Guide

## Prerequisites Check

### ✅ Completed
- [x] All environment variables configured in `.env`
- [x] Permit.io API key added
- [x] ScaleKit credentials configured
- [x] All code compiles successfully

### ⚠️ Required
- [ ] Docker Desktop is running
- [ ] Docker daemon is accessible

## Step-by-Step Startup Process

### Step 1: Start Docker Desktop

**On macOS:**
```bash
# Option 1: Open Docker Desktop application
open -a Docker

# Option 2: Start via command line (if installed)
docker info
```

**Wait for Docker to fully start** (you'll see the Docker icon in the menu bar turn green/stable).

### Step 2: Verify Docker is Running

```bash
cd /Users/macbook/hms-local-dev-env
docker --version
docker ps
```

Expected output: Should show Docker version and empty container list (or existing containers).

### Step 3: Start Services in Order

#### 3.1 Start Infrastructure Services First

```bash
docker-compose up -d postgres redis kuma-cp
```

**Wait 10-15 seconds** for these to become healthy:
```bash
docker-compose ps postgres redis kuma-cp
```

Look for `(healthy)` status.

#### 3.2 Start Permit.io PDP Containers

```bash
docker-compose up -d permit-pdp-kong permit-pdp-workflow permit-pdp-bff
```

**Wait 5 seconds** and verify:
```bash
docker-compose ps permit-pdp-kong permit-pdp-workflow permit-pdp-bff
```

#### 3.3 Start Application Services

```bash
docker-compose up -d hms-auth-bff
```

**Wait 30-60 seconds** for the Spring Boot application to start:
```bash
docker-compose logs -f hms-auth-bff
```

Look for: `Started ServicenameApplication` in the logs.

### Step 4: Verify All Services Are Running

```bash
docker-compose ps
```

**Expected Status:**
- `postgres`: `Up (healthy)`
- `redis`: `Up (healthy)`
- `kuma-cp`: `Up`
- `permit-pdp-kong`: `Up (healthy)`
- `permit-pdp-workflow`: `Up (healthy)`
- `permit-pdp-bff`: `Up (healthy)`
- `hms-auth-bff`: `Up (healthy)` or `Up`

### Step 5: Check Application Logs

```bash
# Check for Permit.io initialization
docker-compose logs hms-auth-bff | grep -i "permit"

# Check for ScaleKit initialization
docker-compose logs hms-auth-bff | grep -i "scalekit"

# Check for errors
docker-compose logs hms-auth-bff | grep -i "error\|exception"
```

**Expected Log Messages:**
- ✅ `Permit.io PermissionService initialized successfully`
- ✅ `PermitSyncService initialized successfully`
- ✅ `ScaleKit client initialized` (or similar)

### Step 6: Test Health Endpoint

```bash
curl http://localhost:8080/actuator/health
```

**Expected Response:**
```json
{
  "status": "UP",
  "components": {
    "db": {"status": "UP"},
    "redis": {"status": "UP"}
  }
}
```

### Step 7: Test Permit.io Integration

Check if Permit.io services are accessible from the container:

```bash
# Test PDP connectivity
docker exec hms-auth-bff curl -s http://permit-pdp-bff:7000/health || echo "PDP not accessible"
```

## Quick Start Script

Use the provided script for automated startup:

```bash
cd /Users/macbook/hms-local-dev-env
chmod +x start-services.sh
./start-services.sh
```

## Troubleshooting

### Issue: "Cannot connect to Docker daemon"

**Solution:**
1. Open Docker Desktop application
2. Wait for it to fully start (green icon in menu bar)
3. Try `docker ps` to verify

### Issue: "Service unhealthy"

**Solution:**
1. Check logs: `docker-compose logs <service-name>`
2. Check if dependencies are running
3. Restart the service: `docker-compose restart <service-name>`

### Issue: "hms-auth-bff fails to start"

**Common Causes:**
1. **Database not ready**: Wait longer, then restart BFF
2. **Permit.io connection failed**: Check `PERMIT_API_KEY` in `.env`
3. **ScaleKit connection failed**: Check ScaleKit credentials in `.env`

**Debug:**
```bash
docker-compose logs hms-auth-bff | tail -100
```

### Issue: "Port already in use"

**Solution:**
```bash
# Find what's using the port
lsof -i :8080

# Stop conflicting service or change port in docker-compose.yml
```

## Next Steps After Services Start

1. ✅ Verify all services are running
2. ✅ Test health endpoints
3. ✅ Check logs for initialization success
4. ✅ Test user creation API: `POST /api/admin/organizations`
5. ✅ Test permission checks: `POST /api/v1/onboarding/start`

## Service URLs

Once running, services are accessible at:

- **hms-auth-bff**: http://localhost:8080
- **Health Check**: http://localhost:8080/actuator/health
- **Kong Gateway**: http://localhost:8000 (if configured)
- **Kuma Control Plane**: http://localhost:5681/gui/

## Monitoring

Watch logs in real-time:
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f hms-auth-bff

# Filter for errors
docker-compose logs -f hms-auth-bff | grep -i error
```

