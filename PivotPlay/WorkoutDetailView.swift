
import SwiftUI
import MapKit
import CoreLocation

struct WorkoutDetailView: View {
    let workout: WorkoutSession
    
    private var locations: [CLLocation] {
        workout.locationData.map { CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
    }
    
    var body: some View {
        VStack {
            HeatmapView(locations: locations)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Workout Details")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack {
                    Text("Date:")
                    Spacer()
                    Text(workout.date, style: .date)
                }
                
                HStack {
                    Text("Duration:")
                    Spacer()
                    Text(formatDuration(workout.duration))
                }
                
                HStack {
                    Text("Distance:")
                    Spacer()
                    Text(formatDistance(workout.totalDistance))
                }
            }
            .padding()
        }
        .navigationTitle("Workout Heatmap")
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return "<1 minute"
        }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        return formatter.string(from: duration) ?? "00:00:00"
    }
    
    private func formatDistance(_ distance: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        let measurement = Measurement(value: distance, unit: UnitLength.meters)
        return formatter.string(from: measurement)
    }
}
