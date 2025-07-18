# PivotPlay Build Configuration Notes

## Project Structure
- **Project File**: `PivotPlay.xcodeproj`
- **Main App Scheme**: `PivotPlay` (iOS)
- **Watch App Scheme**: `PivotPlay Watch App` (watchOS)

## Preferred Build Settings

### iOS Simulator Build (Preferred: iPhone 16 + Apple Watch Series 10)
```bash
# Using MCP XcodeBuild tools - iOS App
mcp_XcodeBuildMCP_build_sim_name_proj({
  projectPath: "/Users/andrei/Code/XCODE/PivotPlay/PivotPlay.xcodeproj",
  scheme: "PivotPlay",
  simulatorName: "iPhone 16"
})

# Using MCP XcodeBuild tools - Watch App
mcp_XcodeBuildMCP_build_sim_name_proj({
  projectPath: "/Users/andrei/Code/XCODE/PivotPlay/PivotPlay.xcodeproj",
  scheme: "PivotPlay Watch App",
  simulatorName: "Apple Watch Series 10 (45mm)"
})
```

### Manual xcodebuild Commands
```bash
# Build for iOS Simulator (iPhone 16)
xcodebuild build -project PivotPlay.xcodeproj -scheme PivotPlay -destination 'platform=iOS Simulator,name=iPhone 16'

# Build for watchOS Simulator (Apple Watch Series 10)
xcodebuild build -project PivotPlay.xcodeproj -scheme "PivotPlay Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (45mm)'

# List available targets and schemes
xcodebuild -project PivotPlay.xcodeproj -list
```

## Build Status
- ✅ Main app builds successfully
- ⚠️ Test scheme not configured (tests exist in PivotPlayTests/ but not integrated into build scheme)
- ⚠️ Minor AppIntents metadata warning (can be ignored)

## Notes
- The project has test files in `PivotPlayTests/` directory but the main scheme isn't configured for testing
- Error handling infrastructure (Task 1) builds without issues
- Ready to proceed with Task 2: WorkoutStorage fixes

## Last Successful Build
- Date: 2025-07-15
- Scheme: PivotPlay
- Target: iOS Simulator (iPhone 16)
- Status: ✅ Success