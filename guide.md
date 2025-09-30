## Guide: Fastest Way to Kickstart PivotPlay (iOS + watchOS)

### TL;DR
- Create an iOS SwiftUI app named `PivotPlay` with a watchOS companion app.
- Enable capabilities: HealthKit (both iOS and watch), Background Modes (Workout Processing, Location), Motion & Fitness.
- Use schemes `PivotPlay` and `PivotPlay Watch App` with preferred simulators (iPhone 16 and Apple Watch Series 10) [[memory:3664699]]. Prefer the paired iPhone simulator ID `7F8FDE71-03D1-4061-9A4C-B066855786E6` [[memory:3118683]], and watch simulator `Apple Watch Series 10 (46mm)` [[memory:3664792]].
- Fill `AGENT.md` with Xcode MCP build/test commands (examples below).
- Run a clean build and tests; then let the LLM generate code incrementally.

---

### 1) Create the Xcode project (iOS app + watch companion)
1. Open Xcode → File → New → Project…
2. Select “App” under iOS → Next
3. Configure:
   - Product Name: `PivotPlay`
   - Team: your Apple ID team
   - Organization Identifier: your domain reverse (e.g., `com.yourname`)
   - Interface: SwiftUI
   - Language: Swift
   - Include Tests: checked
   - Use Core Data: off (add later if needed)
   - Use CloudKit: off (MVP)
4. Choose the folder `/Users/andrei/Code/XCODE/PivotPlay` and create.
5. Add watchOS companion:
   - File → New → Target… → watchOS → “App” (or “Watch App for iOS App”)
   - Name: `PivotPlay Watch App`
   - Embed in Companion iOS App: checked
   - SwiftUI lifecycle
   - Finish; activate the new scheme if prompted.

Schemes to use:
- iOS: 
- watchOS: 

Preferred simulators:
- iPhone: use simulator ID
- Watch: 

---

### 2) Initial project settings
In Xcode, select each target and configure:

- Signing & Capabilities (iOS app target `PivotPlay`):
  - Team: your Apple ID team
  - Add Capability: HealthKit (Share + Update)
  - Add Capability: Background Modes → check “Workout Processing” and “Location Updates”
  - Add Capability: Motion & Fitness
  - (Optional) Location: ensure “Location Updates” is enabled under Background Modes

- Signing & Capabilities (watch target `PivotPlay Watch App`):
  - Team: same as iOS
  - Add Capability: HealthKit (required on watch)
  - Add Capability: Background Modes → “Workout Processing”
  - Add Capability: Motion & Fitness

- Deployment Info:
  - iOS: turn on iPhone; set minimum iOS 26.0 
  - watchOS: set minimum to match supported watchOS for iOS 26 SDK

- Info.plist keys (add as needed):
  - `NSHealthShareUsageDescription`: "We use Health data (heart rate, workouts) during sessions."
  - `NSHealthUpdateUsageDescription`: "We write workout summaries you confirm."
  - `NSLocationWhenInUseUsageDescription`: "Used to map your session to the field."
  - `NSMotionUsageDescription`: "Used to estimate pace and improve accuracy."

---

### 3) Prepare simulators and pairing
- Ensure the iPhone simulator with UDID `7F8FDE71-03D1-4061-9A4C-B066855786E6` is available [[memory:3118683]].
- Use `Xcode → Window → Devices and Simulators` to create/verify:
  - iPhone 16 (or your preferred 16 model) and pair it with Apple Watch Series 10.
  - Standalone watch sim: `Apple Watch Series 10 (46mm)` [[memory:3664792]].

---

### 4) Fill AGENT.md build/test sections (using Xcode MCP)
Paste/replace the placeholders in `AGENT.md` with the following examples so the agent and tools can build/test quickly.

