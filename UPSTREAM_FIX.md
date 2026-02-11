# Upstream Workflow Fix Required

## Summary

This document describes the precise fix required in the `PerlToolsTeam/github_workflows` repository to enable Windows testing. **UPDATE**: Option 1 (path conversion) was implemented but still fails due to Perl binary incompatibility. **Option 2 (PowerShell) is the correct solution.**

## Problem Statement

When running Perl tests on Windows using Git Bash (MSYS environment), module installation fails with the error:

```
! No MYMETA file is found after configure. Your toolchain is too old?
```

## UPDATE: Why Option 1 (Path Conversion) Didn't Work

Option 1 was implemented and successfully converted paths, but the tests still fail. The logs show:

1. ✅ Path conversion works correctly: `D:\a\path` → `/d/a/path`
2. ✅ PERL5LIB is correctly set with colon separators
3. ✅ `@INC` shows correct paths

**BUT** the real problem is **incompatible Perl installations**:

- `actions-setup-perl` installs **Strawberry Perl** (MSWin32-x64-multi-thread)
- Git Bash uses **MSYS Perl** (x86_64-msys-thread-multi)
- These are **binary-incompatible** Perl distributions
- Modules compiled for Strawberry Perl cannot be used by MSYS Perl (different C runtimes, ABIs, and DLL formats)

Even with correct paths, MSYS Perl cannot load Strawberry Perl's compiled modules.

## Root Cause

### The Core Issue

When using `shell: bash` on Windows:
1. Git Bash provides an MSYS environment
2. Commands run in bash invoke **MSYS Perl** (x86_64-msys-thread-multi)
3. But `actions-setup-perl` installs **Strawberry Perl** (MSWin32-x64-multi-thread)
4. These are **different, binary-incompatible Perl distributions**

### Binary Incompatibility Details

- **MSYS Perl**: Built for MSYS2 environment with MSYS2 runtime libraries
- **Strawberry Perl**: Built for native Windows with MSVCRT runtime libraries
- **Problem**: XS modules (compiled C extensions) are incompatible between distributions
  - Different C runtime libraries (libmsys-2.0.a vs MSVCRT)
  - Different binary interfaces and calling conventions
  - Different DLL formats and dependencies
  - Different architecture identifiers in module directories

### Why Path Conversion Alone Isn't Enough

Path conversion (Option 1) fixes `@INC` parsing but doesn't solve the fundamental problem:
- ❌ MSYS Perl still cannot load Strawberry Perl's compiled modules
- ❌ Binary incompatibility causes loading failures
- ❌ Even pure-Perl modules may have dependencies on XS modules
- ❌ The module installation directories don't match expected architecture

## Precise Fix Required

### Affected Repository
`PerlToolsTeam/github_workflows`

### Affected File
`.github/actions/cpan-test/action.yml`

### **CORRECT Solution: Use PowerShell on Windows (Option 2)**

**Remove the path conversion step** and **change all Windows commands to use PowerShell instead of bash**.

This ensures that Windows uses the correct Perl installation (Strawberry Perl) that was installed by `actions-setup-perl`.

#### Changes Required:

```yaml
- name: Set up perl
  uses: shogo82148/actions-setup-perl@v1
  with:
    perl-version: ${{ inputs.perl_version }}

# REMOVE the "Fix PERL5LIB for MSYS on Windows" step entirely

- name: Perl version
  run: perl -V
  shell: ${{ startsWith(inputs.os, 'windows') && 'powershell' || 'bash' }}

- name: Install modules
  run: |
    cpanm --notest --with-configure --with-develop --no-man-pages --installdeps .
  shell: ${{ startsWith(inputs.os, 'windows') && 'powershell' || 'bash' }}

- name: Configure with Makefile.PL
  id: configure-with-eumm
  if: ${{ hashFiles('Makefile.PL') != '' }}
  run: |
    perl Makefile.PL
    make
  shell: ${{ startsWith(inputs.os, 'windows') && 'powershell' || 'bash' }}

- name: Configure with Build.PL
  id: configure-with-mb
  if: ${{ hashFiles('Build.PL') != '' }}
  run: |
    perl Build.PL
    ./Build
  shell: ${{ startsWith(inputs.os, 'windows') && 'powershell' || 'bash' }}

- name: Run tests with make
  if: steps.configure-with-eumm.outcome == 'success'
  run: |
    make TEST_VERBOSE=1 test
  shell: ${{ startsWith(inputs.os, 'windows') && 'powershell' || 'bash' }}

- name: Run tests with ./Build
  if: steps.configure-with-mb.outcome == 'success'
  run: |
    ./Build verbose=1 test
  shell: ${{ startsWith(inputs.os, 'windows') && 'powershell' || 'bash' }}
```

