# Agent Instructions

## Test Commands
- Do not use `swift test` in this repository.
- Use `./test.sh` for test execution.
- If `test.sh` cannot be used, use `xcodebuild test` with an iOS Simulator destination.

## Preferred Usage
- Full run: `./test.sh`
- Test target: `./test.sh --only-testing SessionReplayTests`
- Test suite: `./test.sh --only-testing SessionReplayTests/RRWebEventGeneratorTests`
- Test file: `./test.sh --test-file Tests/SessionReplayTests/SessionReplayEventGeneratorTests.swift`
