## Implementation Roadmap (TDD-first MVP)

### Scope & Goals
- **Goal**: Ship a dual iOS + watchOS MVP for casual soccer tracking: record on watch, review on iPhone. Heatmap comes last.
- **Platforms**: iOS 26 SDK, watchOS 11+/26 SDK equivalents. Minimum deployment iOS 18, watchOS matching.
- **Data**: Heart rate, distance, pace, top 5-second pace; history; averages; basic settings.

### Principles (TDD)
- **Write failing tests first** per unit/feature, then implement to pass, refactor safely.
- **Prefer pure functions** for calculations (pace, stats) to make tests fast and deterministic.
- **Mock system services** (HealthKit, CoreLocation, WatchConnectivity) for integration tests.
- **Guard rails**: Each feature has explicit acceptance criteria and definition of done.
- **Follow repo guidance**: Adhere to `AGENT.md` for architecture patterns, SwiftUI conventions, and build/test commands.

### Architecture (brief)
- **watchOS app**: `HKWorkoutSession` + `HKLiveWorkoutBuilder` for HR/distance/pace; long-press start UI; publish live stats; persist checkpoints.
- **iOS app**: Home, Stats, History, Settings; receives workout summaries from watch; computes aggregates; renders details. Heatmap processing deferred.
- **Sync**: `WatchConnectivity` message-based with resumable transfers.
- **Storage**: Lightweight store (Core Data or SQLite) for Sessions and Samples; HealthKit workout/route for portability.

### Entities (initial)
- **Session**: id, start/end, duration, totalDistance, avgPace, topFiveSecPace, avgHR, maxHR, source (watch), fieldTransform (reserved for heatmap), notes.
- **Sample** (optional for MVP phone): timestamp, distanceTotal, heartRate, paceInstant.

### MVP Feature Map
- **iOS Home**: quick summary of last session + CTA to start on watch.
- **iOS Stats**: lifetime and rolling averages (distance, pace, HR), simple charts.
- **iOS History**: list of sessions; detail view with metrics (heatmap placeholder box for now).
- **iOS Settings**: units, privacy, permissions helpers.
- **watch Home**: elegant start tile; press-and-hold 3s to start.
- **watch In-Workout**: HR (with zone hint), total distance, average pace, top 5s pace; end/save.

---

## Sprint Plan (test-first)

### Sprint 0 – Project, CI, Mocks
- **Acceptance**:
  - Build and test tasks run locally and in CI.
  - Mocks available for HealthKit, Location, Connectivity.
- **Write tests (failing)**:
  - `EnvironmentTests.testHealthKitAuthorizationFlow_stubbed()`
  - `ConnectivityTests.testRoundTripPayloadEncoding()`
  - `PaceCalculatorTests.testPaceFormatting()`
- **Implement**:
  - Project/workspace, targets, basic folders.
  - Test support: mock services, fixtures, builders.
- **DoD**: Green tests, CI badge, instructions in README.

### Sprint 1 – Permissions, Onboarding, Settings
- **User stories**:
  - As a user, I can grant Health/Location/Motion permissions with clear rationale.
  - As a user, I can set units and privacy choices.
- **Acceptance**:
  - App gracefully handles denied permissions and guides user to Settings.
- **Write tests (failing)**:
  - `PermissionsReducerTests.testRequestAndStoreAuthorizations()`
  - `SettingsStoreTests.testPersistsUnitsAndPrivacy()`
- **Implement**:
  - Onboarding flow with permission requests.
  - Settings screen (units: metric/imperial; privacy toggles; reset tips).
- **DoD**: Snapshot/UI tests stable; cold start flows validated.

### Sprint 2 – watchOS Workout Core
- **User stories**:
  - Press-and-hold 3s starts a soccer workout; metrics stream live.
  - I can see HR, distance, avg pace, top 5s pace; end/save reliably.
- **Acceptance**:
  - Start requires continuous 3s hold; accidental taps do not start.
  - Pausing/resuming works; app survives background.
- **Write tests (failing)**:
  - `StartHoldRecognizerTests.testRequiresThreeSeconds()`
  - `TopPaceTrackerTests.testFastestFiveSecondWindow()`
  - `WorkoutSessionLogicTests.testAggregatesDistanceAndPace()`
- **Implement**:
  - `HKWorkoutSession` + `HKLiveWorkoutBuilder` pipeline.
  - Long-press start UI with progress ring; debounced.
  - `TopPaceTracker` sliding window (5s best pace) over distance/time samples.
  - Persist to HealthKit and local summary.
- **DoD**: Simulated and device runs stable for 45+ minutes.

