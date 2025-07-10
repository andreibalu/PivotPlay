
import SwiftUI
import MapKit

struct WorkoutDetailView: View {
    let workout: WorkoutSession
    
    private var locations: [CLLocation] {
        workout.locationData.map { CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
    }
    
    var body: some View {
        VStack {
            HeatmapView(locations: locations)
                .edgesIgnoringSafeArea(.all)
            
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
                    Text(String(format: "%.2f minutes", workout.duration / 60))
                }
                
                HStack {
                    Text("Distance:")
                    Spacer()
                    Text(String(format: "%.2f meters", workout.totalDistance))
                }
            }
            .padding()
        }
        .navigationTitle("Workout Heatmap")
    }
}