#### Why This Works:

- ✅ PowerShell natively invokes Strawberry Perl (the one installed by `actions-setup-perl`)
- ✅ No MSYS Perl involved - no architecture mismatch
- ✅ Windows paths work natively in PowerShell - no conversion needed
- ✅ All Perl commands use the same Perl installation
- ✅ Simpler than path conversion approach
- ✅ Standard practice for Windows Perl CI

## Testing the Fix

### Test Case
1. Use a CPAN module with `CONFIGURE_REQUIRES` dependencies
2. Run on `windows-latest` runner with Perl 5.38
3. Use PowerShell shell
4. Verify module installation succeeds
5. Verify tests run successfully

### Validation Commands (PowerShell on Windows)
```powershell
perl -V                    # Should show MSWin32 (Strawberry Perl)
cpanm --installdeps .      # Should successfully install dependencies
perl Makefile.PL           # Should find ExtUtils::MakeMaker
make test                  # Should run tests
```

### What NOT to Do
```bash
# This will invoke MSYS Perl and fail due to binary incompatibility
bash -c "perl -V"          # Shows x86_64-msys-thread-multi
bash -c "cpanm --installdeps ."  # Cannot use Strawberry Perl modules
```

## Impact of Fix

### Benefits
- ✅ Enables Windows testing in GitHub Actions workflows
- ✅ Uses the correct Perl installation (Strawberry Perl)
- ✅ Maintains compatibility with Unix systems (macOS, Linux)
- ✅ No path conversion complexity needed
- ✅ Simpler and more maintainable
- ✅ Faster (no extra conversion step)
- ✅ Standard practice for Windows Perl CI

### What Changed from Previous Recommendation
- ❌ **Option 1 (path conversion)** was implemented but doesn't work due to binary incompatibility
- ✅ **Option 2 (PowerShell)** is the correct solution and should be implemented instead
- The path conversion step should be **removed** as it adds complexity without solving the real problem

## Current Workaround

Until the upstream fix is applied, consumers can exclude Windows from the OS matrix:

```yaml
jobs:
  build:
    uses: PerlToolsTeam/github_workflows/.github/workflows/cpan-test.yml@main
    with:
      perl_version: "['5.38']"
      os: "['macos-latest', 'ubuntu-latest']"  # Excludes windows-latest
```

## References

- **Issue**: CI Error on Windows in davorg-cpan/cpan-changes-parser-keepachangelog
- **Error Log**: Shows binary incompatibility between MSYS Perl and Strawberry Perl
- **Key Finding**: Path conversion works, but MSYS Perl cannot use Strawberry Perl modules
- **Evidence**:
  - First `perl -V`: MSWin32-x64-multi-thread (Strawberry Perl via PowerShell)
  - Second `perl -V`: x86_64-msys-thread-multi (MSYS Perl via bash)
  - These are incompatible binary distributions

## Technical Deep Dive

### Why Two Perl Installations Exist

On Windows GitHub Actions runners with Git Bash:
1. **Strawberry Perl** is installed in `C:/hostedtoolcache/windows/perl/...`
   - Native Windows Perl distribution
   - Used when running commands in PowerShell or CMD
   - Modules installed via `cpanm` go to this Perl

2. **MSYS Perl** is installed in `/usr/bin/perl` (MSYS2 environment)
   - Part of Git Bash / MSYS2 installation
   - Used when running commands in bash shell
   - Has its own separate module directories

### The Binary Incompatibility

```
Strawberry Perl Module:
- Compiled against: MSVCRT, Windows API
- Architecture: MSWin32-x64-multi-thread
- Module path: .../MSWin32-x64-multi-thread/...
- DLL dependencies: Windows system DLLs

MSYS Perl Module:
- Compiled against: MSYS2 runtime (libmsys-2.0.a)
- Architecture: x86_64-msys-thread-multi  
- Module path: .../x86_64-msys-thread-multi/...
- DLL dependencies: MSYS2 runtime DLLs
```

These cannot be mixed - loading a Strawberry module in MSYS Perl will fail at the DLL loading stage.

### Why PowerShell is the Solution

PowerShell is the native Windows shell that:
- Correctly invokes Strawberry Perl (via PATH)
- Uses Windows-native path handling
- Doesn't involve MSYS2 or its Perl
- Is the standard environment for Windows Perl development

## Contact

For questions about this fix, please contact the maintainers of:
- `PerlToolsTeam/github_workflows` (for implementing the fix)
- `davorg-cpan/cpan-changes-parser-keepachangelog` (for the original issue report)
