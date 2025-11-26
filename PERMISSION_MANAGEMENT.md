# Permission Management Guide

## Architecture Overview

The HMS platform implements a **Defense in Depth** authorization architecture with three layers:

1. **Ingress (Kong Gateway)**: Coarse-grained route-level checks via Permit.io PDP
2. **Mesh (Kuma)**: Zero-trust mTLS and service-to-service identity
3. **Application (Microservices)**: Fine-grained resource-level checks via Permit.io SDK + PDP sidecars

## Policy Modeling in Permit.io

### Resources

Define the following resources in your Permit.io Dashboard:

- `workspace`: Container for tenant data (maps to `org_id` from JWT)
- `workflow_process`: Flowable workflow process instance
- `patient_record`: Healthcare entity (for future use)
- `onboarding_request`: Onboarding request entity

### Roles (RBAC)

- `admin`: Full access to all resources in their workspace
- `clinician`: Read/update `patient_record` in their workspace
- `auditor`: Read-only access to logs and audit trails
- `ai_agent`: Special role for AI agents - can read but cannot delete
- `viewer`: Read-only access to non-sensitive resources

### Actions

- `create`: Create new resources
- `read`: Read/view resources
- `update`: Modify existing resources
- `delete`: Remove resources
- `execute`: Execute workflow processes

### Relationships (ReBAC)

- `patient_record` **belongs_to** `workspace`
- `workflow_process` **belongs_to** `workspace`
- `onboarding_request` **belongs_to** `workspace`
- User **member_of** `workspace`

**Policy Example**: "Allow `read` on `workflow_process` IF User is `member_of` the parent `workspace`"

### Agentic Policy Rules

Special policy for AI agents:
- "Allow `delete` ONLY IF `act` claim is NOT present OR `act.role == 'super_agent'`"
- Prevents standard AI agents from deleting data even if the user can

## Configuration

### Environment Variables

Add to your `.env` file:

```bash
PERMIT_API_KEY=your-permit-api-key
PERMIT_ENVIRONMENT=your-permit-environment-id
```

### Service Configuration

Each service automatically configures the Permit.io SDK using:
- `PERMIT_API_KEY`: API key from Permit.io dashboard
- `PERMIT_ENVIRONMENT`: Environment ID from Permit.io dashboard
- `PERMIT_PDP_URL`: URL of the PDP sidecar (default: `http://permit-pdp-{service}:7000`)

## Adding Permission Checks to Endpoints

### Method 1: Using @RequiresPermission Annotation

```java
@PostMapping("/start")
@RequiresPermission(action = "create", resourceType = "workflow_process")
public ResponseEntity<OnboardingResponse> startOnboarding(@RequestBody StartOnboardingRequest request) {
    // Your implementation
}
```

### Method 2: Explicit Permission Check

```java
@PostMapping("/start")
public ResponseEntity<OnboardingResponse> startOnboarding(@RequestBody StartOnboardingRequest request) {
    String userId = UserContext.getUserId();
    String tenantId = TenantContext.getTenantId();
    String agentId = UserContext.getAgentId();

    Resource resource = permissionService.buildResource("workflow_process", null, tenantId);
    boolean permitted = permissionService.checkWithAgent(userId, agentId, "create", resource);

    if (!permitted) {
        throw new AccessDeniedException("User/Agent not authorized to create workflow_process");
    }

    // Your implementation
}
```

## Agentic "On-Behalf-Of" Flow

When an AI agent acts on behalf of a user, the JWT contains:
- `sub`: The human user ID
- `act`: The agent ID (and optionally agent role)

The `JwtAuthenticationFilter` automatically extracts the `act` claim and stores it in `AgentContext`.

Permission checks consider both the user and agent:
- User must have the required permission
- Agent restrictions apply (e.g., standard agents cannot delete)

## Testing

Run the test script:

```bash
./test-permissions.sh
```

This tests:
1. Requests without JWT (should return 401)
2. Requests with invalid JWT (should return 401)
3. Requests with valid JWT but insufficient permissions (should return 403)
4. Requests with valid JWT and correct permissions (should return 200/202)

## Troubleshooting

### Permission checks are skipped

**Symptom**: Log shows "Permission check skipped - Permit.io not enabled"

**Solution**: 
1. Verify `PERMIT_API_KEY` and `PERMIT_ENVIRONMENT` are set in environment
2. Check that PDP sidecars are running: `docker ps | grep permit-pdp`
3. Verify PDP health: `curl http://localhost:7766/health`

### Permission denied for valid users

**Symptom**: Users with correct roles get 403 Forbidden

**Solution**:
1. Verify policies are configured in Permit.io Dashboard
2. Check that user roles are assigned in Permit.io
3. Verify resource relationships (e.g., user is `member_of` workspace)
4. Check PDP logs: `docker logs permit-pdp-workflow`

### Agent permissions not working

**Symptom**: Agent actions are denied even when user has permission

**Solution**:
1. Verify `act` claim is present in JWT
2. Check agent role policies in Permit.io
3. Ensure agent restrictions are correctly configured (e.g., delete prevention)

## Kong Gateway Integration

The Kong OPA plugin is configured but commented out in `kong/kong.yml`. To enable:

1. Install the `kong-opa` plugin (requires custom Kong image or Kong Enterprise)
2. Uncomment the OPA plugin configuration in `kong/kong.yml`
3. Restart Kong: `docker-compose restart kong`

The OPA plugin will forward requests to `permit-pdp-kong` for authorization before routing to services.

## Best Practices

1. **Fail Closed**: Always fail closed on permission errors (return 403, don't allow access)
2. **Log Everything**: Permission checks are logged for audit trails
3. **Cache Policies**: Permit.io PDP caches policies for performance
4. **Test Thoroughly**: Test all role combinations and agent scenarios
5. **Monitor PDP Health**: Set up alerts for PDP sidecar failures

## References

- [Permit.io Documentation](https://docs.permit.io)
- [Permit Java SDK](https://github.com/permitio/permit-sdk-java)
- [Kong OPA Plugin](https://docs.konghq.com/hub/kong-inc/opa/)

