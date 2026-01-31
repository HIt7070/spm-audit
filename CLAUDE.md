# spm-audit

## Project Overview

`spm-audit` is a Swift command-line tool that audits Swift Package Manager (SPM) dependencies for available updates. It scans directories for `Package.swift` and `Package.resolved` files, checks GitHub for the latest releases, and presents a table showing which packages have updates available.

### Key Features

- Parallel update checking for fast performance
- Support for both direct and transitive dependencies
- Multiple version requirement types (exact, upToNextMajor, upToNextMinor, range, branch, revision)
- GitHub authentication support via `GITHUB_TOKEN` env var or `gh` CLI
- Table-formatted output with update status
- Excludes pre-release versions by default

## Architecture

### Core Components

1. **PackageUpdateChecker** (`main.swift:82-547`)
   - Main class orchestrating the audit process
   - Scans filesystem for package files
   - Coordinates parallel API requests
   - Generates formatted output

2. **Data Models**
   - `PackageInfo`: Represents a package with version and metadata
   - `GitHubRelease`: GitHub API release response
   - `PackageUpdateResult`: Result of checking a package for updates
   - `PackageResolved`: Parses Package.resolved JSON files

3. **Version Comparison** (`main.swift:501-528`)
   - Semantic version parsing and comparison
   - Handles version normalization (strips 'v' prefix)
   - Component-wise comparison with zero-padding

4. **CLI Interface** (`main.swift:551-577`)
   - Uses ArgumentParser for command-line parsing
   - Supports directory argument and `--all` flag
   - AsyncParsableCommand for async entry point

## Dependencies

- **swift-argument-parser** (v1.3.0+): CLI argument parsing and command structure
  - GitHub: https://github.com/apple/swift-argument-parser

## Project Structure

```
spm-audit/
├── Sources/
│   └── spm-audit/
│       └── main.swift          # All source code (CLI, models, logic)
├── Tests/
│   ├── Fixtures/               # Test fixtures for Package.swift and .pbxproj files
│   └── spm-audit-tests/        # Test target
├── Package.swift               # SPM manifest
└── Package.resolved            # Dependency lock file
```

## Building and Running

### Build

```bash
swift build
```

### Run

```bash
# Run from source
swift run spm-audit

# Run with directory argument
swift run spm-audit /path/to/project

# Include transitive dependencies
swift run spm-audit --all

# After building, run executable directly
.build/debug/spm-audit
```

### Install

```bash
swift build -c release
cp .build/release/spm-audit /usr/local/bin/
```

## Testing

### Run Tests

```bash
swift test
```

### Test Structure

Tests are located in `Tests/spm-audit-tests/` and use fixtures in `Tests/Fixtures/` for testing parsing logic.

The `PackageUpdateChecker` class exposes several public test helpers:
- `extractRequirementTypesPublic`: Tests Xcode project.pbxproj parsing
- `extractPackagesFromResolvedPublic`: Tests Package.resolved parsing
- `compareVersionsPublic`: Tests version comparison logic
- `normalizeVersionPublic`: Tests version normalization

## Releasing New Versions

When creating a new release, follow these steps to update both GitHub and the Homebrew tap:

### 1. Update Version Number

Edit `Sources/spm-audit/main.swift` and update the version constant:
```swift
let currentVersion = "0.1.2"  // Update this
```

Commit and push:
```bash
git add Sources/spm-audit/main.swift
git commit -m "Bump version to 0.1.2"
git push origin main
```

### 2. Create Git Tag and GitHub Release

```bash
# Create and push tag
git tag -a 0.1.2 -m "Release 0.1.2: Description"
git push origin 0.1.2

# Create GitHub release (update notes as needed)
gh release create 0.1.2 \
  --title "0.1.2 - Feature Name" \
  --notes "## What's New
- Feature 1
- Feature 2

## Installation
\`\`\`bash
brew upgrade rspoon3/tap/spm-audit
\`\`\`"
```

### 3. Update Homebrew Formula

Calculate the SHA256 for the new release:
```bash
curl -sL https://github.com/Rspoon3/spm-audit/archive/refs/tags/0.1.2.tar.gz | shasum -a 256
```

Update the formula in the `homebrew-tap` repository:
```bash
cd /tmp
git clone https://github.com/Rspoon3/homebrew-tap.git
cd homebrew-tap

# Edit Formula/spm-audit.rb:
# - Update url to new version
# - Update sha256 with calculated hash

git add Formula/spm-audit.rb
git commit -m "Update spm-audit to 0.1.2"
git push origin main
```

