# ScaleKit Java SDK + Permit.io Integration Summary

## The Complete Picture

Your HMS application uses **ScaleKit Java SDK programmatically** (no dashboard) to manage users, organizations, and roles. These are then **automatically synced to Permit.io** for authorization decisions.

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────┐
│         HMS User Management UI (Your Application)           │
│  Admin creates users, orgs, assigns roles via web interface │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           │ HTTP POST /api/admin/users
                           ▼
┌─────────────────────────────────────────────────────────────┐
│         HMS Backend (UserManagementController)             │
│                                                              │
│  1. Create User in ScaleKit:                                │
│     scalekitClient.directory().createUser(...)              │
│                                                              │
│  2. Sync User to Permit.io:                                 │
│     permitSyncService.syncUser(...)                         │
│                                                              │
│  3. Assign Role in ScaleKit:                                │
│     scalekitClient.directory().assignRole(...)               │
│                                                              │
│  4. Sync Role to Permit.io:                                 │
│     permitSyncService.assignRole(...)                       │
└──────────────────────────┬──────────────────────────────────┘
                           │
        ┌──────────────────┴──────────────────┐
        │                                     │
        ▼                                     ▼
┌──────────────────┐              ┌──────────────────┐
│   ScaleKit API   │              │   Permit.io API  │
│  (Identity)      │              │  (Authorization) │
│                  │              │                  │
│  - Stores users  │              │  - Stores users  │
│  - Stores orgs  │              │  - Stores workspaces│
│  - Stores roles  │              │  - Stores role assignments│
│                  │              │  - Makes permission decisions│
└──────────────────┘              └──────────────────┘
        │                                     │
        │ Issues JWT                         │
        │ {sub, org_id}                      │
        │                                     │
        └──────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│         User Makes API Call                                 │
│                                                              │
│  JWT: { "sub": "user_123", "org_id": "org_456" }           │
│                                                              │
│  Permission Check:                                          │
│  permissionService.check("user_123", "create", resource)   │
│                                                              │
│  Permit.io Decision: ALLOW or DENY                          │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. ScaleKit Java SDK (`ScalekitClient`)
- **Purpose**: Programmatic identity management
- **Methods**:
  - `scalekitClient.directory().createUser(...)` - Create user
  - `scalekitClient.directory().createOrganization(...)` - Create org
  - `scalekitClient.directory().assignRole(...)` - Assign role
- **Location**: Already configured in `ScalekitConfig.java`

### 2. PermitSyncService (NEW)
- **Purpose**: Sync identity data from ScaleKit to Permit.io
- **Methods**:
  - `syncUser(userId, email, firstName, lastName)` - Sync user
  - `syncOrganization(orgId, orgName)` - Sync org as workspace
  - `assignRole(userId, roleName, orgId)` - Sync role assignment
- **Location**: `hms-common-lib/src/main/java/com/hms/lib/common/security/PermitSyncService.java`

### 3. PermissionService (EXISTING)
- **Purpose**: Check permissions via Permit.io
- **Methods**:
  - `check(userId, action, resource)` - Check permission
  - `checkWithAgent(userId, agentId, action, resource)` - Check with agent context
- **Location**: `hms-common-lib/src/main/java/com/hms/lib/common/security/PermissionService.java`

## Implementation Checklist

### ✅ Already Implemented
- [x] Permit.io SDK dependency added
- [x] PermissionService created
- [x] Permission checks in controllers
- [x] JWT authentication filter (extracts user/org from JWT)
- [x] PermitSyncService created

### 🔨 To Implement in Your HMS Application

1. **User Management Controller**
   ```java
   @RestController
   @RequestMapping("/api/admin")
   public class UserManagementController {
       private final ScalekitClient scalekitClient;
       private final PermitSyncService permitSyncService;
       
       @PostMapping("/users")
       public ResponseEntity<UserResponse> createUser(@RequestBody CreateUserRequest request) {
           // 1. Create in ScaleKit
           DirectoryUserResponse user = scalekitClient.directory().createUser(...);
           
           // 2. Sync to Permit.io
           permitSyncService.syncUser(user.getId(), user.getEmail(), ...);
           
           return ResponseEntity.ok(...);
       }
   }
   ```

