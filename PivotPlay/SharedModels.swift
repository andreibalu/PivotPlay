import Foundation
import CoreLocation
import WatchConnectivity

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