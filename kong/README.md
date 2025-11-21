# Kong Gateway Configuration

## Overview

Kong Gateway serves as the **API Gateway** (Ingress Layer) for the HMS platform. It provides:

- **Unified Entry Point**: All API traffic flows through `http://localhost:8000`
- **Request Routing**: Routes requests to appropriate microservices
- **Rate Limiting**: Protects services from abuse
- **CORS Handling**: Manages cross-origin requests for the BFF
- **Service Decoupling**: Frontend only needs to know one URL, regardless of service topology

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (Next.js)                        │
│              Only knows: http://localhost:8000               │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Kong Gateway (Port 8000)                       │
│         ┌─────────────────────────────────────┐              │
│         │  Routing & Cross-Cutting Concerns  │              │
│         │  • CORS                             │              │
│         │  • Rate Limiting                    │              │
│         │  • Request Logging                 │              │
│         └─────────────────────────────────────┘              │
└───────────┬───────────────────────────────┬─────────────────┘
            │                               │
            ↓                               ↓
┌───────────────────────┐    ┌──────────────────────────────┐
│  hms-auth-bff:8080    │    │ hms-onboarding-workflow:8080  │
│  • /api/auth          │    │  • /api/v1/onboarding         │
│  • /api/webhooks      │    │  (Rate Limited: 100/min)      │
│  • /login             │    │                               │
│  • /oauth2            │    │                               │
└───────────────────────┘    └──────────────────────────────┘
```

**Key Benefit**: The frontend is **completely decoupled** from the service topology. Services can be moved, renamed, or scaled without any frontend code changes.

## Configuration

The gateway configuration is defined in `kong/kong.yml` using Kong's declarative (DB-less) mode.

### Services

1. **hms-auth-bff**: Public-facing authentication and user management
   - Routes: `/api/auth`, `/api/webhooks`, `/login`, `/oauth2`
   - CORS enabled for frontend integration

2. **hms-onboarding-workflow**: Internal orchestration service
   - Routes: `/api/v1/onboarding`
   - Rate limited: 100 requests/minute per IP

## Usage

### Starting the Stack

```bash
cd /Users/macbook/hms-local-dev-env
docker-compose up -d
```

**Note**: Kong will start after `hms-auth-bff` and `hms-onboarding-workflow` are ready due to `depends_on` configuration.

### Verifying Kong is Running

```bash
# Check Kong container status
docker-compose ps kong

# Check Kong health
curl http://localhost:8001/status

# Expected response: {"database":{"reachable":true},"server":{"connections_accepted":0,...}}
```

### Testing the Gateway Routing

#### ✅ **Correct Way (Through Kong Gateway)**

All frontend requests should go through Kong:

```bash
# BFF Authentication endpoints
curl http://localhost:8000/api/auth/login
curl http://localhost:8000/api/webhooks/scalekit
curl http://localhost:8000/login
curl http://localhost:8000/oauth2/callback

# Workflow Service endpoints
curl -X POST http://localhost:8000/api/v1/onboarding/start \
  -H "Content-Type: application/json" \
  -d '{"tenantName":"Acme Corp","adminEmail":"admin@acme.com"}'
```

#### ⚠️ **Direct Service Access (Debugging Only)**

Services are still accessible directly for debugging, but **should not be used by frontend**:

```bash
# Direct BFF access (for debugging)
curl http://localhost:8080/api/auth/login

# Direct Workflow access (for debugging)
curl http://localhost:8080/api/v1/onboarding/start
```

**Why This Matters**: 
- **Before Kong**: Frontend needs to know BFF is on `:8080` and Workflow is on `:8080` (different services, same port in Docker network)
- **After Kong**: Frontend only knows `localhost:8000`. Kong handles all routing internally.
- **Service Decoupling**: If you move `hms-onboarding-workflow` to port `8081` or rename it, **zero frontend changes needed**.

### Admin API

Kong Admin API is available at `http://localhost:8001` for debugging and management:

```bash
# List all registered services
curl http://localhost:8001/services | jq

# List all routes
curl http://localhost:8001/routes | jq

# Check Kong health and configuration
curl http://localhost:8001/status

# View Kong configuration (declarative mode)
curl http://localhost:8001/config
```

### Testing CORS (BFF Service)

The BFF service has CORS enabled via Kong. Test with:

```bash
curl -X OPTIONS http://localhost:8000/api/auth/login \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST" \
  -v
```

Expected headers in response:
- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS`
- `Access-Control-Allow-Headers: Authorization, Content-Type, X-Trace-Id`

### Testing Rate Limiting (Workflow Service)

The workflow service has rate limiting (100 requests/minute per IP):

```bash
# Make 101 rapid requests
for i in {1..101}; do
  curl -X POST http://localhost:8000/api/v1/onboarding/start \
    -H "Content-Type: application/json" \
    -d '{"tenantName":"Test","adminEmail":"test@example.com"}'
done

