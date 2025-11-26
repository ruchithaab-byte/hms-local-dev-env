# Security Best Practices for Environment Variables

## ⚠️ CRITICAL: Secret Keys Are Sensitive

**ALL API keys, secrets, and tokens shown in this documentation are SENSITIVE and must be protected.**

## Security Rules

### 1. Never Commit Secrets to Git

✅ **DO:**
- Add `.env` to `.gitignore`
- Use `.env.example` as a template (without real values)
- Use environment-specific secrets for dev/staging/prod

❌ **DON'T:**
- Commit `.env` file to Git
- Share secrets in chat/email/Slack
- Hardcode secrets in source code
- Commit secrets in documentation

### 2. Rotate Secrets Regularly

- **Permit.io API Keys**: Regenerate if compromised or quarterly
- **ScaleKit Secrets**: Regenerate Client Secret and Webhook Secret if exposed
- **Database Passwords**: Change regularly, especially in production

### 3. Use Different Secrets Per Environment

- **Development**: Use separate Permit.io "Development" environment
- **Staging**: Use separate Permit.io "Staging" environment  
- **Production**: Use separate Permit.io "Production" environment

### 4. Access Control

- Only team members who need access should have Dashboard credentials
- Use least-privilege principle
- Revoke access immediately when team members leave

## How to Safely Add Secrets

### Step 1: Verify `.env` is in `.gitignore`

```bash
cd hms-local-dev-env
cat .gitignore | grep -E "^\.env$"
```

If not present, add it:
```bash
echo ".env" >> .gitignore
```

### Step 2: Add Secrets to `.env` (Local File Only)

```bash
# Edit .env file (this file should NEVER be committed)
nano .env
# or
vim .env
```

Add your secrets:
```bash
# Permit.io Configuration
PERMIT_API_KEY=permit_key_your_actual_secret_key_here
PERMIT_ENVIRONMENT=Development

# ScaleKit Configuration (already configured)
SCALEKIT_ENVIRONMENT_URL=https://your-org.scalekit.com
SCALEKIT_CLIENT_ID=your_client_id
SCALEKIT_CLIENT_SECRET=your_client_secret
SCALEKIT_WEBHOOK_SECRET=your_webhook_secret
```

### Step 3: Verify `.env` is NOT Tracked by Git

```bash
git status
# .env should NOT appear in the list
```

If it does appear, remove it:
```bash
git rm --cached .env
```

## What to Do If Secrets Are Exposed

### If `.env` was accidentally committed:

1. **Immediately rotate all exposed secrets:**
   - Permit.io: Generate new API key in Dashboard
   - ScaleKit: Regenerate Client Secret and Webhook Secret

2. **Remove from Git history:**
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch .env" \
     --prune-empty --tag-name-filter cat -- --all
   ```

3. **Force push (coordinate with team):**
   ```bash
   git push origin --force --all
   ```

4. **Update `.env` with new secrets**

### If secrets were shared in chat/documentation:

1. Rotate all exposed secrets immediately
2. Update `.env` with new values
3. Review access logs in Permit.io and ScaleKit dashboards

## Production Deployment

For production, use **secure secret management**:

- **AWS**: AWS Secrets Manager or Parameter Store
- **Azure**: Azure Key Vault
- **GCP**: Secret Manager
- **Kubernetes**: Secrets (encrypted at rest)
- **Docker Swarm**: Docker Secrets

**Never** use `.env` files in production containers.

## Verification Checklist

Before committing code:

- [ ] `.env` is in `.gitignore`
- [ ] `.env` is not tracked by Git (`git status` shows no `.env`)
- [ ] `.env.example` exists (without real secrets)
- [ ] No secrets in source code
- [ ] No secrets in documentation
- [ ] Different secrets for dev/staging/prod

## Current Secret Status

✅ **ScaleKit Secrets**: Configured in `.env` (not in Git)
❌ **Permit.io Secrets**: Need to be added to `.env` (not in Git)

**Action**: Add Permit.io secrets to `.env` file (local only, never commit).

