# Startup Script Comparison

## Two Scripts Available

### 1. `./start-service-and-ngrok.sh` ⭐ **RECOMMENDED**

**This is the comprehensive script you should use!**

**What it does:**
- ✅ Starts all infrastructure (Postgres, Redis, Kafka, Zookeeper)
- ✅ Starts Kuma Service Mesh Control Plane
- ✅ Initializes Kuma mesh configuration
- ✅ Builds and starts microservices (BFF, Workflow)
- ✅ Starts Kuma sidecars for mTLS
- ✅ Starts Kong Gateway (API Gateway)
- ✅ Starts **Permit.io PDP containers** (NEW - just added)
- ✅ Starts ngrok tunnel for public webhook URLs
- ✅ Provides ScaleKit webhook URL configuration
- ✅ Verifies all services are running
- ✅ Shows comprehensive status and URLs

**Use this when:**
- You need the full stack (Kong + Kuma + ngrok)
- You need public webhook URLs for ScaleKit
- You want everything automated in one command

**Command:**
```bash
cd /Users/macbook/hms-local-dev-env
./start-service-and-ngrok.sh
```

### 2. `./start-services.sh` (Simplified)

**What it does:**
- ✅ Starts infrastructure (Postgres, Redis, Kuma)
- ✅ Starts Permit.io PDP containers
- ✅ Starts hms-auth-bff service
- ❌ Does NOT start Kong Gateway
- ❌ Does NOT start ngrok
- ❌ Does NOT build services
- ❌ Does NOT initialize Kuma mesh

**Use this when:**
- You only need basic services running
- You don't need public webhook URLs
- You're testing locally without Kong/ngrok

**Command:**
```bash
cd /Users/macbook/hms-local-dev-env
./start-services.sh
```

## Recommendation

**Use `./start-service-and-ngrok.sh`** - It's the complete solution that includes:
- All infrastructure
- Kong Gateway (for ingress)
- Kuma Mesh (for service-to-service mTLS)
- Permit.io PDPs (for authorization)
- ngrok (for public webhook URLs)

## What Was Updated

The `start-service-and-ngrok.sh` script has been enhanced with:

1. ✅ **Environment verification** - Checks for Permit.io credentials
2. ✅ **Permit.io PDP startup** - Starts all 3 PDP containers
3. ✅ **PDP health checks** - Verifies PDPs are running
4. ✅ **Permit.io initialization check** - Verifies SDK initialization in logs
5. ✅ **Authorization status** - Shows Permit.io integration status

## Quick Start

```bash
cd /Users/macbook/hms-local-dev-env

# Make sure Docker is running
docker ps

# Start everything (recommended)
./start-service-and-ngrok.sh
```

## Expected Output

When `start-service-and-ngrok.sh` completes, you'll see:

```
✅ Docker is running
✅ ngrok is authenticated
✅ Permit.io API key configured
✅ Permit.io environment configured
✅ PostgreSQL is ready
✅ Redis is ready
✅ Kuma Control Plane is ready
✅ All Permit.io PDP containers are running
✅ BFF service is running
✅ Kong Gateway is healthy
✅ Permit.io services initialized
🌐 NGROK PUBLIC URL: https://xxxx-xx-xx-xx-xx.ngrok-free.app
📝 USE THIS IN SCALEKIT (Webhook Endpoint): https://xxxx-xx-xx-xx-xx.ngrok-free.app/api/webhooks/scalekit
```

## Summary

- **Use `./start-service-and-ngrok.sh`** for full stack with webhooks
- **Use `./start-services.sh`** for minimal local testing
- Both scripts now include Permit.io PDP support