#### Building for iOS Simulator
```bash
# Xcode MCP: iOS build & run on the preferred iPhone simulator
# Tool: XcodeBuildMCP build_run_sim
# Params:
#   projectPath: "/Users/andrei/Code/XCODE/PivotPlay/PivotPlay.xcodeproj"
#   scheme: "PivotPlay"  # [[memory:3664699]]
#   simulatorId: "7F8FDE71-03D1-4061-9A4C-B066855786E6"  # [[memory:3118683]]
```

#### Running iOS Unit Tests
```bash
# Xcode MCP: iOS tests on simulator
# Tool: XcodeBuildMCP test_sim
# Params:
#   projectPath: "/Users/andrei/Code/XCODE/PivotPlay/PivotPlay.xcodeproj"
#   scheme: "PivotPlay"  # [[memory:3664699]]
#   simulatorId: "7F8FDE71-03D1-4061-9A4C-B066855786E6"  # [[memory:3118683]]
```

#### Building the watchOS App
```bash
# Xcode MCP: watchOS build on Series 10 (46mm)
# Tool: XcodeBuildMCP build_sim
# Params:
#   projectPath: "/Users/andrei/Code/XCODE/PivotPlay/PivotPlay.xcodeproj"
#   scheme: "PivotPlay Watch App"  # [[memory:3664699]]
#   simulatorName: "Apple Watch Series 10 (46mm)"  # [[memory:3664792]]
```

#### Optional: CLI fallback (xcodebuild)
```bash
xcodebuild -scheme "PivotPlay" -destination 'platform=iOS Simulator,name=iPhone 16' build | cat
xcodebuild -scheme "PivotPlay" -destination 'platform=iOS Simulator,name=iPhone 16' test | cat
xcodebuild -scheme "PivotPlay Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build | cat
```

---

### 5) One-time checklist before LLM coding
- Git hygiene:
  - Initialize repo (already present), add a `*.gitignore` (Xcode/Swift).
  - Commit the clean template project as baseline.
- Signing:
  - Confirm both iOS and watch targets sign successfully for Debug.
- Capabilities:
  - HealthKit + Background Modes + Motion & Fitness enabled on both targets (as above).
- Schemes & Simulators:
  - Confirm schemes `PivotPlay` and `PivotPlay Watch App` exist [[memory:3664699]].
  - Verify the iPhone simulator ID `7F8FDE71-03D1-4061-9A4C-B066855786E6` runs [[memory:3118683]].
  - Verify watch sim `Apple Watch Series 10 (46mm)` builds [[memory:3664792]].
- Permissions copy:
  - Add the Info.plist strings shown above to prevent runtime crashes on permission prompts.
- Build once:
  - Run an iOS build and a watch build using the MCP or CLI to confirm toolchain is green.
- AGENT alignment:
  - Ensure `AGENT.md` reflects the MCP commands above and references SwiftUI architecture guidance.

---

### 6) Suggested folder layout (lightweight)
- `PivotPlay/` – iOS app code
- `PivotPlay Watch App/` – watch app code
- `Shared/` – shared models/utilities (if needed)
- `Tests/` – unit tests for shared/iOS
- `WatchTests/` – watch unit tests (optional)
- `Docs/` – docs like this guide and the roadmap

---

### 7) First tasks to ask the LLM to implement
1. Add a minimal SwiftUI `HomeView` with last-session placeholder.
2. Add `SettingsView` with units toggle and permissions helpers.
3. Add watch long-press start (3s) view model + UI; stub `HKWorkoutSession`.
4. Add `TopPaceTracker` with unit tests (sliding 5-second window).
5. Wire navigation: Home, Stats, History, Settings tabs.

Once these compile and tests pass, proceed to Sync, History, Stats, and finally Heatmap (per `implementation_roadmap.md`).

---

### 8) Reference
- Roadmap: `implementation_roadmap.md`
- Guidelines: `AGENT.md`
- Schemes & Simulators: `PivotPlay`, `PivotPlay Watch App`, iPhone UDID and Watch name as noted above [[memory:3664699]] [[memory:3118683]] [[memory:3664792]].


