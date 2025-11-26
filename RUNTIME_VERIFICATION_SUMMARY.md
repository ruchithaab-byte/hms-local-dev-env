# Runtime Verification Summary

## ✅ Verification Script Created

A verification script has been created to check all required environment variables before starting services.

### Quick Start

```bash
cd hms-local-dev-env
./verify-runtime-config.sh
```

## Required Environment Variables for `hms-auth-bff`

### 1. Permit.io (2 variables required)

| Variable | Status | Where to Get It |
|----------|--------|-----------------|
| `PERMIT_API_KEY` | ❌ **MISSING** | Permit.io Dashboard → Settings → API Keys |
| `PERMIT_ENVIRONMENT` | ❌ **MISSING** | Permit.io Dashboard → Environments → Select/Create |
| `PERMIT_PDP_URL` | ⚠️ Optional | Set in docker-compose.yml to `http://permit-pdp-bff:7000` |

**Action Required:**
1. Log in to [Permit.io Dashboard](https://app.permit.io)
2. Create/retrieve API key from Settings → API Keys
3. Select/create environment from Environments
4. Add both to `.env` file

### 2. ScaleKit (4 variables - ✅ ALL CONFIGURED)

| Variable | Status | Value |
|----------|--------|-------|
| `SCALEKIT_ENVIRONMENT_URL` | ✅ Configured | `https://julleyonline-afgqshppaaaa2.scalekit.dev` |
| `SCALEKIT_CLIENT_ID` | ✅ Configured | `skc_93741191983529997` |
| `SCALEKIT_CLIENT_SECRET` | ✅ Configured | `test_a73...2JUQ` (masked) |
| `SCALEKIT_WEBHOOK_SECRET` | ✅ Configured | `whsec_Dr...60tl` (masked) |

**Status:** ✅ All ScaleKit variables are properly configured!

### 3. Database (Optional - ✅ Configured)

| Variable | Status | Value |
|----------|--------|-------|
| `POSTGRES_USER` | ✅ Configured | `postgres` |
| `POSTGRES_PASSWORD` | ✅ Configured | `postgres` (default) |

## Current Verification Results

```
==========================================
HMS Runtime Configuration Verification
==========================================

✅ .env file found

Checking Permit.io Configuration...
-----------------------------------
❌ MISSING: PERMIT_API_KEY
❌ MISSING: PERMIT_ENVIRONMENT
⚠️  PERMIT_PDP_URL not set (using docker-compose.yml default)

Checking ScaleKit Configuration...
-----------------------------------
✅ SCALEKIT_ENVIRONMENT_URL
✅ SCALEKIT_CLIENT_ID
✅ SCALEKIT_CLIENT_SECRET
✅ SCALEKIT_WEBHOOK_SECRET

Checking Database Configuration...
-----------------------------------
✅ POSTGRES_USER
✅ POSTGRES_PASSWORD

==========================================
❌ 2 required variable(s) are missing!
```

## Next Steps

### Step 1: Add Permit.io Credentials

Add these two lines to your `.env` file:

```bash
PERMIT_API_KEY=p_your_actual_api_key_here
PERMIT_ENVIRONMENT=dev
```

**How to get Permit.io credentials:**

1. **API Key:**
   - Go to https://app.permit.io
   - Navigate to **Settings** → **API Keys**
   - Click **Create API Key** or copy existing key
   - Copy the key (starts with `p_`)

2. **Environment:**
   - In Permit.io Dashboard, go to **Environments**
   - Select your environment (e.g., `dev`, `production`)
   - Or create a new one if needed
   - Copy the environment name (case-sensitive)

### Step 2: Re-run Verification

```bash
./verify-runtime-config.sh
```

Expected output:
```
✅ All required environment variables are configured!
```

### Step 3: Start Services

```bash
docker-compose up -d
```

### Step 4: Verify Services Are Running

```bash
# Check all containers
docker-compose ps

# Check hms-auth-bff logs
docker-compose logs -f hms-auth-bff

# Check health endpoint
curl http://localhost:8080/actuator/health
```

## How Environment Variables Are Used

### In `docker-compose.yml`

The `hms-auth-bff` service receives these environment variables:

```yaml
environment:
  - PERMIT_API_KEY=${PERMIT_API_KEY}              # From .env
  - PERMIT_ENVIRONMENT=${PERMIT_ENVIRONMENT}      # From .env
  - PERMIT_PDP_URL=http://permit-pdp-bff:7000    # Hardcoded in docker-compose.yml
  - SCALEKIT_ENVIRONMENT_URL=${SCALEKIT_ENVIRONMENT_URL}
  - SCALEKIT_CLIENT_ID=${SCALEKIT_CLIENT_ID}
  - SCALEKIT_CLIENT_SECRET=${SCALEKIT_CLIENT_SECRET}
  - SCALEKIT_WEBHOOK_SECRET=${SCALEKIT_WEBHOOK_SECRET}
```

### In Application Code

The Spring Boot application reads these via `@Value` annotations:

- `PermissionService`: Uses `permit.api.key`, `permit.environment`, `permit.pdp.url`
- `PermitSyncService`: Uses `permit.api.key`, `permit.environment`, `permit.pdp.url`
- `ScalekitClient`: Uses `scalekit.env.url`, `scalekit.client.id`, `scalekit.client.secret`
- `OidcCallbackController`: Uses `scalekit.client.id` for authentication

## Troubleshooting

### Issue: "Permit.io API key not configured"
- **Symptom**: Log shows: `Permit.io API key not configured. Permission checks will be disabled.`
- **Fix**: Add `PERMIT_API_KEY` to `.env` file

### Issue: "Permission checks disabled"
- **Symptom**: Log shows: `Permit.io environment not configured. Permission checks will be disabled.`
- **Fix**: Add `PERMIT_ENVIRONMENT` to `.env` file

### Issue: "Cannot connect to Permit PDP"
- **Symptom**: Errors when calling `PermissionService.check()`
- **Fix**: 
  1. Verify `permit-pdp-bff` container is running: `docker ps | grep permit-pdp-bff`
  2. Check PDP health: `docker exec permit-pdp-bff wget -q -O- http://localhost:7000/health`
  3. Verify `PERMIT_PDP_URL` is correct (should be `http://permit-pdp-bff:7000` in Docker)

### Issue: "ScaleKit authentication fails"
- **Symptom**: OAuth callback fails or SDK initialization errors
- **Fix**: Verify all ScaleKit variables are correct in `.env` file

## Files Created

1. ✅ `verify-runtime-config.sh` - Verification script
2. ✅ `RUNTIME_CONFIGURATION.md` - Detailed configuration guide
3. ✅ `.env.example` - Template for environment variables

## Summary

- ✅ **ScaleKit**: All 4 variables configured
- ✅ **Database**: Configured (using defaults)
- ❌ **Permit.io**: 2 variables missing (need to add)
- ✅ **Verification Script**: Created and working

**Action Required:** Add `PERMIT_API_KEY` and `PERMIT_ENVIRONMENT` to `.env` file, then services are ready to start!

