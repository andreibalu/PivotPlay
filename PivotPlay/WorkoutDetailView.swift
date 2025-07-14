
import SwiftUI
import MapKit
import CoreLocation
import Foundation

struct WorkoutDetailView: View {
    let workout: WorkoutSession
    @StateObject private var heatmapPipeline = HeatmapPipeline.shared
    @State private var showingLegacyMap = false
    
    private var locations: [CLLocation] {
        workout.locationData.map { CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Heatmap Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Player Heatmap")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Toggle between pitch heatmap and legacy map view
                        Button(action: { showingLegacyMap.toggle() }) {
                            Image(systemName: showingLegacyMap ? "map" : "location.square")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if showingLegacyMap {
                        // Legacy GPS map view for backward compatibility
                        LegacyHeatmapView(locations: locations)
                            .frame(height: 250)
                            .cornerRadius(12)
                    } else {
                        // New pitch-based heatmap
                        HeatmapView(locations: locations)
                            .frame(height: 250)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    if heatmapPipeline.isProcessing {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                            Text("Processing heatmap data...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    
                    if heatmapPipeline.heatmap == nil && !heatmapPipeline.isProcessing {
                        VStack(spacing: 8) {
                            Image(systemName: "location.slash")
                                .font(.title)
                                .foregroundColor(.gray)
                            Text("No pitch data available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Use legacy map view to see GPS tracking")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                // Workout Details Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Workout Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        DetailCard(
                            title: "Date",
                            value: workout.date.formatted(date: .abbreviated, time: .omitted),
                            icon: "calendar"
                        )
                        
                        DetailCard(
                            title: "Time",
                            value: workout.date.formatted(date: .omitted, time: .shortened),
                            icon: "clock"
                        )
                        
                        DetailCard(
                            title: "Duration",
                            value: formatDuration(workout.duration),
                            icon: "stopwatch"
                        )
                        
                        DetailCard(
                            title: "Distance",
                            value: formatDistance(workout.totalDistance),
                            icon: "figure.walk"
                        )
                    }
                    
                    // Heart Rate Summary if available
                    if !workout.heartRateData.isEmpty {
                        let avgHeartRate = workout.heartRateData.map(\.value).reduce(0, +) / Double(workout.heartRateData.count)
                        let maxHeartRate = workout.heartRateData.map(\.value).max() ?? 0
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Heart Rate")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            HStack(spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("Average")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(Int(avgHeartRate)) BPM")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("Maximum")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(Int(maxHeartRate)) BPM")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Workout Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let corners = workout.corners, !corners.isEmpty {
                let pitchData = PitchDataTransfer(
                    workoutId: workout.id,
                    date: workout.date,
                    duration: workout.duration,
                    totalDistance: workout.totalDistance,
                    heartRateData: workout.heartRateData,
                    corners: corners.map { $0.coordinate },
                    locationData: workout.locationData
                )
                heatmapPipeline.ingest(pitchData)
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return "<1 min"
        }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        
        return formatter.string(from: duration) ?? "0m"
    }
    
    private func formatDistance(_ distance: Double) -> String {
        let measurement = Measurement(value: distance, unit: UnitLength.meters)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: measurement)
    }
}

// MARK: - Detail Card Component

struct DetailCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
