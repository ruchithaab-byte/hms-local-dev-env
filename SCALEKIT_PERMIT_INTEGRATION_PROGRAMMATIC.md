# ScaleKit Java SDK + Permit.io Integration (Programmatic Approach)

## Overview

This document explains how to integrate ScaleKit Java SDK (programmatic user/org/role management) with Permit.io for authorization in your HMS application.

## Architecture: Programmatic Management

```
┌─────────────────────────────────────────────────────────────────┐
│              HMS Application User Management UI                  │
│  (Admin creates users, orgs, assigns roles via UI)              │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       │ HTTP Request
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│              HMS Backend Service                                 │
│                                                                   │
│  1. User Management Controller                                   │
│     - POST /api/users (create user)                              │
│     - POST /api/organizations (create org)                      │
│     - POST /api/users/{id}/roles (assign role)                  │
│                                                                   │
│  2. Calls ScaleKit Java SDK                                      │
│     - scalekitClient.directory().createUser(...)                  │
│     - scalekitClient.directory().createOrganization(...)         │
│     - scalekitClient.directory().assignRole(...)                 │
│                                                                   │
│  3. Syncs to Permit.io (via PermitSyncService)                   │
│     - permitSyncService.syncUser(...)                            │
│     - permitSyncService.syncOrganization(...)                    │
│     - permitSyncService.assignRole(...)                          │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       │ ScaleKit API
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ScaleKit (Identity Provider)                  │
│  - Stores users, organizations, roles                           │
│  - Issues JWT tokens with claims                                │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       │ Permit.io API
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Permit.io (Authorization)                    │
│  - Stores users, workspaces, role assignments                  │
│  - Makes permission decisions                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Key Difference: No Dashboard, All Programmatic

Unlike the traditional approach where admins use ScaleKit dashboard, in your HMS application:

- ✅ **Users are created** via ScaleKit Java SDK: `scalekitClient.directory().createUser(...)`
- ✅ **Organizations are created** via ScaleKit Java SDK: `scalekitClient.directory().createOrganization(...)`
- ✅ **Roles are assigned** via ScaleKit Java SDK: `scalekitClient.directory().assignRole(...)`
- ✅ **All happens in your HMS User Management UI** → Backend → ScaleKit SDK → Permit.io Sync

## Implementation Pattern

### Step 1: User Management Controller

Create a controller that handles user/org/role management:

```java
@RestController
@RequestMapping("/api/admin")
public class UserManagementController {

    private final ScalekitClient scalekitClient;
    private final PermitSyncService permitSyncService;

    @PostMapping("/users")
    public ResponseEntity<UserResponse> createUser(@RequestBody CreateUserRequest request) {
        // 1. Create user in ScaleKit via Java SDK
        DirectoryUserResponse scalekitUser = scalekitClient.directory()
            .createUser(new CreateUserRequest()
                .withEmail(request.getEmail())
                .withFirstName(request.getFirstName())
                .withLastName(request.getLastName())
            );

        String userId = scalekitUser.getId();
        String email = scalekitUser.getEmail();

        // 2. Sync user to Permit.io
        permitSyncService.syncUser(
            userId,
            email,
            request.getFirstName(),
            request.getLastName()
        );

        return ResponseEntity.ok(new UserResponse(userId, email));
    }

    @PostMapping("/organizations")
    public ResponseEntity<OrganizationResponse> createOrganization(
            @RequestBody CreateOrganizationRequest request) {
        
        // 1. Create organization in ScaleKit
        DirectoryOrganizationResponse scalekitOrg = scalekitClient.directory()
            .createOrganization(new CreateOrganizationRequest()
                .withName(request.getName())
            );

        String orgId = scalekitOrg.getId();
        String orgName = scalekitOrg.getName();

        // 2. Sync organization to Permit.io (as workspace)
        permitSyncService.syncOrganization(orgId, orgName);

        return ResponseEntity.ok(new OrganizationResponse(orgId, orgName));
    }

    @PostMapping("/users/{userId}/roles")
    public ResponseEntity<Void> assignRole(
            @PathVariable String userId,
            @RequestBody AssignRoleRequest request) {
        
        String roleName = request.getRoleName();
        String orgId = request.getOrgId();

        // 1. Assign role in ScaleKit
        scalekitClient.directory()
            .assignRole(userId, roleName, orgId);

        // 2. Sync role assignment to Permit.io
        permitSyncService.assignRole(userId, roleName, orgId);

        return ResponseEntity.ok().build();
    }
}
```

### Step 2: PermitSyncService

The `PermitSyncService` (already created) handles syncing to Permit.io:

```java
@Service
public class PermitSyncService {
    
    // Syncs user from ScaleKit to Permit.io
    public boolean syncUser(String userId, String email, String firstName, String lastName);
    
    // Syncs organization from ScaleKit to Permit.io (as workspace)
    public boolean syncOrganization(String orgId, String orgName);
    
    // Assigns role to user in workspace
    public boolean assignRole(String userId, String roleName, String orgId);
    
    // Removes role from user
    public boolean removeRole(String userId, String roleName, String orgId);
}
```

### Step 3: Permission Checks

When users make API calls, permission checks work the same way:

```java
@PostMapping("/api/v1/onboarding/start")
public ResponseEntity<OnboardingResponse> startOnboarding(@RequestBody Request req) {
    // Extract from JWT (set by JwtAuthenticationFilter)
    String userId = UserContext.getUserId();  // From ScaleKit
    String orgId = TenantContext.getTenantId(); // From ScaleKit

    // Check permission via Permit.io
    Resource resource = permissionService.buildResource("workflow_process", null, orgId);
    boolean permitted = permissionService.check(userId, "create", resource);

    if (!permitted) {
        throw new AccessDeniedException("Not authorized");
    }

    // Proceed with business logic
    ...
}
```

## Complete Flow Example

### Scenario: Admin Creates a New User

```
1. Admin opens HMS User Management UI
   → Fills form: email="doctor@hospital.com", firstName="John", lastName="Doe"
   → Selects organization: "Hospital A"
   → Selects role: "clinician"
   → Clicks "Create User"

