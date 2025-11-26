# How to Verify ScaleKit SDK Package Names

## Quick Reference

When you see compilation errors like:
```
package com.scalekit.grpc.scalekit.v1.directories does not exist
```

This means your `import` statements don't match the actual package structure in the installed JAR file.

## Step-by-Step Verification in VS Code

### 1. Open JAVA PROJECTS View

- Look in the **left sidebar** of VS Code
- Find the **"JAVA PROJECTS"** section
- If you don't see it, install the **"Extension Pack for Java"** extension

### 2. Navigate to Maven Dependencies

1. Expand your project name in JAVA PROJECTS
2. Expand **"Maven Dependencies"** (or **"Referenced Libraries"**)
3. Look for `scalekit-sdk-java` entry
   - Should show: `com.scalekit:scalekit-sdk-java:2.0.1` (or your version)

### 3. Inspect the JAR Structure

1. **Expand the JAR file** to see its internal folder structure
2. **Drill down** through the folders:
   ```
   com/
     scalekit/
       grpc/
         scalekit/
           v1/          ← Check this version number!
             directories/
               CreateUser.class
               CreateUserProfile.class
             organizations/
               CreateOrganization.class
               UpdateOrganizationMember.class
             authentication/
               AuthenticationResponse.class
               IdTokenClaims.class
   ```

3. **Note the version**: Is it `v1`, `v2`, or something else?

### 4. Match Your Code Imports

Your Java code must import from the **exact path** shown in the JAR:

**If JAR shows `v1`:**
```java
import com.scalekit.grpc.scalekit.v1.directories.CreateUser;
import com.scalekit.grpc.scalekit.v1.organizations.CreateOrganization;
```

**If JAR shows `v2`:**
```java
import com.scalekit.grpc.scalekit.v2.directories.CreateUser;
import com.scalekit.grpc.scalekit.v2.organizations.CreateOrganization;
```

### 5. Use IDE Auto-Import

1. **Delete the incorrect import** line
2. **Type the class name** (e.g., `CreateUser`)
3. **Press Ctrl+Space** (Windows/Linux) or **Cmd+Space** (Mac)
4. **Select the correct import** from the suggestions
5. The IDE will show you the exact package path

## Common Issues and Fixes

### Issue: "package does not exist" Error

**Cause**: Import path doesn't match JAR structure

**Fix**:
1. Check JAR structure in JAVA PROJECTS view
2. Update all `import` statements to match
3. Use find-and-replace to change `v1` → `v2` (if needed)

### Issue: Can't Find Classes

**Cause**: Classes might be in different packages

**Fix**:
1. Search for the class name in the JAR (use VS Code search)
2. Note the full package path
3. Update imports accordingly

### Issue: Multiple Versions in JAR

**Cause**: JAR might contain both `v1` and `v2` packages

**Fix**:
1. Check which version is recommended in SDK docs
2. Use the version that matches your SDK version
3. Be consistent across all imports

## Files That Need Package Verification

Check these files for correct imports:

1. **`UserManagementService.java`**:
   - `CreateUser`, `CreateUserProfile`
   - `CreateOrganization`
   - `UpdateOrganizationMember`

2. **`OidcCallbackController.java`**:
   - `AuthenticationResponse`
   - `IdTokenClaims`
   - `AuthenticationOptions`

## Verification Checklist

- [ ] Opened JAVA PROJECTS view in VS Code
- [ ] Found `scalekit-sdk-java` in Maven Dependencies
- [ ] Expanded JAR to see folder structure
- [ ] Noted version number (`v1`, `v2`, etc.)
- [ ] Checked all `import` statements match JAR structure
- [ ] Used IDE auto-import to verify correct paths
- [ ] Resolved all compilation errors
- [ ] Tested compilation succeeds

## Alternative: Command Line Verification

If you prefer command line:

```bash
# Navigate to your Maven repository
cd ~/.m2/repository/com/scalekit/scalekit-sdk-java/2.0.1/

# List JAR contents
jar -tf scalekit-sdk-java-2.0.1.jar | grep "CreateUser.class"

# Look for the package path
# Example output: com/scalekit/grpc/scalekit/v1/directories/CreateUser.class
```

The path shows: `com.scalekit.grpc.scalekit.v1.directories.CreateUser`

## Summary

**Key Takeaway**: Your `import` statements must **exactly match** the folder structure inside the JAR file. The version number (`v1`, `v2`) is the most common difference between SDK versions.

**Quick Fix**: Use VS Code's JAVA PROJECTS view to see the actual structure, then update your imports to match.

