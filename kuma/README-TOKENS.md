# Kuma Dataplane Token Generation

## Problem
Kuma 2.8.3 requires dataplane tokens for sidecar authentication. The tokens cannot be disabled via environment variables.

## Solution Options

### Option 1: Use kumactl (Recommended)

1. **Install kumactl:**
   ```bash
   # macOS
   brew install kumactl
   
   # Or download from: https://github.com/kumahq/kuma/releases
   ```

2. **Configure kumactl:**
   ```bash
   kumactl config control-planes add \
     --name=local \
     --address=http://localhost:5681 \
     --overwrite
   ```

3. **Generate tokens:**
   ```bash
   cd kuma
   mkdir -p tokens
   
   kumactl generate dataplane-token --mesh=default --name=hms-auth-bff > tokens/hms-auth-bff-token
   kumactl generate dataplane-token --mesh=default --name=hms-onboarding-workflow > tokens/hms-onboarding-workflow-token
   kumactl generate dataplane-token --mesh=default --name=hms-dashboard-projector > tokens/hms-dashboard-projector-token
   ```

4. **Update docker-compose.yml sidecars:**
   ```yaml
   hms-auth-bff-sidecar:
     command: run --cp-address=https://kuma-cp:5678 --dataplane-file=/kuma/dataplane.yaml --dataplane-token-file=/kuma/token
     volumes:
       - ./kuma/dataplanes/hms-auth-bff.yaml:/kuma/dataplane.yaml:ro
       - ./kuma/tokens/hms-auth-bff-token:/kuma/token:ro
   ```

### Option 2: Use Kuma GUI

1. Open Kuma GUI: http://localhost:5681/gui/
2. Navigate to **Dataplanes** → **Generate Token**
3. Select mesh: `default`
4. Enter dataplane name: `hms-auth-bff`
5. Copy the generated token
6. Save to `kuma/tokens/hms-auth-bff-token`

### Option 3: Use API with Admin Token (Advanced)

If you can access the admin token (requires localhost admin access):

```bash
# Get admin token
ADMIN_TOKEN=$(curl -s http://localhost:5681/global-secrets/admin-user-token | jq -r .data | base64 -d)

# Generate dataplane token
curl -X POST http://localhost:5681/tokens/dataplane \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"mesh":"default","name":"hms-auth-bff"}' | jq -r .token > kuma/tokens/hms-auth-bff-token
```

## After Generating Tokens

1. **Update docker-compose.yml** to mount token files in sidecars
2. **Update sidecar commands** to include `--dataplane-token-file=/kuma/token`
3. **Restart sidecars:**
   ```bash
   docker-compose restart *-sidecar
   ```

## Verify

Check Kuma GUI: http://localhost:5681/gui/
- Navigate to **Meshes** → **default** → **Dataplanes**
- You should see your services listed as online dataplanes

