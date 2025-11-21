# Kuma Service Mesh for HMS Platform

## 📋 Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Why Kuma?](#why-kuma)
- [Traffic Flow](#traffic-flow)
- [Configuration](#configuration)
- [Policies](#policies)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)

---

## 🎯 Overview

**Kuma** is the service mesh layer that handles **East-West** (service-to-service) traffic in the HMS platform. It works in conjunction with **Kong Gateway**, which handles **North-South** (external-to-service) traffic.

### Key Capabilities
- ✅ **mTLS (Mutual TLS)**: Zero-trust security for service-to-service communication
- ✅ **Traffic Management**: Automatic retries, circuit breaking, timeouts
- ✅ **Observability**: Distributed tracing, metrics, and logging
- ✅ **Context Propagation**: Preserves `x-hms-*` headers across service boundaries
- ✅ **Polyglot Support**: Works seamlessly with Java, Python, and Node.js services

---

## 🏗️ Architecture

### The "Gateway + Mesh" Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                    EXTERNAL USER                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              AWS ALB / Load Balancer                            │
│              (TLS Termination, WAF)                             │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    KONG GATEWAY                                 │
│  • Authentication (ScaleKit OIDC)                               │
│  • Rate Limiting (per IP/Tenant)                                │
│  • Routing (/api/auth → BFF, /api/v1 → Workflow)              │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    KUMA SERVICE MESH                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  hms-auth-bff                                             │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │ Kuma Sidecar │  │ Spring Boot  │  │   Postgres   │  │  │
│  │  │   (Envoy)    │◄─┤   Service    │  │   (Direct)   │  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                     │
│                            │ mTLS                                │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  hms-onboarding-workflow                                  │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │ Kuma Sidecar │  │ Spring Boot  │  │   Kafka     │  │  │
│  │  │   (Envoy)    │◄─┤   Service    │  │  (Direct)   │  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  • Automatic Retries (503 errors)                               │
│  • Circuit Breaking (prevent cascading failures)                 │
│  • Distributed Tracing (Zipkin)                                 │
│  • Context Header Propagation (x-hms-*)                         │
└─────────────────────────────────────────────────────────────────┘
```

### Component Roles

| Component | Role | Responsibility |
|-----------|------|----------------|
| **Kong Gateway** | Edge Gateway | North-South traffic, Auth, Rate Limiting |
| **Kuma Control Plane** | Mesh Orchestrator | Policy management, certificate authority |
| **Kuma Sidecar (Envoy)** | Data Plane | Traffic interception, mTLS, metrics |
| **Spring Boot Services** | Business Logic | Application code (unaware of mesh) |

---

## 🎯 Why Kuma?

### 1. **Synergy with Kong Gateway**
- Both use **Envoy** as the underlying proxy
- Unified data plane reduces operational complexity
- Similar YAML-based configuration style

### 2. **Kafka Protocol Support**
- Unlike Istio/Linkerd, Kuma can parse Kafka protocol
- Provides metrics on Kafka message consumption
- Better observability for event-driven architecture

### 3. **Polyglot Compatibility**
- Works transparently with Java, Python, Node.js
- No code changes required in application services
- Context propagation via standard HTTP headers

### 4. **Operational Simplicity**
- Easier to operate than Istio
- More powerful than Linkerd for hybrid environments
- Built-in GUI for policy management

---

## 🔄 Traffic Flow

### North-South (External → Service)
```
User → AWS ALB → Kong Gateway → Kuma Sidecar → Spring Boot Service
```

**Kong Responsibilities:**
- Validate JWT token (ScaleKit)
- Extract `org_id` for tenant resolution
- Rate limit per IP/tenant
- Route to correct service

**Kuma Responsibilities:**
- Upgrade connection to mTLS
- Inject tracing headers
- Apply traffic policies (retries, timeouts)

### East-West (Service → Service)
```
Service A → Kuma Sidecar A → mTLS → Kuma Sidecar B → Service B
```

**Kuma Responsibilities:**
- Encrypt all inter-service traffic (mTLS)
- Automatic retries on transient failures
- Circuit breaking to prevent cascading failures
- Preserve context headers (`x-hms-trace-id`, `x-hms-tenant-id`)

---

## ⚙️ Configuration

### Mesh Configuration (`mesh-default.yaml`)

The mesh is configured with:
- **mTLS**: Enabled in `permissive` mode (allows non-mesh traffic during migration)
- **Metrics**: Prometheus backend on port 5670
- **Tracing**: Zipkin backend (requires Zipkin service)
- **Logging**: File-based logging

### Dataplane Configuration

Each service has a dataplane configuration file in `dataplanes/`:

```yaml
type: Dataplane
mesh: default
name: hms-auth-bff
networking:
  address: 0.0.0.0
  inbound:
    - port: 8080
      servicePort: 8080
      serviceAddress: 127.0.0.1
      tags:
        kuma.io/service: hms-auth-bff
        kuma.io/protocol: http
  outbound:
    - port: 10001
      tags:
        kuma.io/service: hms-onboarding-workflow
```

**Key Points:**
- `inbound`: Defines how the service receives traffic
- `outbound`: Defines how the service reaches other services
- `serviceAddress: 127.0.0.1`: The sidecar proxies to localhost

---

## 📜 Policies

### 1. Retry Policy (`retry-policy.yaml`)
- Automatically retries failed requests (503 errors)
- Configurable retry count and backoff

### 2. Circuit Breaker (`circuit-breaker-policy.yaml`)
- Prevents cascading failures
- Opens circuit after threshold of failures
- Automatically attempts to close after timeout

### 3. Timeout Policy (`timeout-policy.yaml`)
- Enforces request and idle timeouts
- Prevents resource exhaustion

### 4. Traffic Trace Policy (`traffic-trace-policy.yaml`)
- Enables distributed tracing
- Sends spans to Zipkin backend
- Preserves trace context across services

### Applying Policies

Policies are automatically applied when you run `init-kuma.sh`:

```bash
cd kuma
./init-kuma.sh
```

Or manually via API:

```bash
curl -X POST http://localhost:5681/meshes/default/retries \
  -H "Content-Type: application/json" \
  -d @policies/retry-policy.yaml
```

---

## 🚀 Usage

### Starting the Stack

The startup script automatically:
1. Starts Kuma Control Plane
2. Initializes mesh configuration
3. Applies policies
4. Starts services with sidecars

```bash
cd hms-local-dev-env
./start-service-and-ngrok.sh
```

### Accessing Kuma GUI

Open your browser to:
```
http://localhost:5681/gui/
```

**Note:** The GUI is served through the API server on port 5681, not port 5683. Port 5683 is used for Inter-CP communication (TLS).

**Features:**
- View registered dataplanes
- Monitor traffic policies
- Inspect mTLS certificates
- View metrics and traces

### Verifying mTLS

Check if services are communicating via mTLS:

```bash
# List dataplanes
curl http://localhost:5681/meshes/default/dataplanes

# Check mesh status
curl http://localhost:5681/meshes/default
```

### Testing Service-to-Service Communication

```bash
# From BFF to Workflow (via Kuma mesh)
curl -X POST http://localhost:8000/api/auth/onboarding/start \
  -H "Content-Type: application/json" \
  -d '{"tenantName": "Acme Corp", "adminEmail": "admin@acme.com"}'
```

The request will:
1. Hit Kong Gateway (port 8000)
2. Route to `hms-auth-bff`
3. BFF calls Workflow service via Kuma mesh (mTLS)
4. Kuma applies retry/timeout policies
5. Response flows back through mesh

---

## 🔧 Troubleshooting

### Kuma Control Plane Not Starting

**Symptoms:**
- `kuma-cp` container exits immediately
- Cannot access `http://localhost:5681`

**Solutions:**
```bash
# Check logs
docker-compose logs kuma-cp

# Verify port availability
lsof -i :5681

# Restart control plane
docker-compose restart kuma-cp
```

### Sidecar Not Registering

**Symptoms:**
- Service starts but doesn't appear in Kuma GUI
- Dataplane not listed in API

**Solutions:**
```bash
# Check sidecar logs
docker-compose logs hms-auth-bff-sidecar

# Verify dataplane configuration
cat kuma/dataplanes/hms-auth-bff.yaml

# Manually register dataplane
curl -X POST http://localhost:5681/meshes/default/dataplanes \
  -H "Content-Type: application/json" \
  -d @kuma/dataplanes/hms-auth-bff.yaml
```

### mTLS Connection Failures

**Symptoms:**
- Services cannot communicate
- `503 Service Unavailable` errors

**Solutions:**
1. **Check mTLS mode:**
   ```bash
   curl http://localhost:5681/meshes/default | jq '.mtls.mode'
   ```
   Should be `permissive` or `strict`.

2. **Verify certificates:**
   ```bash
   # List certificates
   curl http://localhost:5681/meshes/default/certificates
   ```

3. **Check service tags:**
   Ensure service names match in dataplane configs.

### Policies Not Applied

**Symptoms:**
- Retries/timeouts not working
- Circuit breaker not triggering

**Solutions:**
```bash
# List applied policies
curl http://localhost:5681/meshes/default/retries
curl http://localhost:5681/meshes/default/circuit-breakers

# Re-apply policies
cd kuma
./init-kuma.sh
```

### Context Headers Not Propagating

**Symptoms:**
- `x-hms-trace-id` lost between services
- Tenant context missing

**Solutions:**
1. **Verify headers are set:**
   ```bash
   curl -v http://localhost:8000/api/auth/login \
     -H "x-hms-trace-id: test-123"
   ```

2. **Check Kuma access logs:**
   ```bash
   docker exec kuma-cp cat /tmp/kuma-access.log
   ```

3. **Verify service configuration:**
   Ensure services are using `hms-common-lib` context propagation.

---

## 🎓 Advanced Topics

### Switching to Strict mTLS

**Current:** `permissive` mode (allows non-mesh traffic)

**To enable strict mode:**

1. Update `mesh-default.yaml`:
   ```yaml
   mtls:
     mode: strict  # Changed from permissive
   ```

2. Re-apply mesh config:
   ```bash
   curl -X PUT http://localhost:5681/meshes/default \
     -H "Content-Type: application/json" \
     -d @mesh-default.yaml
   ```

**Warning:** Strict mode will block all non-mesh traffic. Ensure all services have sidecars.

### Adding a New Service to the Mesh

1. **Create dataplane config:**
   ```yaml
   # kuma/dataplanes/my-new-service.yaml
   type: Dataplane
   mesh: default
   name: my-new-service
   networking:
     address: 0.0.0.0
     inbound:
       - port: 8080
         servicePort: 8080
         serviceAddress: 127.0.0.1
         tags:
           kuma.io/service: my-new-service
           kuma.io/protocol: http
   ```

2. **Add sidecar to `docker-compose.yml`:**
   ```yaml
   my-new-service-sidecar:
     image: kong/kuma-dp:2.5.0
     container_name: my-new-service-sidecar
     network_mode: "service:my-new-service"
     environment:
       KUMA_DATAPLANE_NAME: my-new-service
       KUMA_DATAPLANE_MESH: default
       KUMA_CONTROL_PLANE_URL: http://kuma-cp:5681
     depends_on:
       - kuma-cp
       - my-new-service
   ```

3. **Update service to use sidecar:**
   ```yaml
   my-new-service:
     # ... existing config ...
     network_mode: "service:my-new-service-sidecar"  # Add this
   ```

### Custom Traffic Policies

Create custom policies for specific services:

```yaml
# kuma/policies/custom-retry-policy.yaml
type: TrafficRetry
mesh: default
name: workflow-service-retry
spec:
  targetRef:
    kind: MeshService
    name: hms-onboarding-workflow
  from:
    - targetRef:
        kind: Mesh
      default:
        http:
          numRetries: 5
          retriableStatusCodes: [503, 504]
          perTryTimeout: 2s
```

Apply:
```bash
curl -X POST http://localhost:5681/meshes/default/retries \
  -H "Content-Type: application/json" \
  -d @kuma/policies/custom-retry-policy.yaml
```

### Integration with Zipkin

To enable distributed tracing:

1. **Add Zipkin to `docker-compose.yml`:**
   ```yaml
   zipkin:
     image: openzipkin/zipkin:latest
     container_name: zipkin
     ports:
       - "9411:9411"
     networks:
       - hms-network
   ```

2. **Update `traffic-trace-policy.yaml`:**
   ```yaml
   conf:
     url: http://zipkin:9411/api/v2/spans
   ```

3. **View traces:**
   ```
   http://localhost:9411
   ```

---

## 📚 References

- [Kuma Documentation](https://kuma.io/docs/)
- [Kuma Universal Mode](https://kuma.io/docs/2.5.x/installation/universal/)
- [Kuma Policies](https://kuma.io/docs/2.5.x/policies/)
- [Envoy Proxy](https://www.envoyproxy.io/)

---

## ✅ Verification Checklist

After setup, verify:

- [ ] Kuma Control Plane is running (`http://localhost:5681/ready`)
- [ ] Kuma GUI is accessible (`http://localhost:5681/gui/`)
- [ ] All dataplanes are registered (check GUI or API)
- [ ] mTLS is enabled (check mesh config)
- [ ] Policies are applied (retry, circuit breaker, timeout)
- [ ] Service-to-service communication works
- [ ] Context headers are preserved (`x-hms-trace-id`)
- [ ] Metrics are being collected (Prometheus endpoint)

---

**Last Updated:** 2024
**Maintained by:** HMS Platform Engineering Team

