# Copilot Instructions for CPAN::Changes::Parser::KeepAChangeLog

## Repository Overview

This is a Perl module that parses Keep a Changelog 1.1.0-formatted markdown files and converts them to CPAN::Changes specification format. The parser extends `CPAN::Changes::Parser` base class using Moo object system.

**Key Information:**
- **Language:** Perl (pure Perl, no XS/C)
- **Minimum Perl Version:** 5.26 (tested up to 5.42)
- **Object System:** Moo
- **Testing Framework:** Test::More
- **CI/CD:** GitHub Actions with PerlToolsTeam reusable workflows

## Build and Test Instructions

### No Build Step Required
This is a pure Perl module with no compilation or build step. There is no Makefile.PL, dist.ini, or cpanfile.

### Running Tests Locally
```bash
# Run tests directly with Perl
perl -Ilib t/basic.t

# The -I flag adds lib/ to @INC so the module can be found
# Always use -Ilib when running tests locally
```

### CI Validation
Tests run automatically on push to `master` or on pull requests via GitHub Actions:
- **Test Matrix:** Perl versions 5.26, 5.28, 5.30, 5.32, 5.34, 5.36, 5.38, 5.40, 5.42
- **Jobs:** 
  - `cpan-test.yml` - Main test suite across all Perl versions
  - `cpan-coverage.yml` - Code coverage analysis
  - `cpan-perlcritic.yml` - Static code analysis (Perl::Critic)

All CI jobs use PerlToolsTeam's reusable workflows from `.github/workflows/perltest.yml`.

### Expected Test Behavior
- Tests should pass quickly (< 5 seconds)
- Two subtests in `t/basic.t`:
  1. Basic Keep a Changelog parsing validation
  2. Non-KaC format rejection (returns undef)
- No warnings should be emitted during tests

## Project Layout

### Directory Structure
```
.
├── .github/
│   ├── workflows/
│   │   ├── perltest.yml      # CI testing workflow
│   │   └── perlrelease.yml   # CPAN release workflow
│   └── dependabot.yml        # Dependency updates config
├── lib/
│   └── CPAN/Changes/Parser/
│       └── KeepAChangeLog.pm # Main parser module (only code file)
└── t/
    └── basic.t               # Test suite (only test file)
```

### Key Files
- **Main Module:** `lib/CPAN/Changes/Parser/KeepAChangeLog.pm`
  - Extends `CPAN::Changes::Parser`
  - Uses Moo for OO
  - Main public method: `parse_string($string)`
  - Returns `CPAN::Changes` object or undef

- **Test File:** `t/basic.t`
  - Uses Test::More with subtests
  - Tests both successful parsing and rejection of non-KaC formats
  - Helper functions: `_walk_entries`, `_find_entry_by_text`

### Dependencies
**Runtime:**
- Moo (object system)
- CPAN::Changes::Parser (parent class)

**Testing:**
- Test::More (core module, no installation needed)

## Code Style and Conventions

### Perl Conventions
- Use `strict` and `warnings` pragmas
- Moo attribute syntax for object properties
- Private functions prefixed with underscore (e.g., `_kac_to_cpan_changes_spec`)
- Snake_case for function names
- Regex matching with `qr//` for compiled patterns

### Testing Conventions
- Use `subtest` to organize related tests
- Use `done_testing` at end of subtests and main test file
- Provide diagnostic messages with `diag()` on failures
- Early return with `done_testing` if critical assertions fail

### Comments
- Focus comments on "why" not "what"
- Explain regex patterns and format transformations
- Document return values (especially undef cases)

## Common Tasks

### Making Code Changes
1. Modify `lib/CPAN/Changes/Parser/KeepAChangeLog.pm`
2. Run test: `perl -Ilib t/basic.t`
3. Ensure no warnings or errors
4. Commit changes - CI will run automatically

### Adding Tests
1. Edit `t/basic.t`
2. Add new subtests following existing patterns
3. Use `_walk_entries` helper for nested entry validation
4. Test locally before committing

### Release Process
The release workflow (`.github/workflows/perlrelease.yml`) is triggered manually via workflow_dispatch and uses davorg's CPAN release automation.

## Important Notes

- **Always run tests with `-Ilib` flag** when running locally
- The parser returns `undef` for non-Keep a Changelog formatted input (this is intentional, not an error)
- Link reference definitions (e.g., `[1.0.0]: https://...`) at bottom of changelog files are intentionally stripped during parsing
- The "Unreleased" section is a special version that maps to date "Not Released"
- Trust these instructions - all commands have been validated to work correctly
