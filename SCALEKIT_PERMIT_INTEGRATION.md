# ScaleKit + Permit.io Integration Architecture

## The Big Picture: Identity vs Authorization

```
┌─────────────────────────────────────────────────────────────────┐
│                    SCALEKIT (Identity Provider)                 │
│  ┌──────────┐  ┌──────────────┐  ┌──────────┐                 │
│  │  Users   │  │ Organizations│  │  Roles   │                 │
│  │          │  │  (Tenants)   │  │ (Identity)│                │
│  └────┬─────┘  └──────┬───────┘  └────┬─────┘                 │
│       │               │                │                        │
│       └───────────────┴────────────────┘                        │
│                          │                                        │
│                          ▼                                        │
│              Issues JWT Token with Claims:                        │
│              {                                                      │
│                "sub": "user_123",        // User ID              │
│                "org_id": "org_456",      // Organization ID      │
│                "roles": ["admin"],       // ScaleKit Roles       │
│                "email": "user@example.com"                       │
│              }                                                      │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                           │ JWT Token
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                  YOUR APPLICATION (HMS)                         │
│                                                                   │
│  1. JwtAuthenticationFilter extracts claims                     │
│     - userId = "user_123"                                       │
│     - orgId = "org_456"                                          │
│     - roles = ["admin"]                                          │
│                                                                   │
│  2. PermissionService calls Permit.io                            │
│     - User: "user_123"                                           │
│     - Resource: "workflow_process"                               │
│     - Action: "create"                                           │
│     - Tenant: "org_456"                                          │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                           │ Permission Check
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                  PERMIT.IO (Authorization Engine)               │
│  ┌──────────┐  ┌──────────────┐  ┌──────────┐                 │
│  │  Users   │  │  Workspaces   │  │  Roles   │                 │
│  │ (Synced) │  │  (Synced)     │  │(Authz)   │                 │
│  └────┬─────┘  └──────┬───────┘  └────┬─────┘                 │
│       │               │                │                        │
│       └───────────────┴────────────────┘                        │
│                          │                                        │
│                          ▼                                        │
│              Policy Decision:                                    │
│              "Does user_123 have 'create' permission             │
│               on 'workflow_process' in workspace org_456?"        │
│                                                                   │
│              Returns: ALLOW or DENY                              │
└─────────────────────────────────────────────────────────────────┘
```

## Key Concepts

### 1. ScaleKit = Identity Provider (WHO you are)

**What ScaleKit Manages:**
- **Users**: User accounts, emails, profiles
- **Organizations**: Multi-tenant organizations (your `org_id`)
- **Roles (Identity)**: Roles for authentication/identity purposes
  - Examples: "admin", "user", "viewer"
  - These are **identity roles** - they identify what type of user you are

**What ScaleKit Provides:**
- JWT tokens with identity claims:
  ```json
  {
    "sub": "user_123",           // User ID
    "org_id": "org_456",         // Organization/Tenant ID
    "roles": ["admin"],          // ScaleKit identity roles
    "email": "user@example.com"
  }
  ```
- OIDC/OAuth2 authentication
- Webhooks for user/org lifecycle events

### 2. Permit.io = Authorization Engine (WHAT you can do)

**What Permit.io Manages:**
- **Resources**: Things you want to protect (e.g., `workflow_process`, `patient_record`)
- **Actions**: What can be done (e.g., `create`, `read`, `update`, `delete`)
- **Roles (Authorization)**: Roles for authorization decisions
  - Examples: "admin", "clinician", "auditor", "ai_agent"
  - These are **authorization roles** - they define what you can do
- **Policies**: Rules that connect users, roles, resources, and actions

**What Permit.io Provides:**
- Policy decisions (ALLOW/DENY)
- Fine-grained authorization
- Relationship-based access control (ReBAC)
- Audit logging

## The Integration: How They Work Together

### Step 1: User Authenticates via ScaleKit

```
User → ScaleKit Login → JWT Token Issued
```

**JWT Contains:**
- `sub`: User ID from ScaleKit
- `org_id`: Organization ID from ScaleKit (maps to Permit.io "workspace")
- `roles`: ScaleKit identity roles (optional, may be in JWT or fetched separately)

### Step 2: Application Extracts Identity Claims