**Formula template:**
```ruby
class SpmAudit < Formula
  desc "Audit and update Swift Package Manager dependencies"
  homepage "https://github.com/Rspoon3/spm-audit"
  url "https://github.com/Rspoon3/spm-audit/archive/refs/tags/0.1.2.tar.gz"
  sha256 "NEW_SHA256_HERE"
  license "MIT"

  depends_on xcode: ["14.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/spm-audit"
  end

  test do
    system "#{bin}/spm-audit", "--version"
  end
end
```

### 4. Verify Release

Users can now update:
```bash
brew upgrade rspoon3/tap/spm-audit
```

The automatic version checker will notify users on the old version that a new release is available.

## Code Patterns and Conventions

### Swift Concurrency

- Uses modern Swift concurrency throughout (`async`/`await`)
- Parallel API requests via `TaskGroup` for performance
- Main entry point is `AsyncParsableCommand`

### Error Handling

- Graceful degradation: missing GitHub token falls back to unauthenticated requests
- API errors are collected and displayed in the results table
- File parsing errors are silently skipped (returns empty arrays)

### GitHub API Integration

- Uses GitHub REST API v3 (`/repos/{owner}/{repo}/releases`)
- Authentication via Bearer token (optional)
- Filters out pre-release versions
- Rate limiting considerations (parallel requests)

### Version Resolution

The tool discovers packages from multiple sources:
1. **Package.swift**: Direct regex matching for `exact: "x.y.z"` dependencies
2. **Package.resolved**: JSON parsing for all resolved versions
3. **project.pbxproj**: Extracts requirement types (^Major, ^Minor, etc.)

For Xcode projects, it correlates Package.resolved entries with project.pbxproj to determine:
- Direct vs transitive dependencies
- Version requirement type (exact, upToNextMajor, etc.)

## Development Guidelines

### Testing Requirements

**CRITICAL: Always run and verify unit tests before completing any task.**

- Run `swift test` after making any code changes
- Verify all tests pass before considering work complete
- Add new tests for new features or bug fixes
- Update existing tests when changing behavior
- Never skip or disable tests without explicit discussion

### Adding New Features

1. **New requirement types**: Add to `PackageInfo.RequirementType` enum and update parsing regex
2. **Additional package registries**: Extend URL matching and API integration
3. **Output formats**: Add new formatting functions alongside `printTable`

### Code Style

- Use Swift standard naming conventions
- Prefer explicit types for public APIs
- Use type inference for local variables
- Comment complex regex patterns and algorithms

### Performance Considerations

- Package checking runs in parallel (one task per package)
- Filesystem enumeration skips `.build/` directories
- Results are collected and sorted before display
- Duplicate packages (by URL) are filtered out

## Common Use Cases

### Check current directory
```bash
spm-audit
```

### Check specific project
```bash
spm-audit ~/Projects/MyApp
```

### Include all transitive dependencies
```bash
spm-audit --all
```

### Use with GitHub token for private repos
```bash
GITHUB_TOKEN=ghp_xxx spm-audit
# or use gh CLI
gh auth login
spm-audit
```

## Output Format

Results are displayed in a table with columns:
- **Package**: Package name (extracted from URL)
- **Type**: Version requirement type (Exact, ^Major, ^Minor, Range, Branch, Revision)
- **Current**: Currently resolved version
- **Latest**: Latest stable release on GitHub
- **Status**: ✅ Up to date, ⚠️ Update available, ⚠️ No releases, or ❌ Error

## Known Limitations

1. Only supports GitHub-hosted packages
2. Only checks GitHub Releases (not git tags without releases)
3. Requires packages to use semantic versioning
4. Skips pre-release versions
5. Package.swift parsing only matches `exact:` version constraints
6. Xcode project parsing requires specific project.pbxproj structure

## Troubleshooting

### "No packages found"
- Ensure you're in a directory with `Package.swift` or an Xcode project with SPM dependencies
- Check that packages use exact versions or are in Package.resolved

### API rate limiting
- Use GitHub authentication: `export GITHUB_TOKEN=your_token` or `gh auth login`
- Authenticated requests have higher rate limits (5000/hour vs 60/hour)

### "Could not parse GitHub URL"
- Only GitHub.com URLs are supported
- URL must follow format: `https://github.com/{owner}/{repo}`
