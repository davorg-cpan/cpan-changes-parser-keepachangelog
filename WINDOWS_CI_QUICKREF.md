# Quick Reference: Windows CI Fix

## TL;DR

**Option 1 (path conversion) doesn't work because it still uses MSYS Perl, which is binary-incompatible with Strawberry Perl modules.**

**Use Option 2 (PowerShell) instead.**

## The Problem in One Sentence

Git Bash on Windows invokes MSYS Perl, which cannot load modules compiled for Strawberry Perl (installed by actions-setup-perl), even with correct paths.

## The Solution in One Sentence

Use PowerShell instead of bash on Windows - it uses Strawberry Perl natively.

## Exact Changes Needed in Upstream

File: `PerlToolsTeam/github_workflows/.github/actions/cpan-test/action.yml`

**Remove this step:**
```yaml
- name: Fix PERL5LIB for MSYS on Windows
  # ... entire step can be deleted
```

**Change shell for these steps:**
```yaml
- name: Perl version
  run: perl -V
  shell: ${{ startsWith(inputs.os, 'windows') && 'powershell' || 'bash' }}

- name: Install modules
  run: cpanm --notest --with-configure --with-develop --no-man-pages --installdeps .
  shell: ${{ startsWith(inputs.os, 'windows') && 'powershell' || 'bash' }}

- name: Configure with Makefile.PL
  run: |
    perl Makefile.PL
    make
  shell: ${{ startsWith(inputs.os, 'windows') && 'powershell' || 'bash' }}

- name: Run tests with make
  run: make TEST_VERBOSE=1 test
  shell: ${{ startsWith(inputs.os, 'windows') && 'powershell' || 'bash' }}
```

Apply the same pattern to all build/test steps.

## Why This Works

| Aspect | Bash (fails) | PowerShell (works) |
|--------|--------------|-------------------|
| Perl used | MSYS Perl | Strawberry Perl |
| Architecture | x86_64-msys-thread-multi | MSWin32-x64-multi-thread |
| Can use installed modules? | ❌ No | ✅ Yes |
| Path handling | Needs conversion | Native Windows |
| Complexity | High | Low |

## Evidence

Run logs show TWO different Perl installations are present:
1. Strawberry Perl (MSWin32) - the one with the modules
2. MSYS Perl (msys) - invoked by bash, can't use Strawberry modules

Path conversion fixes the paths but doesn't fix the binary incompatibility.

## Current Status

- This repository: Windows excluded from CI matrix (workaround)
- Upstream: Has path conversion implemented (doesn't solve the problem)
- Needed: Upstream should switch to PowerShell on Windows

## See Also

- `UPSTREAM_FIX.md` - Complete technical documentation
- Recent CI logs - Show the binary incompatibility in action
