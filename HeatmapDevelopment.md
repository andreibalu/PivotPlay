# Heatmap Development Guide

This document outlines the end-to-end pipeline for capturing a player's positional data on Apple Watch, transmitting it to the iPhone, rasterising it into a heatmap, and rendering it in the workout detail view.

## 1. Capturing Pitch Corners & Workout Path on Apple Watch

### UI Flow
1. When the user taps **Start**, push `CornerCaptureView` onto the navigation stack.
2. Display instructional text (now with smaller fonts for better visibility) prompting the player to walk to the *current* corner and tap the **Mark Corner** button.
3. Each button tap records the current `CLLocationCoordinate2D` in `cornerPoints` and updates the prompt (e.g. *“Corner 2/4 marked”*).
4. After four corners are recorded:
   * Persist `cornerPoints` (exactly four) in memory.
   * Present **“Pitch saved – tap to start workout.”**

### Starting the Workout
• On the next tap, instantiate `HKWorkoutSession` **and** a `CLLocationManager` configured to deliver updates every ~1–2 s.  
• Append each valid reading to `var workoutPath: [CLLocation]`.  
• On workout completion:
  1. End the `HKWorkoutSession`.
  2. Package data into `PitchDataTransfer` (see §2).
  3. Call `WCSession.default.sendMessageData(...)` to transmit to the iPhone.

```swift
// Watch target
struct PitchDataTransfer: Codable {
    let corners: [CoordinateDTO]          // Exactly 4 elements
    let path: [CoordinateDTO]             // ~N workout points

    struct CoordinateDTO: Codable {
        let latitude: Double
        let longitude: Double
    }
}
```
`CLLocationCoordinate2D` itself is not `Codable`, hence the lightweight DTO above.

---

## 2. Transferring Data to iPhone

```swift
let encoder = JSONEncoder()
if let data = try? encoder.encode(pitchData) {
    try? WCSession.default.sendMessageData(data, replyHandler: nil)
}
```
*Use `sendMessageData` to guarantee near-real-time transfer once connectivity is available.*

---

## 3. Receiving & Pre-processing on iPhone

```swift
func session(_ session: WCSession,
             didReceiveMessageData data: Data) {
    guard let transfer = try? JSONDecoder().decode(PitchDataTransfer.self, from: data) else { return }

    HeatmapPipeline.shared.ingest(transfer)
}
```
Inside `ingest(_)`:

1. **Store Corners**  
   ```swift
   UserDefaults.standard.set(transfer.corners, forKey: "SavedPitchCorners")
   ```
2. **Discard Low-Accuracy Points**  
   Filter where `location.horizontalAccuracy > 15`.
3. **Coordinate Transform**  
   * origin = bottom-left corner (`corners[0]`)
   * `x` axis = vector bottom sideline (`corners[1] – corners[0]`)
   * `y` axis = orthogonal vector toward top sideline (`corners[3] – corners[0]`)
4. Convert each `CLLocation` in `path` to `(x: metres, y: metres)`.

---

## 4. Rasterisation

```swift
let gridSize = (width: 105, height: 68) // Full pitch @ 1 m resolution
var heatmap = Array(repeating: Array(repeating: 0, count: gridSize.height),
                    count: gridSize.width)

for point in transformedPath {
    let x = Int(point.x.rounded())
    let y = Int(point.y.rounded())
    guard (0..<gridSize.width).contains(x),
          (0..<gridSize.height).contains(y) else { continue }
    heatmap[x][y] += 1
}

let maxCount = heatmap.flatMap { $0 }.max() ?? 1
for x in 0..<gridSize.width {
    for y in 0..<gridSize.height {
        heatmap[x][y] = heatmap[x][y] / maxCount // Normalise 0…1
    }
}
```

---

## 5. Colour Table

Build a 15-stop gradient (clear → green → yellow → red).

```swift
let palette: [UIColor] = GradientBuilder
    .stops([
        (0.0, .clear),
        (0.07, .systemGreen),
        (0.45, .systemYellow),
        (1.0, .systemRed)
    ])
    .sample(count: 15)
```

---

## 6. Rendering the Image

1. Create a `CGContext` sized to `gridSize`.
2. For each cell, pick colour `palette[index]` and fill a 1 px rect.
3. Convert to `UIImage`.
4. Overlay on a static pitch image inside a `UIImageView` using `.multiply` blend mode.
5. Wrap in `UIScrollView` / `SwiftUI.ScrollView` with appropriate zoom scales.

---

## 7. Display in Workout Detail Screen

`WorkoutDetailView` observes `HeatmapPipeline`:

```swift
Image(uiImage: pipeline.heatmap)
    .resizable()
    .aspectRatio(contentMode: .fit)
    .gesture(MagnificationGesture())
```

As soon as `WCSession` delivers data, the pipeline publishes the heatmap, automatically refreshing the UI.

---

### Key Types Reference

| Context | Type / Variable | Purpose |
|---------|-----------------|---------|
| Watch   | `cornerPoints: [CLLocation]` | Four pitch corners |
| Watch   | `workoutPath: [CLLocation]` | Player path |
| Both    | `PitchDataTransfer` | Codable payload for WCSession |
| iPhone  | `HeatmapPipeline` | Singleton handling decode → raster → render |
| iPhone  | `heatmap: UIImage` | Final rendered overlay |

---

This guide provides a clear, repeatable pipeline for implementing the pitch-based heatmap from capture to display. 