# Request 101 should return: 429 Too Many Requests
```

## Benefits

1. **Single Entry Point**: Frontend only needs to know `localhost:8000` - no need to track individual service ports
2. **Service Decoupling**: Services can be moved, renamed, or scaled without any frontend code changes
3. **Security**: Rate limiting and request validation at the edge before traffic reaches services
4. **Observability**: Centralized logging and request tracing at the gateway layer
5. **Zero Vendor Lock-in**: Open source, runs anywhere containers run (Docker, Kubernetes, ECS, etc.)
6. **CORS Management**: Centralized CORS configuration instead of per-service setup
7. **Future-Proof**: Easy to add authentication, API versioning, or service mesh features later

## Troubleshooting

### Kong Won't Start

```bash
# Check Kong logs
docker-compose logs kong

# Common issues:
# 1. Configuration syntax error in kong.yml
# 2. Services (hms-auth-bff, hms-onboarding-workflow) not ready
# 3. Port 8000 or 8001 already in use
```

### Routes Not Working

```bash
# Verify Kong can see the services
curl http://localhost:8001/services

# Verify routes are registered
curl http://localhost:8001/routes

# Check if services are reachable from Kong's network
docker-compose exec kong ping hms-auth-bff
docker-compose exec kong ping hms-onboarding-workflow
```

### 502 Bad Gateway

This usually means Kong can reach the service but the service isn't responding:

```bash
# Check if services are running
docker-compose ps

# Check service logs
docker-compose logs hms-auth-bff
docker-compose logs hms-onboarding-workflow

# Test direct service access
curl http://localhost:8080/actuator/health
```

### Rate Limiting Not Working

```bash
# Verify rate-limiting plugin is enabled
curl http://localhost:8001/services/hms-onboarding-workflow/plugins | jq

# Check plugin configuration
curl http://localhost:8001/plugins | jq '.[] | select(.name=="rate-limiting")'
```

## Frontend Integration

### Update Your Frontend Configuration

**Before (Direct Service Access):**
```typescript
// ❌ Old way - tightly coupled to service topology
const API_BASE_URL = 'http://localhost:8080'; // BFF
const WORKFLOW_URL = 'http://localhost:8080';  // Workflow (confusing!)
```

**After (Through Kong Gateway):**
```typescript
// ✅ New way - decoupled from service topology
const API_BASE_URL = 'http://localhost:8000'; // Single entry point

// All API calls go through Kong
fetch(`${API_BASE_URL}/api/auth/login`, {...});
fetch(`${API_BASE_URL}/api/v1/onboarding/start`, {...});
```

**Benefits:**
- Frontend doesn't need to know which service handles which endpoint
- Services can be moved/scaled without frontend changes
- Single CORS configuration
- Easier to add API versioning later

## Production Considerations

For production deployment:

1. **Domain Configuration**: Replace `localhost:8000` with your domain (e.g., `api.yourdomain.com`)
2. **JWT Plugin**: Configure Kong to validate ScaleKit tokens at the gateway layer
   ```yaml
   plugins:
     - name: jwt
       config:
         uri_param_names: ["token"]
         claims_to_verify: ["exp", "iss"]
   ```
3. **Enable Metrics**: Integrate with Prometheus/Grafana for observability
4. **Add WAF**: Deploy AWS ALB in front of Kong for DDoS protection and AWS WAF rules
5. **SSL/TLS**: Configure Kong to terminate HTTPS or use ALB for TLS termination
6. **High Availability**: Run multiple Kong instances behind a load balancer
7. **Configuration Management**: Use GitOps to manage `kong.yml` (already in place)
8. **Rate Limiting**: Adjust rate limits per tenant/organization using Kong's advanced rate limiting plugins

## Architecture Decision Record

**Decision**: Use Kong Gateway instead of AWS API Gateway

**Rationale**:
- **Container-Native**: Kong runs as a container, perfect for Docker/Kubernetes
- **Low Latency**: <1ms overhead vs 50-200ms for AWS API Gateway
- **Cost-Effective**: Fixed compute cost vs per-request pricing
- **Native JWT Support**: Built-in JWT plugin for ScaleKit token validation
- **GitOps-Friendly**: Declarative YAML configuration versioned in Git
- **Zero Vendor Lock-in**: Open source, runs anywhere

**Trade-offs**:
- Requires infrastructure management (vs fully managed AWS API Gateway)
- Need to handle scaling/HA ourselves (vs automatic scaling)

## Quick Reference

### Common Commands

```bash
# Start Kong and all services
docker-compose up -d

# Restart Kong only
docker-compose restart kong

# View Kong logs
docker-compose logs -f kong

# Test gateway routing
curl http://localhost:8000/api/auth/login

# Check Kong configuration
curl http://localhost:8001/config | jq

# Reload Kong configuration (if using DB mode)
curl -X POST http://localhost:8001/config?check_hash=1
```

### Service Endpoints Through Kong

| Endpoint | Service | Description |
|----------|---------|-------------|
| `http://localhost:8000/api/auth/*` | hms-auth-bff | Authentication APIs |
| `http://localhost:8000/api/webhooks/*` | hms-auth-bff | Webhook endpoints |
| `http://localhost:8000/login` | hms-auth-bff | OAuth login |
| `http://localhost:8000/oauth2/*` | hms-auth-bff | OAuth callbacks |
| `http://localhost:8000/api/v1/onboarding/*` | hms-onboarding-workflow | Workflow orchestration |

### Configuration Files

- **Kong Config**: `kong/kong.yml` - Declarative configuration
- **Docker Compose**: `docker-compose.yml` - Service definitions
- **Documentation**: `kong/README.md` - This file

