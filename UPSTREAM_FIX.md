# Upstream Workflow Fix Required

## Summary

This document describes the precise fix required in the `PerlToolsTeam/github_workflows` repository to enable Windows testing with the MSYS Perl environment.

## Problem Statement

When running Perl tests on Windows using Git Bash (MSYS environment), the `PERL5LIB` environment variable is incorrectly parsed, causing module installation failures with the error:

```
! No MYMETA file is found after configure. Your toolchain is too old?
```

## Root Cause

### The Issue in Detail

1. **Environment Setup**: The `shogo82148/actions-setup-perl@v1` action sets `PERL5LIB` with Windows-style paths:
   ```
   PERL5LIB=D:\a\cpan-changes-parser-keepachangelog\cpan-changes-parser-keepachangelog\local\lib\perl5;D:\a\cpan-changes-parser-keepachangelog\cpan-changes-parser-keepachangelog\local\lib\perl5\MSWin32-x64-multi-thread;...
   ```

2. **MSYS Perl Interpretation**: When Perl runs in the MSYS environment (via `shell: bash`), it expects Unix-style paths with colons as separators. Instead, it receives Windows paths with semicolons, causing incorrect parsing:
   ```perl
   @INC:
       D
       \a\cpan-changes-parser-keepachangelog\cpan-changes-parser-keepachangelog\local\lib\perl5;D
       \a\cpan-changes-parser-keepachangelog\cpan-changes-parser-keepachangelog\local\lib\perl5\MSWin32-x64-multi-thread;D
       ...
   ```

3. **Result**: Perl cannot find modules in `@INC`, including `ExtUtils::MakeMaker` specified in `CONFIGURE_REQUIRES`.

### Why This Happens

- **MSYS Perl** (used in Git Bash on Windows) expects Unix-style paths: `/d/a/path` separated by colons (`:`)
- **Actions Setup Perl** sets Windows-style paths: `D:\a\path` separated by semicolons (`;`)
- **Path Parsing**: MSYS Perl splits on colons, but the entire `PERL5LIB` becomes one malformed entry that gets further mangled

## Precise Fix Required

### Affected Repository
`PerlToolsTeam/github_workflows`

### Affected File
`.github/actions/cpan-test/action.yml`

### Solution Option 1: Path Conversion (Preferred)

Add a new step **after** "Set up perl" and **before** "Perl version":

```yaml
- name: Set up perl
  uses: shogo82148/actions-setup-perl@v1
  with:
    perl-version: ${{ inputs.perl_version }}

# NEW STEP - Add this
- name: Fix PERL5LIB for MSYS on Windows
  if: ${{ startsWith(inputs.os, 'windows') }}
  shell: bash
  run: |
    # Convert Windows paths to MSYS paths and semicolons to colons
    if [ -n "$PERL5LIB" ]; then
      echo "Original PERL5LIB: $PERL5LIB"
      
      # Split on semicolons, convert each path, rejoin with colons
      NEW_PERL5LIB=""
      IFS=';' read -ra PATHS <<< "$PERL5LIB"
      for path in "${PATHS[@]}"; do
        # Convert Windows path (D:\path) to MSYS path (/d/path)
        msys_path=$(cygpath -u "$path" 2>/dev/null || echo "$path")
        if [ -n "$NEW_PERL5LIB" ]; then
          NEW_PERL5LIB="$NEW_PERL5LIB:$msys_path"
        else
          NEW_PERL5LIB="$msys_path"
        fi
      done
      
      # Update environment
      echo "PERL5LIB=$NEW_PERL5LIB" >> $GITHUB_ENV
      echo "Converted PERL5LIB to MSYS format: $NEW_PERL5LIB"
    fi

- name: Perl version
  run: perl -V
  shell: bash
```

### Solution Option 2: Use PowerShell on Windows (Simpler Alternative)

Change the shell for Windows-specific steps to use PowerShell instead of bash:

```yaml
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

- name: Run tests with make
  if: steps.configure-with-eumm.outcome == 'success'
  run: |
    make TEST_VERBOSE=1 test
  shell: ${{ startsWith(inputs.os, 'windows') && 'powershell' || 'bash' }}
```

**Rationale**: PowerShell natively understands Windows paths, avoiding the MSYS path translation issue entirely.

## Testing the Fix

### Test Case
1. Use a CPAN module with `CONFIGURE_REQUIRES` dependencies
2. Run on `windows-latest` runner with Perl 5.38
3. Verify module installation succeeds
4. Verify tests run successfully

### Validation Commands
```bash
# After fix is applied, these should work:
perl -V                    # Should show correct @INC paths
cpanm --installdeps .      # Should successfully install dependencies
perl Makefile.PL           # Should find ExtUtils::MakeMaker
make test                  # Should run tests
```

## Impact of Fix

### Benefits
- ✅ Enables Windows testing in GitHub Actions workflows
- ✅ Maintains compatibility with Unix systems (macOS, Linux)
- ✅ No changes required in consumer repositories
- ✅ Resolves path handling issues in MSYS environment

### Risks
- Minimal - only affects Windows runners
- Path conversion is standard operation in MSYS environment
- Fallback behavior if conversion fails

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
- **Error Log**: Shows `@INC` being split incorrectly at backslashes
- **MSYS Documentation**: https://www.msys2.org/docs/path-conversion/
- **cygpath utility**: Used for Windows-to-MSYS path conversion

## Contact

For questions about this fix, please contact the maintainers of:
- `PerlToolsTeam/github_workflows` (for implementing the fix)
- `davorg-cpan/cpan-changes-parser-keepachangelog` (for the original issue report)
