# Contributing to the LaunchDarkly Swift Observability SDK

LaunchDarkly has published an [SDK contributor's guide](https://docs.launchdarkly.com/sdk/concepts/contributors-guide) that provides a detailed explanation of how our SDKs work. See below for additional information on how to contribute to this SDK.

## Submitting bug reports and feature requests

The LaunchDarkly SDK team monitors the [issue tracker](https://github.com/launchdarkly/swift-launchdarkly-observability/issues) in the SDK repository. Bug reports and feature requests specific to this library should be filed in this issue tracker. The SDK team will respond to all newly filed issues within two business days.

## Submitting pull requests

We encourage pull requests and other contributions from the community. Before submitting pull requests, ensure that all temporary or unintended code is removed. Don't worry about adding reviewers to the pull request; the LaunchDarkly SDK team will add themselves. The SDK team will acknowledge all pull requests within two business days.

### Pull Request Title Format

All pull request titles must follow the [Conventional Commits](https://www.conventionalcommits.org/) format. This is enforced by our CI pipeline and is required for automated semantic versioning and changelog generation.

#### Format Structure:
```
<type>(<optional-scope>): <description>
```

#### Common Types:
- `feat:` - New features (triggers minor version bump)
- `fix:` - Bug fixes (triggers patch version bump)
- `docs:` - Documentation changes
- `style:` - Code style/formatting changes
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks
- `perf:` - Performance improvements
- `ci:` - CI/CD changes
- `build:` - Build system changes

#### Examples:
- `feat: add automatic crash reporting instrumentation`
- `fix: correct session timeout handling`
- `docs: update installation instructions`
- `refactor: simplify HTTP request instrumentation`

#### Breaking Changes:
To indicate a breaking change (major version bump), add `!` after the type:
- `feat!: change observability plugin API signature`

Or include `BREAKING CHANGE:` in the pull request body:
```
feat: update session management

BREAKING CHANGE: SessionOptions API has changed
```

## Build instructions

### Prerequisites

- Xcode 14.0 or later
- Swift 5.7 or later
- SwiftLint (optional, for linting)

### Setup

To install project dependencies:

```bash
# Clone the repository
git clone https://github.com/launchdarkly/swift-launchdarkly-observability.git
cd swift-launchdarkly-observability

# Open in Xcode
open Package.swift
```

### Build

To build the project:

```bash
swift build
```

### Testing

To run all unit tests:

```bash
swift test
```

Or use Xcode's test runner (⌘+U).

## Code organization

The library's structure is as follows:

* `Sources/` - Contains all SDK source code
  * `LaunchDarklyObservability/` - Main plugin implementation
* `Tests/` - Unit tests
* `ExampleApp/` - Example application demonstrating SDK usage

## Documenting types and methods

Please try to make the style and terminology in documentation comments consistent with other documentation comments in the library. Also, if a class or method is being added that has an equivalent in other libraries, and if we have described it in a consistent way in those other libraries, please reuse the text whenever possible (with adjustments for anything language-specific) rather than writing new text.
