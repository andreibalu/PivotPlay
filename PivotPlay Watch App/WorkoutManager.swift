import Foundation
import HealthKit
import CoreLocation
import Combine

class WorkoutManager: NSObject, ObservableObject {
    // MARK: - Properties
    
    @Published var workoutState: HKWorkoutSessionState = .notStarted
    @Published var authorizationState: AuthorizationState = .notDetermined
    @Published var duration: TimeInterval = 0
    @Published var distance: Double = 0
    @Published var heartRate: Double = 0
    
    private var healthStore = HKHealthStore()
    private var locationManager = CLLocationManager()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKWorkoutBuilder?
    
    private var timer: Timer?
    private var heartRateSamples: [HeartRateSample] = []
    private var locationSamples: [LocationSample] = []

    enum AuthorizationState {
        case notDetermined
        case processing
        case authorized
        case denied(String)
    }
    
    var isAuthorized: Bool {
        if case .authorized = authorizationState {
            return true
        }
        return false
    }

    // MARK: - Initialization & Authorization
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermissions() {
        // Check current authorization status first
        checkAuthorizationStatus()
    }
    
    private func checkAuthorizationStatus() {
        // Check HealthKit authorization status
        let heartRateAuth = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .heartRate)!)
        let distanceAuth = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!)
        
        let healthKitAuthorized = heartRateAuth == .sharingAuthorized && distanceAuth == .sharingAuthorized
        let locationAuthorized = isLocationAuthorized()
        
        if healthKitAuthorized && locationAuthorized {
            DispatchQueue.main.async {
                self.authorizationState = .authorized
            }
            return
        }
        
        // Only request permissions if not already authorized
        if !healthKitAuthorized {
            requestHealthKitPermissions()
        } else if !locationAuthorized {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    private func isLocationAuthorized() -> Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
    
    private func requestHealthKitPermissions() {
        DispatchQueue.main.async {
            self.authorizationState = .processing
        }

        let typesToShare: Set = [HKObjectType.workoutType()]
        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            if success {
                // After HealthKit approval, check location permissions
                DispatchQueue.main.async {
                    if self?.isLocationAuthorized() == true {
                        self?.authorizationState = .authorized
                    } else {
                        self?.locationManager.requestWhenInUseAuthorization()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.authorizationState = .denied("HealthKit authorization was denied. Please enable access in the Health app.")
                }
            }
        }
    }

    // MARK: - Workout Control
    
    func startWorkout() {
        guard isAuthorized else {
            print("Cannot start workout, permissions not granted.")
            requestPermissions()
            return
        }
        
        // Reset previous workout data
        resetWorkout()
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .soccer
        configuration.locationType = .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            if let liveBuilder = workoutBuilder as? HKLiveWorkoutBuilder {
                liveBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
                liveBuilder.delegate = self
            }
            
            workoutSession?.delegate = self
            
            // Start the session and builder
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { (success, error) in
                if !success {
                    print("Failed to start workout builder: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
            
            locationManager.startUpdatingLocation()
            
            // Start the timer to update the UI
            startTimer()
            
            DispatchQueue.main.async {
                self.workoutState = .running
            }
            
        } catch {
            print("Failed to start workout session: \(error.localizedDescription)")
        }
    }

    func stopWorkout() {
        workoutSession?.end()
        locationManager.stopUpdatingLocation()
        stopTimer()
        
        DispatchQueue.main.async {
            self.workoutState = .ended
        }
    }
    
    private func resetWorkout() {
        duration = 0
        distance = 0
        heartRate = 0
        heartRateSamples = []
        locationSamples = []
        workoutState = .notStarted
    }

    // MARK: - Data & UI Updates
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let builder = self.workoutBuilder {
                self.duration = builder.elapsedTime(at: Date())
            } else {
                self.duration = 0
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateForStatistics(_ statistics: HKStatistics?) {
        guard let statistics = statistics else { return }
        
        DispatchQueue.main.async {
            switch statistics.quantityType {
            case HKObjectType.quantityType(forIdentifier: .heartRate):
                let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                self.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                if self.heartRate > 0 {
                    self.heartRateSamples.append(HeartRateSample(value: self.heartRate, timestamp: Date()))
                }
                
            case HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning):
                let distanceUnit = HKUnit.meter()
                self.distance = statistics.sumQuantity()?.doubleValue(for: distanceUnit) ?? 0
                
            default:
                break
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    /*
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let locationSample = LocationSample(coordinate: location.coordinate, timestamp: location.timestamp)
        self.locationSamples.append(locationSample)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    */
}

// MARK: - CLLocationManagerDelegate
extension WorkoutManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let locationSample = LocationSample(coordinate: location.coordinate, timestamp: location.timestamp)
        self.locationSamples.append(locationSample)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            break // still waiting
        case .restricted, .denied:
            DispatchQueue.main.async {
                self.authorizationState = .denied("Location access is required for workouts. Please enable it in your iPhone's Settings app (Privacy > Location Services).")
            }
        case .authorizedWhenInUse, .authorizedAlways:
            DispatchQueue.main.async {
                self.authorizationState = .authorized
            }
        @unknown default:
            DispatchQueue.main.async {
                self.authorizationState = .denied("An unknown authorization error occurred.")
            }
        }
    }
}


// MARK: - HKWorkoutSessionDelegate & HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.workoutState = toState
        }
        
        // When the session ends, finish collecting data
        if toState == .ended {
            workoutBuilder?.endCollection(withEnd: Date()) { (success, error) in
                self.workoutBuilder?.finishWorkout { (workout, error) in
                    DispatchQueue.main.async {
                        self.workoutState = .ended
                        self.packageAndSendWorkout()
                    }
                }
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed with error: \(error.localizedDescription)")
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            updateForStatistics(statistics)
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Not used in this MVP
    }
    
    // MARK: - Data Transfer
    
    private func packageAndSendWorkout() {
        let workoutDTO = WorkoutSessionDTO(
            id: UUID(),
            date: Date(),
            duration: self.duration,
            totalDistance: self.distance,
            heartRateData: self.heartRateSamples,
            locationData: self.locationSamples
        )
        
        WatchConnectivityManager.shared.sendWorkout(workoutDTO)
        
        print("Workout finished and packaged. Sent to iPhone.")
        print("Duration: \(workoutDTO.duration), Distance: \(workoutDTO.totalDistance)")
    }
}