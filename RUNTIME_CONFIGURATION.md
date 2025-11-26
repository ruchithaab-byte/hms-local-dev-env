# Runtime Configuration Guide

This document explains how to configure the required environment variables for the HMS services to run correctly.

## Quick Start

1. **Create `.env` file** in `hms-local-dev-env/` directory
2. **Run verification script**: `./verify-runtime-config.sh`
3. **Start services**: `docker-compose up -d`

## Required Environment Variables

### 1. Permit.io Configuration

#### `PERMIT_API_KEY`
- **Description**: API key for Permit.io SDK authentication
- **Where to get it**:
  1. Log in to [Permit.io Dashboard](https://app.permit.io)
  2. Navigate to **Settings** → **API Keys**
  3. Click **Create API Key** or copy existing key
  4. Copy the key (starts with `p_` or similar)
- **Example**: `p_abc123def456ghi789jkl012mno345pqr678stu901vwx234yz`
- **Required for**: 
  - `hms-auth-bff` service
  - `permit-pdp-kong`, `permit-pdp-workflow`, `permit-pdp-bff` containers

#### `PERMIT_ENVIRONMENT`
- **Description**: Permit.io environment name (e.g., 'dev', 'production', 'staging')
- **Where to get it**:
  1. In Permit.io Dashboard, go to **Environments**
  2. Select your environment or create a new one
  3. Copy the environment name (case-sensitive)
- **Example**: `dev` or `production`
- **Required for**: `hms-auth-bff` service

#### `PERMIT_PDP_URL`
- **Description**: URL of the Permit.io Policy Decision Point (PDP) sidecar
- **Default**: Set automatically in `docker-compose.yml` to `http://permit-pdp-bff:7000`
- **Note**: Usually you don't need to set this manually unless running locally
- **For local development**: `http://localhost:7000`
- **Required for**: `hms-auth-bff` service (for `PermissionService` and `PermitSyncService`)

### 2. ScaleKit Configuration

#### `SCALEKIT_ENVIRONMENT_URL`
- **Description**: Your ScaleKit environment URL
- **Where to get it**:
  1. Log in to [ScaleKit Dashboard](https://app.scalekit.com)
  2. Navigate to **Settings** → **Environment**
  3. Copy the Environment URL
- **Example**: `https://your-org.scalekit.com` or `https://api.scalekit.com/v1`
- **Required for**: `hms-auth-bff` service (for OAuth and JWT validation)

#### `SCALEKIT_CLIENT_ID`
- **Description**: OAuth 2.0 Client ID for your ScaleKit application
- **Where to get it**:
  1. In ScaleKit Dashboard, go to **Applications**
  2. Select your application or create a new one
  3. Copy the **Client ID**
- **Example**: `client_abc123def456`
- **Required for**: `hms-auth-bff` service (for OAuth flow and SDK initialization)

#### `SCALEKIT_CLIENT_SECRET`
- **Description**: OAuth 2.0 Client Secret for your ScaleKit application
- **Where to get it**:
  1. In ScaleKit Dashboard, go to **Applications**
  2. Select your application
  3. Copy the **Client Secret** (only shown once when created)
  4. If lost, regenerate it (old secret will be invalidated)
- **Example**: `secret_xyz789abc123def456`
- **Required for**: `hms-auth-bff` service (for OAuth flow and SDK initialization)

#### `SCALEKIT_WEBHOOK_SECRET`
- **Description**: Secret key for verifying webhook signatures from ScaleKit
- **Where to get it**:
  1. In ScaleKit Dashboard, go to **Webhooks**
  2. Create a webhook endpoint pointing to: `https://your-domain.com/api/webhooks/scalekit`
  3. Copy the **Webhook Secret** (only shown once when created)
  4. If lost, regenerate it
- **Example**: `whsec_abc123def456`
- **Required for**: `hms-auth-bff` service (for webhook signature verification)

### 3. Database Configuration (Optional)

These are usually set in `docker-compose.yml` with defaults, but can be overridden:

- `POSTGRES_USER`: PostgreSQL username (default: `postgres`)
- `POSTGRES_PASSWORD`: PostgreSQL password (default: `postgres`)
- `SPRING_DATASOURCE_URL`: JDBC URL (default: `jdbc:postgresql://postgres:5432/bff_db`)

## Example `.env` File

Create a `.env` file in `hms-local-dev-env/` directory:

```bash
# Permit.io Configuration
PERMIT_API_KEY=p_abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
PERMIT_ENVIRONMENT=dev
# PERMIT_PDP_URL is set in docker-compose.yml, but can override here if needed
# PERMIT_PDP_URL=http://permit-pdp-bff:7000

# ScaleKit Configuration
SCALEKIT_ENVIRONMENT_URL=https://your-org.scalekit.com
SCALEKIT_CLIENT_ID=client_abc123def456
SCALEKIT_CLIENT_SECRET=secret_xyz789abc123def456
SCALEKIT_WEBHOOK_SECRET=whsec_abc123def456

# Database (optional - defaults in docker-compose.yml)
# POSTGRES_USER=postgres
# POSTGRES_PASSWORD=postgres
```

## Verification

Run the verification script to check all required variables:

```bash
cd hms-local-dev-env
chmod +x verify-runtime-config.sh
./verify-runtime-config.sh
```

The script will:
- ✅ Check if `.env` file exists
- ✅ Verify all required variables are set
- ✅ Mask sensitive values in output
- ✅ Provide clear error messages if variables are missing

## How Environment Variables Are Used

### In `docker-compose.yml`

The `hms-auth-bff` service receives environment variables like this:

```yaml
environment:
  - PERMIT_API_KEY=${PERMIT_API_KEY}
  - PERMIT_ENVIRONMENT=${PERMIT_ENVIRONMENT}
  - PERMIT_PDP_URL=http://permit-pdp-bff:7000
  - SCALEKIT_ENVIRONMENT_URL=${SCALEKIT_ENVIRONMENT_URL}
  - SCALEKIT_CLIENT_ID=${SCALEKIT_CLIENT_ID}
  - SCALEKIT_CLIENT_SECRET=${SCALEKIT_CLIENT_SECRET}
  - SCALEKIT_WEBHOOK_SECRET=${SCALEKIT_WEBHOOK_SECRET}
```

### In Application Code

The Spring Boot application reads these via `application.properties`:

```properties
# Permit.io
permit.api.key=${PERMIT_API_KEY}
permit.environment=${PERMIT_ENVIRONMENT}
permit.pdp.url=${PERMIT_PDP_URL:http://localhost:7000}

# ScaleKit
scalekit.env.url=${SCALEKIT_ENVIRONMENT_URL}
scalekit.client.id=${SCALEKIT_CLIENT_ID}
scalekit.client.secret=${SCALEKIT_CLIENT_SECRET}
scalekit.webhook.secret=${SCALEKIT_WEBHOOK_SECRET}
```

## Troubleshooting

### Issue: "Permit.io API key not configured"
- **Cause**: `PERMIT_API_KEY` is missing or empty
- **Fix**: Add `PERMIT_API_KEY` to `.env` file

### Issue: "ScaleKit client ID not found"
- **Cause**: `SCALEKIT_CLIENT_ID` is missing or incorrect
- **Fix**: Verify the Client ID in ScaleKit Dashboard and update `.env`

### Issue: "Permission checks disabled"
- **Cause**: `PERMIT_API_KEY` or `PERMIT_ENVIRONMENT` is missing
- **Fix**: Ensure both are set in `.env` file

### Issue: "Cannot connect to Permit PDP"
- **Cause**: `PERMIT_PDP_URL` is incorrect or PDP container is not running
- **Fix**: 
  1. Verify `permit-pdp-bff` container is running: `docker ps | grep permit-pdp-bff`
  2. Check PDP health: `curl http://localhost:7000/health` (if exposed)
  3. Verify `PERMIT_PDP_URL` is set to `http://permit-pdp-bff:7000` (for Docker) or `http://localhost:7000` (for local)

### Issue: "OAuth callback fails"
- **Cause**: `SCALEKIT_CLIENT_ID` or `SCALEKIT_CLIENT_SECRET` is incorrect
- **Fix**: Regenerate credentials in ScaleKit Dashboard if needed

## Security Best Practices

1. **Never commit `.env` file to Git**
   - Add `.env` to `.gitignore`
   - Use `.env.example` as a template (without real values)

2. **Rotate secrets regularly**
   - Regenerate API keys and secrets periodically
   - Update `.env` file when rotating

3. **Use different environments**
   - Use separate Permit.io environments for dev/staging/prod
   - Use separate ScaleKit applications for each environment

4. **Restrict access**
   - Only team members who need access should have Dashboard credentials
   - Use environment-specific secrets

## Next Steps

After configuring environment variables:

1. ✅ Run verification: `./verify-runtime-config.sh`
2. ✅ Start services: `docker-compose up -d`
3. ✅ Check logs: `docker-compose logs -f hms-auth-bff`
4. ✅ Test health endpoint: `curl http://localhost:8080/actuator/health`
5. ✅ Test user creation: `POST /api/admin/organizations/{orgId}/users`

## Additional Resources

- [Permit.io Documentation](https://docs.permit.io)
- [ScaleKit Documentation](https://docs.scalekit.com)
- [Docker Compose Environment Variables](https://docs.docker.com/compose/environment-variables/)

