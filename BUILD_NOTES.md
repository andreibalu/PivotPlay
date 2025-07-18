# PivotPlay Build Configuration Notes

## Project Structure
- **Project File**: `PivotPlay.xcodeproj`
- **Main App Scheme**: `PivotPlay` (iOS)
- **Watch App Scheme**: `PivotPlay Watch App` (watchOS)

## Preferred Build Settings (RECOMMENDED)

### iOS App Build (Main App)
- **Scheme:** `PivotPlay`
- **Simulator:** `Iph16+watch10` (ID: 7F8FDE71-03D1-4061-9A4C-B066855786E6)

```bash
# Build iOS app for paired iPhone+Watch simulator
mcp_XcodeBuildMCP_build_sim_id_proj({
  projectPath: "/Users/andrei/Code/XCODE/PivotPlay/PivotPlay.xcodeproj",
  scheme: "PivotPlay",
  simulatorId: "7F8FDE71-03D1-4061-9A4C-B066855786E6"
})
```

### Watch App Build (Standalone)
- **Scheme:** `PivotPlay Watch App`
- **Simulator:** `Apple Watch Series 10 (46mm)` (ID: 36AE1D63-0563-4F4A-9F6A-7525C4BF40FD)

```bash
# Build watchOS app for Apple Watch simulator
mcp_XcodeBuildMCP_build_sim_id_proj({
  projectPath: "/Users/andrei/Code/XCODE/PivotPlay/PivotPlay.xcodeproj",
  scheme: "PivotPlay Watch App",
  simulatorId: "36AE1D63-0563-4F4A-9F6A-7525C4BF40FD"
})
```

## Manual xcodebuild Commands (for reference)
```bash
# Build for iOS Simulator (paired iPhone+Watch)
xcodebuild build -project PivotPlay.xcodeproj -scheme PivotPlay -destination 'platform=iOS Simulator,id=7F8FDE71-03D1-4061-9A4C-B066855786E6'

# Build for watchOS Simulator (Apple Watch Series 10 46mm)
xcodebuild build -project PivotPlay.xcodeproj -scheme "PivotPlay Watch App" -destination 'platform=watchOS Simulator,id=36AE1D63-0563-4F4A-9F6A-7525C4BF40FD'
```

## Build Status
- ✅ Main app builds successfully (after removing duplicate WorkoutSession definition)
- ⚠️ Test scheme not configured (tests exist in PivotPlayTests/ but not integrated into build scheme)
- ⚠️ Minor AppIntents metadata warning (can be ignored)

## Notes
- The project has test files in `PivotPlayTests/` directory but the main scheme isn't configured for testing
- Error handling infrastructure (Task 1) builds without issues
- Ready to proceed with Task 2: WorkoutStorage fixes

## Last Successful Build
- Date: 2025-07-18
- Scheme: PivotPlay
- Target: iOS Simulator (Iph16+watch10)
- Status: ✅ Success