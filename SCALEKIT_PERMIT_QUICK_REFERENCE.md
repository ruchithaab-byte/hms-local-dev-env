# ScaleKit + Permit.io Integration - Quick Reference

## TL;DR: Who Does What?

| Component | Responsibility | Manages |
|-----------|---------------|---------|
| **ScaleKit** | Identity Provider | Users, Organizations, Identity Roles |
| **Permit.io** | Authorization Engine | Resources, Actions, Authorization Roles, Policies |
| **Your App** | Integration Layer | Syncs identity → authorization, makes permission checks |

## The Flow (Simple Version)

```
1. User logs in → ScaleKit issues JWT
   JWT contains: userId, orgId, roles

2. User makes API call → Your app extracts JWT claims
   Extracts: userId="user_123", orgId="org_456"

3. Your app checks permission → Calls Permit.io
   "Can user_123 create workflow_process in workspace org_456?"

4. Permit.io decides → Returns ALLOW or DENY
   Based on: User's role in workspace + Policy rules

5. Your app responds → 200 OK or 403 Forbidden
```

## Where to Configure What

### ScaleKit Java SDK (Programmatic - No Dashboard)
✅ **Create via HMS User Management UI:**
- Users (via `scalekitClient.directory().createUser(...)`)
- Organizations (via `scalekitClient.directory().createOrganization(...)`)
- Role assignments (via `scalekitClient.directory().assignRole(...)`)

✅ **Automatic Sync:**
- Users → Permit.io (via `PermitSyncService.syncUser(...)`)
- Organizations → Permit.io workspaces (via `PermitSyncService.syncOrganization(...)`)
- Role assignments → Permit.io (via `PermitSyncService.assignRole(...)`)

✅ **JWT Claims:**
- ScaleKit automatically includes `sub`, `org_id` in JWT tokens

### Permit.io Dashboard (Authorization)
✅ **Create:**
- **Resources**: `workflow_process`, `patient_record`, etc.
- **Roles**: `admin`, `clinician`, `auditor`, `ai_agent`
- **Policies**: Rules connecting roles → resources → actions

✅ **Sync (via your app):**
- Users (from ScaleKit)
- Workspaces (from ScaleKit organizations)
- Role assignments (from ScaleKit)

## Common Questions

### Q: Do I create roles in ScaleKit or Permit.io?
**A: Both, but for different purposes:**
- **ScaleKit roles**: Identity roles (who you are)
- **Permit.io roles**: Authorization roles (what you can do)
- **Best practice**: Use same role names in both (e.g., "admin" in both)

### Q: Where do organizations come from?
**A: ScaleKit**
- Organizations are created in ScaleKit
- They appear as `org_id` in JWT
- Your app syncs them to Permit.io as "workspaces"

### Q: How do roles get from ScaleKit to Permit.io?
**A: Your app syncs them**
- Option 1: JIT (Just-In-Time) - sync on first login
- Option 2: Webhooks - real-time sync when roles change
- Option 3: Batch job - periodic sync

### Q: What if a user's role changes in ScaleKit?
**A: Update Permit.io too**
- If using webhooks: automatic sync
- If using JIT: sync on next login
- If using batch: sync in next batch run

## Configuration Checklist

### Phase 1: ScaleKit Setup (Programmatic)
- [ ] Implement User Management Controller (create user/org/role endpoints)
- [ ] Integrate ScaleKit Java SDK (`scalekitClient.directory().createUser(...)`)
- [ ] Implement `PermitSyncService` integration
- [ ] Test user creation flow (ScaleKit → Permit.io sync)
- [ ] Verify JWT contains `sub`, `org_id` after user creation

### Phase 2: Permit.io Setup
- [ ] Create resources (`workflow_process`, etc.)
- [ ] Create roles (`admin`, `clinician`, etc.)
- [ ] Create policies (role → resource → action rules)
- [ ] Get API key and environment ID

### Phase 3: Application Sync
- [ ] Implement user sync (JIT or webhook)
- [ ] Implement organization/workspace sync
- [ ] Implement role assignment sync
- [ ] Test sync flow

### Phase 4: Permission Checks
- [ ] Add permission checks to controllers
- [ ] Test with different roles
- [ ] Verify multi-tenancy (users can only access their org's data)

## Example: Setting Up a New User

### Step 1: Create in ScaleKit (via HMS UI)
```
HMS User Management UI:
- Admin fills form: email="doctor@hospital.com"
- Selects organization: "Hospital A" (org_id="org_123")
- Selects role: "clinician"
- Clicks "Create User"

Backend:
- Calls scalekitClient.directory().createUser(...)
- Calls scalekitClient.directory().assignRole(...)
```

### Step 2: Sync to Permit.io (via your app)
```java
// On user login or via webhook
permit.api.users.sync(new UserCreate()
    .withKey("user_456")  // ScaleKit user ID
    .withEmail("doctor@hospital.com")
);

permit.api.users.assignRole(
    "user_456",
    "clinician",  // Same role name as ScaleKit
    "org_123"     // Workspace = ScaleKit org_id
);
```

### Step 3: User Makes Request
```
JWT: { "sub": "user_456", "org_id": "org_123" }

POST /api/v1/onboarding/start
→ Permission check: Can user_456 create workflow_process in org_123?
→ Permit.io: Checks role "clinician" → Policy says "yes" → ALLOW
```

## Troubleshooting

### Problem: Permission denied for valid user
**Check:**
1. Is user synced to Permit.io? (`permit.api.users.get("user_123")`)
2. Is workspace synced? (`permit.api.workspaces.get("org_456")`)
3. Is role assigned? (`permit.api.users.getRoles("user_123", "org_456")`)
4. Does policy allow this role → action → resource?

### Problem: User can access other org's data
**Check:**
1. Is workspace context passed correctly? (`resource.withAttributes("workspace", orgId)`)
2. Does policy enforce workspace isolation?
3. Is ReBAC relationship configured? (`user member_of workspace`)

### Problem: Roles not syncing
**Check:**
1. Are webhooks configured in ScaleKit?
2. Is webhook handler implemented in your app?
3. Are webhook signatures verified?
4. Check application logs for sync errors

## Key Files in Your Codebase

- **Identity Extraction**: `JwtAuthenticationFilter.java`
  - Extracts `sub`, `org_id`, `roles` from JWT
  
- **Permission Checking**: `PermissionService.java`
  - Calls Permit.io with user ID, action, resource
  
- **Sync Logic**: (To be implemented)
  - `OidcCallbackController.java` - JIT sync on login
  - `ScaleKitWebhookController.java` - Real-time sync via webhooks

## Next Steps

1. **Read the full guide**: `SCALEKIT_PERMIT_INTEGRATION.md`
2. **Set up ScaleKit**: Create users, orgs, roles
3. **Set up Permit.io**: Create resources, roles, policies
4. **Implement sync**: Choose JIT, webhooks, or batch
5. **Test**: Verify permission checks work correctly