**In `JwtAuthenticationFilter`:**
```java
String userId = jwt.getSubject();        // "user_123"
String orgId = jwt.getClaimAsString("org_id");  // "org_456"
String tenantId = orgId;                 // Maps to Permit.io workspace
```

### Step 3: Application Calls Permit.io for Authorization

**In `PermissionService`:**
```java
// Build resource with tenant context
Resource resource = permissionService.buildResource(
    "workflow_process", 
    null, 
    tenantId  // "org_456" → maps to Permit.io workspace
);

// Check permission
boolean permitted = permissionService.check(
    userId,      // "user_123" → Permit.io user
    "create",    // Action
    resource     // Resource with workspace context
);
```

### Step 4: Permit.io Makes Policy Decision

Permit.io evaluates:
1. **User**: Does `user_123` exist in Permit.io? (synced from ScaleKit)
2. **Workspace**: Does `org_456` exist as a workspace? (synced from ScaleKit)
3. **Role**: What role does `user_123` have in workspace `org_456`?
4. **Policy**: Does that role allow `create` on `workflow_process`?

Returns: **ALLOW** or **DENY**

## Critical Question: Where Do Roles Come From?

### Option A: ScaleKit Roles → Permit.io Roles (Recommended)

**Architecture:**
- ScaleKit manages roles (identity)
- Roles are synced to Permit.io (authorization)
- Permit.io uses synced roles for policy decisions

**Flow:**
1. Admin assigns role "admin" to user in ScaleKit
2. ScaleKit webhook → Application → Sync to Permit.io
3. Permit.io creates/updates user with role "admin"
4. JWT contains `org_id` and user ID
5. Permit.io looks up user's role in workspace and makes decision

**Implementation:**
- ScaleKit webhook handler syncs users/orgs/roles to Permit.io
- Permit.io API: `permit.api.users.sync()` or similar

### Option B: JWT Roles → Permit.io (Alternative)

**Architecture:**
- ScaleKit roles are in JWT claims
- Permit.io reads roles directly from JWT
- No sync needed, but less flexible

**Flow:**
1. Admin assigns role "admin" to user in ScaleKit
2. ScaleKit includes role in JWT: `"roles": ["admin"]`
3. Application extracts role from JWT
4. Permit.io uses role from JWT for decision

**Implementation:**
- Extract `roles` claim from JWT
- Pass role to Permit.io in permission check

### Option C: Separate Role Systems (Not Recommended)

**Architecture:**
- ScaleKit has identity roles
- Permit.io has separate authorization roles
- Manual mapping required

**Problem:** Two sources of truth, hard to keep in sync

## Recommended Integration Pattern

### Pattern: ScaleKit → Application → Permit.io Sync

```
┌─────────────┐
│  ScaleKit   │
│  (Identity) │
└──────┬──────┘
       │
       │ 1. User/Org/Role Created/Updated
       │    (via Webhook or JIT)
       ▼
┌─────────────────┐
│  Application    │
│  (HMS Service)  │
│                 │
│  - Receives     │
│    webhook      │
│  - Syncs to     │
│    Permit.io    │
└──────┬──────────┘
       │
       │ 2. Sync User/Org/Role
       │    to Permit.io
       ▼
┌─────────────┐
│  Permit.io  │
│ (Authz)     │
│             │
│  - User     │
│  - Workspace│
│  - Role     │
└─────────────┘
```

### Implementation Steps

#### 1. Sync Users from ScaleKit to Permit.io

**When:** User logs in (JIT) or via webhook

```java
// In OidcCallbackController or WebhookController
AuthenticationResponse authResult = scalekit.authentication().authenticateWithCode(code);
String userId = authResult.getIdTokenClaims().getSubject();
String email = authResult.getIdTokenClaims().getEmail();

// Sync to Permit.io
permit.api.users.sync(new UserCreate()
    .withKey(userId)
    .withEmail(email)
    .withRoles(extractRolesFromJWT(jwt))
);
```

#### 2. Sync Organizations/Workspaces

**When:** Organization created/updated (webhook)

