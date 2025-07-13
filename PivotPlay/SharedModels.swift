import Foundation
import CoreLocation
import WatchConnectivity

// MARK: - Existing Models

// A single recorded GPS coordinate with a timestamp.
struct LocationSample: Codable, Hashable {
    var coordinate: CLLocationCoordinate2D
    var timestamp: Date

    // Since CLLocationCoordinate2D is not directly Codable, we need to manually encode/decode it.
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude, timestamp
    }

    init(coordinate: CLLocationCoordinate2D, timestamp: Date) {
        self.coordinate = coordinate
        self.timestamp = timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(CLLocationDegrees.self, forKey: .latitude)
        let longitude = try container.decode(CLLocationDegrees.self, forKey: .longitude)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    // Manually implement hashable since CLLocationCoordinate2D does not conform to hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(timestamp)
    }
    
    static func == (lhs: LocationSample, rhs: LocationSample) -> Bool {
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.timestamp == rhs.timestamp
    }
}

// A single recorded heart rate measurement with a timestamp.
struct HeartRateSample: Codable, Hashable {
    var value: Double // Heart rate in beats per minute (BPM)
    var timestamp: Date
}

struct WorkoutSessionDTO: Codable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let totalDistance: Double
    let heartRateData: [HeartRateSample]
    let locationData: [LocationSample]
}

// MARK: - New Heatmap Models

// Lightweight coordinate DTO for encoding (CLLocationCoordinate2D is not Codable)
struct CoordinateDTO: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    
    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// Enhanced data transfer structure for pitch-based heatmaps
struct PitchDataTransfer: Codable {
    let workoutId: UUID
    let date: Date
    let duration: TimeInterval
    let totalDistance: Double
    let heartRateData: [HeartRateSample]
    let corners: [CoordinateDTO]          // Exactly 4 pitch corners
    let path: [CoordinateDTO]             // Player's workout path
    
    init(workoutId: UUID, date: Date, duration: TimeInterval, totalDistance: Double, 
         heartRateData: [HeartRateSample], corners: [CLLocationCoordinate2D], path: [CLLocationCoordinate2D]) {
        self.workoutId = workoutId
        self.date = date
        self.duration = duration
        self.totalDistance = totalDistance
        self.heartRateData = heartRateData
        self.corners = corners.map { CoordinateDTO(from: $0) }
        self.path = path.map { CoordinateDTO(from: $0) }
    }
}

// Transformed coordinate in pitch-relative space (meters from bottom-left corner)
struct PitchCoordinate {
    let x: Double  // Distance along bottom sideline (meters)
    let y: Double  // Distance perpendicular to bottom sideline (meters)
}

// MARK: - Coordinate Transformation Utilities

struct CoordinateTransformer {
    private let origin: CLLocationCoordinate2D
    private let xAxis: CLLocationCoordinate2D  // Vector along bottom sideline
    private let yAxis: CLLocationCoordinate2D  // Vector toward top sideline
    private let metersPerDegree: Double
    
    init(corners: [CLLocationCoordinate2D]) {
        guard corners.count == 4 else {
            fatalError("CoordinateTransformer requires exactly 4 corners")
        }
        
        // Corners should be ordered: [bottom-left, bottom-right, top-right, top-left]
        self.origin = corners[0]  // Bottom-left corner
        
        // Calculate x-axis vector (bottom sideline)
        let bottomRight = corners[1]
        self.xAxis = CLLocationCoordinate2D(
            latitude: bottomRight.latitude - origin.latitude,
            longitude: bottomRight.longitude - origin.longitude
        )
        
        // Calculate y-axis vector (perpendicular toward top sideline)
        let topLeft = corners[3]
        self.yAxis = CLLocationCoordinate2D(
            latitude: topLeft.latitude - origin.latitude,
            longitude: topLeft.longitude - origin.longitude
        )
        
        // Approximate meters per degree at this latitude
        self.metersPerDegree = 111_000 * cos(origin.latitude * .pi / 180)
    }
    
    func transform(_ coordinate: CLLocationCoordinate2D) -> PitchCoordinate {
        // Vector from origin to the point
        let deltaLat = coordinate.latitude - origin.latitude
        let deltaLng = coordinate.longitude - origin.longitude
        
        // Convert to meters
        let deltaLatM = deltaLat * 111_000  // Latitude degrees to meters
        let deltaLngM = deltaLng * metersPerDegree  // Longitude degrees to meters
        
        // Project onto x and y axes
        let xAxisLatM = xAxis.latitude * 111_000
        let xAxisLngM = xAxis.longitude * metersPerDegree
        let yAxisLatM = yAxis.latitude * 111_000
        let yAxisLngM = yAxis.longitude * metersPerDegree
        
        // Calculate axis lengths
        let xAxisLength = sqrt(xAxisLatM * xAxisLatM + xAxisLngM * xAxisLngM)
        let yAxisLength = sqrt(yAxisLatM * yAxisLatM + yAxisLngM * yAxisLngM)
        
        // Project delta onto normalized axes
        let x = (deltaLatM * xAxisLatM + deltaLngM * xAxisLngM) / xAxisLength
        let y = (deltaLatM * yAxisLatM + deltaLngM * yAxisLngM) / yAxisLength
        
        return PitchCoordinate(x: x, y: y)
    }
}

// MARK: - Watch Connectivity Manager

class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    private let session: WCSession = .default
    
    override private init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed with error: \(error.localizedDescription)")
            return
        }
        print("WCSession activated with state: \(activationState.rawValue)")
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession did become inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession did deactivate")
        session.activate()
    }
    #endif
    
    // Legacy method for backward compatibility
    func sendWorkout(_ workout: WorkoutSessionDTO) {
        guard WCSession.default.isReachable else {
            print("WCSession is not reachable.")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(workout)
            session.transferUserInfo(["workoutData": data])
        } catch {
            print("Failed to encode workout session: \(error.localizedDescription)")
        }
    }
    
    // New method for pitch-based heatmap data
    func sendPitchData(_ pitchData: PitchDataTransfer) {
        guard WCSession.default.isReachable else {
            print("WCSession is not reachable.")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(pitchData)
            session.sendMessageData(data, replyHandler: nil) { error in
                print("Failed to send pitch data: \(error.localizedDescription)")
            }
        } catch {
            print("Failed to encode pitch data: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let data = userInfo["workoutData"] as? Data else { return }
        
        do {
            let decoder = JSONDecoder()
            let workoutDTO = try decoder.decode(WorkoutSessionDTO.self, from: data)
            
            #if os(iOS)
            if let workout = WorkoutSession(from: workoutDTO) {
                Task {
                    await MainActor.run {
                        WorkoutStorage.shared.saveWorkout(workout)
                    }
                }
            }
            #endif
        } catch {
            print("Failed to decode workout session: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        do {
            let decoder = JSONDecoder()
            let pitchData = try decoder.decode(PitchDataTransfer.self, from: messageData)
            
            #if os(iOS)
            Task {
                await MainActor.run {
                    HeatmapPipeline.shared.ingest(pitchData)
                }
            }
            #endif
        } catch {
            print("Failed to decode pitch data: \(error.localizedDescription)")
        }
    }
}

#if os(iOS)
extension WorkoutSession {
    convenience init?(from dto: WorkoutSessionDTO) {
        self.init(id: dto.id,
                  date: dto.date,
                  duration: dto.duration,
                  totalDistance: dto.totalDistance,
                  heartRateData: dto.heartRateData,
                  locationData: dto.locationData)
    }
}
#endif 