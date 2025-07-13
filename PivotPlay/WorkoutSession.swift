
import Foundation
import CoreLocation
#if os(iOS)
import SwiftData
#endif

#if os(iOS)
// The main data model for a completed workout session.
@Model
final class WorkoutSession: Identifiable, Sendable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var duration: TimeInterval // Total duration in seconds
    var totalDistance: Double // Total distance in meters
    var heartRateData: [HeartRateSample]
    var locationData: [LocationSample]
    
    init(id: UUID, date: Date, duration: TimeInterval, totalDistance: Double, heartRateData: [HeartRateSample], locationData: [LocationSample]) {
        self.id = id
        self.date = date
        self.duration = duration
        self.totalDistance = totalDistance
        self.heartRateData = heartRateData
        self.locationData = locationData
    }
}
#endif