```java
// In ScaleKitWebhookController
@PostMapping("/scalekit")
public void handleWebhook(@RequestBody WebhookEvent event) {
    if (event.getType() == "scalekit.dir.org.create") {
        String orgId = event.getOrgId();
        
        // Sync to Permit.io as workspace
        permit.api.workspaces.sync(new WorkspaceCreate()
            .withKey(orgId)
            .withName(event.getOrgName())
        );
    }
}
```

#### 3. Sync Roles

**When:** Role assigned to user (webhook or JIT)

```java
// Assign role to user in workspace
permit.api.users.assignRole(
    userId,           // From ScaleKit
    "admin",          // Role name (same as ScaleKit or mapped)
    orgId             // Workspace (from org_id)
);
```

#### 4. Use in Permission Checks

**In PermissionService:**
```java
// User and workspace already synced
// Just check permission
boolean permitted = permit.check(
    userId,      // Synced from ScaleKit
    "create",
    resource     // With workspace = orgId from JWT
);
```

## Configuration Summary

### ScaleKit Configuration (Identity)

**In ScaleKit Dashboard:**
- Create users
- Create organizations
- Assign roles to users
- Configure webhooks (optional, for real-time sync)

**JWT Claims Provided:**
- `sub`: User ID
- `org_id`: Organization ID
- `roles`: Array of role names (optional)

### Permit.io Configuration (Authorization)

**In Permit.io Dashboard:**
- **Resources**: Define what you protect
  - `workflow_process`
  - `patient_record`
  - `workspace`
  
- **Roles**: Define authorization roles
  - `admin`: Full access
  - `clinician`: Read/update patient records
  - `auditor`: Read-only
  - `ai_agent`: Read-only, no delete
  
- **Policies**: Define rules
  - "Users with role 'admin' can perform all actions on all resources"
  - "Users with role 'clinician' can 'read' and 'update' 'patient_record' in their workspace"
  - "Users with role 'ai_agent' can 'read' but cannot 'delete'"

- **Users/Workspaces**: Synced from ScaleKit (via application)

## Example Flow: User Creates Workflow

```
1. User authenticates → ScaleKit issues JWT
   JWT: { "sub": "user_123", "org_id": "org_456", "roles": ["admin"] }

2. User calls POST /api/v1/onboarding/start
   → JwtAuthenticationFilter extracts: userId="user_123", orgId="org_456"

3. OnboardingController calls PermissionService
   → permissionService.check("user_123", "create", resource("workflow_process", "org_456"))

4. PermissionService calls Permit.io PDP
   → "Does user_123 have 'create' permission on 'workflow_process' in workspace org_456?"

5. Permit.io checks:
   - User "user_123" exists? (synced from ScaleKit)
   - Workspace "org_456" exists? (synced from ScaleKit)
   - User has role "admin" in workspace "org_456"? (synced from ScaleKit)
   - Policy: "admin" role allows "create" on "workflow_process"? (defined in Permit.io)
   
6. Permit.io returns: ALLOW

7. Controller proceeds with workflow creation
```

## Key Takeaways

1. **ScaleKit = Identity (WHO)**
   - Manages users, organizations, identity roles
   - Issues JWT tokens
   - Source of truth for identity

2. **Permit.io = Authorization (WHAT)**
   - Manages resources, actions, authorization roles, policies
   - Makes permission decisions
   - Source of truth for authorization

3. **Integration = Sync Identity to Authorization**
   - Sync users/orgs/roles from ScaleKit to Permit.io
   - Use JWT claims (user ID, org ID) to query Permit.io
   - Permit.io makes decisions based on synced identity data

4. **Roles Can Be:**
   - **Same names**: ScaleKit "admin" → Permit.io "admin" (simplest)
   - **Mapped**: ScaleKit "super_user" → Permit.io "admin" (more flexible)
   - **Separate**: ScaleKit identity roles, Permit.io authorization roles (most complex)

## Next Steps

1. **Decide on Role Strategy:**
   - Same names (recommended for simplicity)
   - Or mapping strategy

2. **Implement Sync:**
   - JIT provisioning on login
   - Webhook handlers for real-time sync
   - Or batch sync job

3. **Configure Permit.io:**
   - Create resources, roles, policies
   - Ensure role names match ScaleKit (or implement mapping)

4. **Test Integration:**
   - Create user in ScaleKit
   - Verify sync to Permit.io
   - Test permission checks