2. Frontend calls: POST /api/admin/users
   {
     "email": "doctor@hospital.com",
     "firstName": "John",
     "lastName": "Doe",
     "organizationId": "org_123",
     "role": "clinician"
   }

3. Backend (UserManagementController):
   a. Creates user in ScaleKit:
      scalekitClient.directory().createUser(...)
      → Returns: userId="user_456"
   
   b. Syncs user to Permit.io:
      permitSyncService.syncUser("user_456", "doctor@hospital.com", "John", "Doe")
      → Permit.io creates user
   
   c. Assigns role in ScaleKit:
      scalekitClient.directory().assignRole("user_456", "clinician", "org_123")
   
   d. Syncs role to Permit.io:
      permitSyncService.assignRole("user_456", "clinician", "org_123")
      → Permit.io assigns role "clinician" to user in workspace "org_123"

4. User logs in:
   → ScaleKit issues JWT: { "sub": "user_456", "org_id": "org_123" }
   → User makes API call
   → Permission check: Can user_456 create workflow_process in org_123?
   → Permit.io: Checks role "clinician" → Policy allows → ALLOW
```

## ScaleKit Java SDK Methods

### Creating Users

```java
// Create user
DirectoryUserResponse user = scalekitClient.directory()
    .createUser(new CreateUserRequest()
        .withEmail("user@example.com")
        .withFirstName("John")
        .withLastName("Doe")
    );

String userId = user.getId();
```

### Creating Organizations

```java
// Create organization
DirectoryOrganizationResponse org = scalekitClient.directory()
    .createOrganization(new CreateOrganizationRequest()
        .withName("Hospital A")
    );

String orgId = org.getId();
```

### Assigning Roles

```java
// Assign role to user in organization
scalekitClient.directory()
    .assignRole(userId, "clinician", orgId);
```

### Updating Users

```java
// Update user
scalekitClient.directory()
    .updateUser(userId, new UpdateUserRequest()
        .withEmail("newemail@example.com")
    );
```

### Removing Roles

```java
// Remove role from user
scalekitClient.directory()
    .removeRole(userId, "clinician", orgId);
```

## Permit.io Configuration

### What You Configure in Permit.io Dashboard

Even though user/org/role management is programmatic via ScaleKit SDK, you still need to configure **policies** in Permit.io Dashboard:

1. **Resources**: Define what you protect
   - `workflow_process`
   - `patient_record`
   - etc.

2. **Roles**: Define authorization roles (should match ScaleKit role names)
   - `admin`
   - `clinician`
   - `auditor`
   - `ai_agent`

3. **Policies**: Define rules
   - "Users with role 'admin' can perform all actions on all resources"
   - "Users with role 'clinician' can 'read' and 'update' 'patient_record' in their workspace"

### What Gets Synced Automatically

- ✅ **Users**: Synced when created via ScaleKit SDK
- ✅ **Workspaces**: Synced when organizations created via ScaleKit SDK
- ✅ **Role Assignments**: Synced when roles assigned via ScaleKit SDK

## Error Handling

### ScaleKit SDK Fails

```java
try {
    DirectoryUserResponse user = scalekitClient.directory().createUser(...);
    // Success - continue with Permit.io sync
} catch (ScalekitException e) {
    // Handle ScaleKit error
    log.error("Failed to create user in ScaleKit", e);
    throw new UserCreationException("Failed to create user", e);
}
```

### Permit.io Sync Fails

```java
// Create in ScaleKit first (source of truth)
DirectoryUserResponse user = scalekitClient.directory().createUser(...);

// Try to sync to Permit.io (non-blocking)
boolean synced = permitSyncService.syncUser(...);
if (!synced) {
    // Log warning but don't fail the request
    // Can retry sync later via background job
    log.warn("Failed to sync user to Permit.io, will retry: userId={}", userId);
}
```

## Best Practices

1. **ScaleKit is Source of Truth**: Always create/update in ScaleKit first, then sync to Permit.io
2. **Idempotent Sync**: `PermitSyncService` uses `sync()` methods which are idempotent (safe to retry)
3. **Error Handling**: Don't fail user creation if Permit.io sync fails (can retry later)
4. **Role Name Consistency**: Use same role names in ScaleKit and Permit.io
5. **Background Sync**: Consider background job to retry failed Permit.io syncs

## Testing

### Test User Creation Flow

```java
@Test
public void testCreateUserAndSync() {
    // 1. Create user via ScaleKit SDK
    DirectoryUserResponse user = scalekitClient.directory()
        .createUser(new CreateUserRequest().withEmail("test@example.com"));
    
    // 2. Sync to Permit.io
    boolean synced = permitSyncService.syncUser(
        user.getId(), 
        user.getEmail(), 
        null, 
        null
    );
    
    assertTrue(synced);
    
    // 3. Verify in Permit.io
    UserRead permitUser = permit.api.users.get(user.getId());
    assertNotNull(permitUser);
    assertEquals(user.getEmail(), permitUser.getEmail());
}
```

## Summary

- ✅ **ScaleKit Java SDK**: Programmatic user/org/role management (no dashboard)
- ✅ **PermitSyncService**: Syncs identity data to Permit.io
- ✅ **PermissionService**: Checks permissions via Permit.io
- ✅ **User Management UI**: Your HMS UI → Backend → ScaleKit SDK → Permit.io

The key is: **Create in ScaleKit first, then sync to Permit.io automatically**.

