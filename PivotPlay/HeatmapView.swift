
import SwiftUI
import MapKit
import CoreLocation
import Combine

#if canImport(UIKit)
import UIKit
#endif

// MARK: - HeatmapPipeline: Core processing pipeline for pitch-based heatmaps

@MainActor
class HeatmapPipeline: ObservableObject {
    static let shared = HeatmapPipeline()
    
    @Published var heatmap: UIImage?
    @Published var isProcessing = false
    
    private let gridSize = (width: 105, height: 68)  // Full pitch @ 1m resolution
    private let pitchImage = UIImage(named: "pitch_background") // Static pitch background
    
    private init() {}
    
    func ingest(_ transfer: PitchDataTransfer) {
        isProcessing = true
        
        Task {
            // Store corners for future use
            UserDefaults.standard.set(try? JSONEncoder().encode(transfer.corners), forKey: "SavedPitchCorners")
            
            // Filter low-accuracy points (would need accuracy info from CLLocation)
            let filteredPath = transfer.path
            
            // Transform coordinates
            let corners = transfer.corners.map { $0.coordinate }
            let transformer = CoordinateTransformer(corners: corners)
            let transformedPath = filteredPath.map { transformer.transform($0.coordinate) }
            
            // Rasterize
            let normalizedHeatmap = rasterizeHeatmap(from: transformedPath)
            
            // Generate image
            let heatmapImage = await generateHeatmapImage(from: normalizedHeatmap)
            
            await MainActor.run {
                self.heatmap = heatmapImage
                self.isProcessing = false
            }
        }
    }
    
    private func rasterizeHeatmap(from points: [PitchCoordinate]) -> [[Double]] {
        var heatmap = Array(repeating: Array(repeating: 0, count: gridSize.height), count: gridSize.width)
        
        // Count visits to each grid cell
        for point in points {
            let x = Int(point.x.rounded())
            let y = Int(point.y.rounded())
            
            guard (0..<gridSize.width).contains(x),
                  (0..<gridSize.height).contains(y) else { continue }
            
            heatmap[x][y] += 1
        }
        
        // Normalize to 0...1 and convert to Double array
        let maxCount = heatmap.flatMap { $0 }.max() ?? 1
        var normalizedHeatmap = Array(repeating: Array(repeating: 0.0, count: gridSize.height), count: gridSize.width)
        
        for x in 0..<gridSize.width {
            for y in 0..<gridSize.height {
                normalizedHeatmap[x][y] = Double(heatmap[x][y]) / Double(maxCount)
            }
        }
        
        return normalizedHeatmap
    }
    
    private func generateHeatmapImage(from normalizedHeatmap: [[Double]]) async -> UIImage? {
        let palette = generateColorPalette()
        
        // UIKit graphics operations must run on main thread
        return await MainActor.run {
            return createHeatmapImage(heatmap: normalizedHeatmap, palette: palette)
        }
    }
    
    private func createHeatmapImage(heatmap: [[Double]], palette: [UIColor]) -> UIImage? {
        let imageSize = CGSize(width: gridSize.width, height: gridSize.height)
        
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        
        // Fill each grid cell with appropriate color
        for x in 0..<gridSize.width {
            for y in 0..<gridSize.height {
                let intensity = heatmap[x][y]
                let colorIndex = min(Int(intensity * Double(palette.count - 1)), palette.count - 1)
                let color = palette[colorIndex]
                
                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: x, y: gridSize.height - 1 - y, width: 1, height: 1))
            }
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    private func generateColorPalette() -> [UIColor] {
        let stops: [(position: Double, color: UIColor)] = [
            (0.0, .clear),
            (0.07, .systemGreen),
            (0.45, .systemYellow),
            (1.0, .systemRed)
        ]
        
        return GradientBuilder.generatePalette(stops: stops, count: 15)
    }
}

// MARK: - Gradient Builder

struct GradientBuilder {
    static func generatePalette(stops: [(position: Double, color: UIColor)], count: Int) -> [UIColor] {
        var palette: [UIColor] = []
        
        for i in 0..<count {
            let position = Double(i) / Double(count - 1)
            let color = interpolateColor(at: position, stops: stops)
            palette.append(color)
        }
        
        return palette
    }
    
    private static func interpolateColor(at position: Double, stops: [(position: Double, color: UIColor)]) -> UIColor {
        // Find the two stops that bracket this position
        let sortedStops = stops.sorted { $0.position < $1.position }
        
        if position <= sortedStops.first!.position {
            return sortedStops.first!.color
        }
        
        if position >= sortedStops.last!.position {
            return sortedStops.last!.color
        }
        
        for i in 0..<(sortedStops.count - 1) {
            let lower = sortedStops[i]
            let upper = sortedStops[i + 1]
            
            if position >= lower.position && position <= upper.position {
                let t = (position - lower.position) / (upper.position - lower.position)
                return interpolateUIColor(from: lower.color, to: upper.color, t: t)
            }
        }
        
        return sortedStops.last!.color
    }
    
    private static func interpolateUIColor(from: UIColor, to: UIColor, t: Double) -> UIColor {
        var fromR: CGFloat = 0, fromG: CGFloat = 0, fromB: CGFloat = 0, fromA: CGFloat = 0
        var toR: CGFloat = 0, toG: CGFloat = 0, toB: CGFloat = 0, toA: CGFloat = 0
        
        from.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)
        to.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)
        
        let r = fromR + (toR - fromR) * t
        let g = fromG + (toG - fromG) * t
        let b = fromB + (toB - fromB) * t
        let a = fromA + (toA - fromA) * t
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Updated Heatmap View

struct HeatmapView: View {
    var locations: [CLLocation]
    @StateObject private var pipeline = HeatmapPipeline.shared
    
    var body: some View {
        ZStack {
            // Background pitch image (if available)
            if let pitchBackground = UIImage(named: "pitch_background") {
                Image(uiImage: pitchBackground)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback: simple green rectangle representing pitch
                Rectangle()
                    .fill(Color.green.opacity(0.3))
                    .aspectRatio(105.0/68.0, contentMode: .fit)
            }
            
            // Heatmap overlay
            if let heatmapImage = pipeline.heatmap {
                Image(uiImage: heatmapImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .blendMode(.multiply)
            }
            
            // Processing indicator
            if pipeline.isProcessing {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Generating Heatmap...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.black.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .onAppear {
            // For backward compatibility with old workout display
            if pipeline.heatmap == nil && !locations.isEmpty {
                // This would be triggered for old workouts without pitch data
                // Could implement a fallback GPS-based heatmap here if needed
            }
        }
    }
}

// MARK: - Legacy MapKit-based View (for reference/fallback)

struct LegacyHeatmapView: UIViewRepresentable {
    var locations: [CLLocation]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybrid
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        let overlay = HeatmapOverlay(locations: locations)
        uiView.addOverlay(overlay)

        if let firstLocation = locations.first {
            let region = MKCoordinateRegion(center: firstLocation.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
            uiView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LegacyHeatmapView

        init(_ parent: LegacyHeatmapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is HeatmapOverlay {
                return HeatmapOverlayRenderer(overlay: overlay, locations: parent.locations)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