### Sprint 3 – Sync & History (iOS)
- **User stories**:
  - My completed workout appears on phone; I can open details.
  - A history list shows previous games with key stats.
- **Acceptance**:
  - Transfer resilient to disconnects; duplicates avoided.
- **Write tests (failing)**:
  - `ConnectivitySyncTests.testResumableTransferAndIdempotency()`
  - `HistoryStoreTests.testSaveFetchSortSessions()`
  - `HistoryDetailViewTests.testShowsMetricsAndHeatmapPlaceholder()`
- **Implement**:
  - `WatchConnectivity` inbound pipeline; dedupe by session id.
  - History list and detail view; placeholder for heatmap canvas.
- **DoD**: Sync round-trip under airplane toggle; UI snapshots approved.

### Sprint 4 – Stats (Aggregates & Charts)
- **User stories**:
  - I can view averages and totals: distance, pace, HR; trend chart.
- **Acceptance**:
  - Stats update when new session arrives; units respected.
- **Write tests (failing)**:
  - `StatsAggregatorTests.testAveragesTotalsOverSampleSessions()`
  - `UnitsFormattingTests.testMetricAndImperialOutputs()`
- **Implement**:
  - Stats aggregator over `Session` store.
  - Charts (distance per session, pace histogram) with SPM Charts.
- **DoD**: Deterministic unit tests with fixtures; snapshot tests stable.

### Sprint 5 – iOS Home & Polish
- **User stories**:
  - Home shows last session summary and CTA to start on watch.
  - Settings refinements and help links.
- **Write tests (failing)**:
  - `HomeViewTests.testShowsLastSessionSummary()`
  - `DeepLinkTests.testOpenSettingsPermissions()`
- **Implement**:
  - Home layout; empty state; deep links to Settings.
- **DoD**: Visual QA passed; VoiceOver labels present.

### Sprint 6 – Heatmap (Final Step)
- **User stories**:
  - In session detail, I see a field heatmap (from my route) with halves normalized.
- **Acceptance**:
  - Heatmap matches dwell hotspots; second half mirrored for attack direction.
- **Write tests (failing)**:
  - `FieldTransformTests.testHomographyFromCornersToUnitField()`
  - `HeatmapGridTests.testBinningAndGaussianSmoothing()`
  - `HalvesNormalizationTests.testFlipSecondHalfXAxis()`
- **Implement**:
  - Field calibration (drag-to-fit + corner-walk optional); homography; grid + blur; color map; render in detail.
- **DoD**: Performance acceptable on device; visual comparisons validated.

---

## Detailed TDD Targets (selected)

### Pace & Top 5-Second Pace
- **Definition**:
  - Pace = duration / distance. Use meters/seconds internally; format by unit setting.
  - Top 5-second pace = fastest pace over any contiguous 5s window using cumulative distance.
- **Tests**:
  - Constant speed stream → average pace equals ground truth.
  - Two-speed segments → top 5s window reflects the fast segment.
  - Noisy jitter → clamped acceleration and minimum window samples handled.

### Start Hold Recognizer (3s)
- **Tests**:
  - <3s press never triggers; ≥3.0s triggers exactly once.
  - Interruptions (finger lifted at 2.9s) reset the timer.
  - Backgrounding during hold cancels.

### Sync Idempotency
- **Tests**:
  - Same session payload sent twice → one record.
  - Interrupted transfer resumes and completes.

### Stats Aggregation
- **Tests**:
  - Aggregates over fixtures: average distance, average pace, avg/max HR match expected.
  - Unit changes reflect in formatted outputs only, not stored SI values.

---

## Build, Run, Test
- **CLI (examples)**:
  - iOS build/tests (scheme: main app) [[memory:3664699]]:
    - `xcodebuild -scheme "PivotPlay" -destination 'platform=iOS Simulator,name=PivotPlayIphone17Pro' test | cat`
  - watchOS build/tests (scheme: watch app) [[memory:3664699]]:
    - `xcodebuild -scheme "WatchPivotPlay Watch App" -destination 'platform=watchOS Simulator,name=PivotPlayPair' build | cat`
- **Simulators**: Prefer simulator ID `7A60F66C-2FAC-4007-A069-81CFEA4C2C02` for iPhone when available [[memory:3118683]].

## Definition of Done (per feature)
- Green tests (unit + UI where applicable).
- No crashes in 45-minute simulated workout.
- Accessibility labels, dynamic type, and basic VoiceOver.
- Battery-conscious sampling and background behavior verified.

## Out of Scope (for MVP)
- Team/session sharing; cloud sync; advanced heatmap analytics; AR replay; role templates.

## Next Steps
- Start Sprint 0; generate fixtures; stand up mocks; add first failing tests for permissions and pace calculations.