2. **Organization Management**
   ```java
   @PostMapping("/organizations")
   public ResponseEntity<OrganizationResponse> createOrganization(...) {
       // 1. Create in ScaleKit
       DirectoryOrganizationResponse org = scalekitClient.directory().createOrganization(...);
       
       // 2. Sync to Permit.io
       permitSyncService.syncOrganization(org.getId(), org.getName());
       
       return ResponseEntity.ok(...);
   }
   ```

3. **Role Assignment**
   ```java
   @PostMapping("/users/{userId}/roles")
   public ResponseEntity<Void> assignRole(...) {
       // 1. Assign in ScaleKit
       scalekitClient.directory().assignRole(userId, roleName, orgId);
       
       // 2. Sync to Permit.io
       permitSyncService.assignRole(userId, roleName, orgId);
       
       return ResponseEntity.ok().build();
   }
   ```

## What Gets Configured Where

### In Your HMS Application (Code)
- ✅ User Management UI (your existing implementation)
- ✅ User Management Controller (calls ScaleKit SDK)
- ✅ Automatic Permit.io sync (via PermitSyncService)

### In Permit.io Dashboard (Manual Configuration)
- ✅ **Resources**: `workflow_process`, `patient_record`, etc.
- ✅ **Roles**: `admin`, `clinician`, `auditor`, `ai_agent`
- ✅ **Policies**: Rules connecting roles → resources → actions

### In ScaleKit (Automatic via SDK)
- ✅ Users (created via SDK)
- ✅ Organizations (created via SDK)
- ✅ Role assignments (created via SDK)
- ✅ JWT tokens (issued automatically)

## Example: Complete User Creation Flow

```java
// 1. Admin creates user via HMS UI
POST /api/admin/users
{
  "email": "doctor@hospital.com",
  "firstName": "John",
  "lastName": "Doe",
  "organizationId": "org_123",
  "role": "clinician"
}

// 2. Backend creates in ScaleKit
DirectoryUserResponse user = scalekitClient.directory()
    .createUser(new CreateUserRequest()
        .withEmail("doctor@hospital.com")
        .withFirstName("John")
        .withLastName("Doe")
    );
// Returns: userId = "user_456"

// 3. Backend syncs to Permit.io
permitSyncService.syncUser("user_456", "doctor@hospital.com", "John", "Doe");
// Permit.io creates user

// 4. Backend assigns role in ScaleKit
scalekitClient.directory().assignRole("user_456", "clinician", "org_123");

// 5. Backend syncs role to Permit.io
permitSyncService.assignRole("user_456", "clinician", "org_123");
// Permit.io assigns role "clinician" to user in workspace "org_123"

// 6. User logs in
// ScaleKit issues JWT: { "sub": "user_456", "org_id": "org_123" }

// 7. User makes API call
POST /api/v1/onboarding/start
Authorization: Bearer <JWT>

// 8. Permission check
permissionService.check("user_456", "create", resource("workflow_process", "org_123"))
// Permit.io: Checks role "clinician" → Policy allows → ALLOW

// 9. Request proceeds
```

## Key Points

1. **No ScaleKit Dashboard**: Everything is programmatic via Java SDK
2. **Automatic Sync**: When you create/update in ScaleKit, sync to Permit.io automatically
3. **ScaleKit = Source of Truth**: Always create in ScaleKit first, then sync to Permit.io
4. **Permit.io = Authorization**: Only makes permission decisions, doesn't manage identity
5. **Role Names**: Use same role names in both ScaleKit and Permit.io (e.g., "admin", "clinician")

## Next Steps

1. **Review your existing User Management implementation** in the HMS repo
2. **Integrate PermitSyncService** into your user creation/update flows
3. **Configure Permit.io Dashboard** with resources, roles, and policies
4. **Test the complete flow**: Create user → Sync → Login → Permission check

## Documentation Files

- `SCALEKIT_PERMIT_INTEGRATION_PROGRAMMATIC.md` - Detailed implementation guide
- `SCALEKIT_PERMIT_QUICK_REFERENCE.md` - Quick reference
- `SCALEKIT_PERMIT_INTEGRATION.md` - Original integration guide (dashboard approach)

