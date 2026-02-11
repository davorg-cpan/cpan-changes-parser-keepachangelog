# Copilot Instructions for CPAN::Changes::Parser::KeepAChangeLog

## Repository Overview

This is a Perl module that parses changelog files in the "Keep a Changelog" format (https://keepachangelog.com/) and converts them into CPAN::Changes objects for use within the Perl ecosystem.

**Project Type**: Perl CPAN distribution  
**Primary Language**: Perl 5  
**Minimum Perl Version**: 5.010  
**Build System**: ExtUtils::MakeMaker (traditional Perl module build system)

## Key Dependencies

- **Moo**: Modern object-oriented framework for Perl
- **CPAN::Changes::Parser**: Base parser class that this module extends
- **Test::More**: Testing framework (test dependency)

## Build and Test Instructions

### Initial Setup

Dependencies are NOT included in the repository. To install dependencies:

```bash
# Install dependencies using cpanm (recommended)
cpanm --installdeps .

# OR using traditional CPAN
cpan -i Moo CPAN::Changes::Parser
```

### Standard Build Process

**Always follow this sequence:**

1. **Generate the Makefile** (required before any other make command):
   ```bash
   perl Makefile.PL
   ```
   Expected output: "Generating a Unix-style Makefile" with possible warnings about missing prerequisites if dependencies aren't installed.

2. **Build the distribution**:
   ```bash
   make
   ```
   This copies module files to `blib/` staging directory.

3. **Run tests**:
   ```bash
   make test
   ```
   **Note**: Tests will fail if dependencies (Moo, CPAN::Changes::Parser) are not installed. Install dependencies first.

4. **Clean build artifacts**:
   ```bash
   make clean
   ```
   Removes `blib/`, `Makefile`, and temporary files.

### Common Issues

- **"Can't locate Moo.pm"**: Dependencies not installed. Run `cpanm --installdeps .` first.
- **"No Makefile"**: Run `perl Makefile.PL` before any make command.
- **Test failures**: Always ensure dependencies are installed before running tests.

## Project Structure

```
.
├── lib/
│   └── CPAN/
│       └── Changes/
│           └── Parser/
│               └── KeepAChangeLog.pm    # Main module implementation
├── t/
│   └── basic.t                          # Test suite
├── .github/
│   └── workflows/
│       ├── perltest.yml                 # CI testing (multiple Perl versions)
│       └── perlrelease.yml              # CPAN release workflow
├── Changes                               # Project changelog (Keep a Changelog format)
├── Makefile.PL                          # Build configuration
├── MANIFEST                             # List of files to include in distribution
├── README.md                            # User documentation
└── LICENSE                              # Perl 5 license
```

## Continuous Integration

The project uses GitHub Actions with reusable workflows from PerlToolsTeam:

1. **CI Testing** (perltest.yml):
   - Runs on: push to main, pull requests
   - Tests against Perl versions: 5.26, 5.28, 5.30, 5.32, 5.34, 5.36, 5.38, 5.40, 5.42
   - Includes coverage analysis and perlcritic (style checker)

2. **Release** (perlrelease.yml):
   - Manual workflow dispatch only
   - Publishes to CPAN

**Important**: The CI workflows use reusable workflows that handle dependency installation automatically. Local development requires manual dependency installation.

## Module Architecture

**Main Module**: `lib/CPAN/Changes/Parser/KeepAChangeLog.pm`

- Extends `CPAN::Changes::Parser` using Moo
- Overrides `parse_string()` method to:
  1. Detect Keep a Changelog format (looks for `## [version]` or `## [Unreleased]`)
  2. Transform Markdown format to CPAN::Changes format
  3. Delegate to parent parser
- Returns `undef` if input is not Keep a Changelog format
- Handles:
  - Release headings: `## [version] - date` or `## [Unreleased]`
  - Category headings: `### Added`, `### Fixed`, etc.
  - Bullet points with `-` or `*`
  - Filters out link reference definitions

**Key Transformation Logic**: `_kac_to_cpan_changes_spec()` function converts:
- `## [1.0.0] - 2024-01-01` → `1.0.0 2024-01-01`
- `## [Unreleased]` → `Unreleased Not Released`
- `### Added` → `[Added]`
- Preserves bullets as `- text`

## Testing

**Test File**: `t/basic.t`

Tests two scenarios:
1. Valid Keep a Changelog input returns CPAN::Changes object
2. Non-Keep a Changelog input returns undef

**To run specific tests**:
```bash
prove -lv t/basic.t
```

**Test Dependencies**: Test::More (included in Perl core since 5.6.2)

## Code Style

- Perl 5 strict and warnings enabled
- POD documentation embedded in module file
- Follow existing code style (2-space indentation observed in module)
- No separate linter config file (uses perlcritic in CI with default settings)

## Development Workflow

1. Make changes to `lib/CPAN/Changes/Parser/KeepAChangeLog.pm`
2. Update `Changes` file following Keep a Changelog format
3. Run `perl Makefile.PL && make && make test` to validate
4. Ensure tests pass locally before pushing
5. CI will run tests on multiple Perl versions

## Important Notes for Code Changes

- **Always test with dependencies installed**: The module requires Moo and CPAN::Changes::Parser at runtime
- **Maintain backward compatibility**: Module is published to CPAN
- **Update POD documentation**: Keep inline documentation in sync with code changes
- **Follow Keep a Changelog**: Update the `Changes` file for all user-visible changes
- **Version numbering**: Update `$VERSION` in module file when releasing (follows semantic versioning)

## Files Not to Modify

- `MANIFEST`: Auto-managed by ExtUtils::MakeMaker
- `MYMETA.*`: Generated files (in .gitignore)
- `blib/`: Build artifact directory
- `Makefile`: Generated by Makefile.PL
