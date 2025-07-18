import Foundation
import CoreLocation
import WatchConnectivity
import CryptoKit

// MARK: - Data Extensions

extension Data {
    /// Calculate SHA256 hash of the data
    var sha256: String {
        let digest = SHA256.hash(data: self)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

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
    let locationData: [LocationSample]    // Player's workout path with timestamps
    
    init(workoutId: UUID, date: Date, duration: TimeInterval, totalDistance: Double, 
         heartRateData: [HeartRateSample], corners: [CLLocationCoordinate2D], locationData: [LocationSample]) {
        self.workoutId = workoutId
        self.date = date
        self.duration = duration
        self.totalDistance = totalDistance
        self.heartRateData = heartRateData
        self.corners = corners.map { CoordinateDTO(from: $0) }
        self.locationData = locationData
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

// MARK: - Enhanced Data Transfer Models

// Validated data transfer structure with checksum verification
struct ValidatedPitchDataTransfer: Codable {
    let schemaVersion: Int
    let workoutId: UUID
    let date: Date
    let duration: TimeInterval
    let totalDistance: Double
    let heartRateData: [HeartRateSample]
    let corners: [CoordinateDTO]
    let locationData: [LocationSample]
    let checksum: String
    let transferId: UUID
    
    init(from pitchData: PitchDataTransfer) {
        self.schemaVersion = 1
        self.workoutId = pitchData.workoutId
        self.date = pitchData.date
        self.duration = pitchData.duration
        self.totalDistance = pitchData.totalDistance
        self.heartRateData = pitchData.heartRateData
        self.corners = pitchData.corners
        self.locationData = pitchData.locationData
        self.transferId = UUID()
        self.checksum = Self.calculateChecksum(for: pitchData)
    }
    
    // Full initializer for testing
    init(schemaVersion: Int, workoutId: UUID, date: Date, duration: TimeInterval, totalDistance: Double, heartRateData: [HeartRateSample], corners: [CoordinateDTO], locationData: [LocationSample], checksum: String, transferId: UUID) {
        self.schemaVersion = schemaVersion
        self.workoutId = workoutId
        self.date = date
        self.duration = duration
        self.totalDistance = totalDistance
        self.heartRateData = heartRateData
        self.corners = corners
        self.locationData = locationData
        self.checksum = checksum
        self.transferId = transferId
    }
    
    // Calculate SHA256 checksum for data integrity verification
    private static func calculateChecksum(for pitchData: PitchDataTransfer) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(pitchData) else {
            return ""
        }
        
        return data.sha256
    }
    
    // Validate data integrity
    func isValid() -> Bool {
        let originalData = PitchDataTransfer(
            workoutId: workoutId,
            date: date,
            duration: duration,
            totalDistance: totalDistance,
            heartRateData: heartRateData,
            corners: corners.map { $0.coordinate },
            locationData: locationData
        )
        
        let calculatedChecksum = Self.calculateChecksum(for: originalData)
        return calculatedChecksum == checksum && !checksum.isEmpty
    }
    
    // Convert back to PitchDataTransfer
    var pitchData: PitchDataTransfer {
        PitchDataTransfer(
            workoutId: workoutId,
            date: date,
            duration: duration,
            totalDistance: totalDistance,
            heartRateData: heartRateData,
            corners: corners.map { $0.coordinate },
            locationData: locationData
        )
    }
}

// Transfer attempt tracking
struct TransferAttempt {
    let data: ValidatedPitchDataTransfer
    let timestamp: Date
    let attemptCount: Int
    let maxRetries: Int = 3
    let transferMethod: TransferMethod
    
    enum TransferMethod {
        case messageData
        case userInfo
        case fileTransfer
    }
    
    var shouldRetry: Bool {
        attemptCount < maxRetries && Date().timeIntervalSince(timestamp) < 300 // 5 minutes timeout
    }
    
    var nextRetryDelay: TimeInterval {
        // Exponential backoff: 2^attempt seconds
        return pow(2.0, Double(attemptCount))
    }
}

// Transfer confirmation message
struct TransferConfirmation: Codable {
    let transferId: UUID
    let success: Bool
    let error: String?
}

// MARK: - Enhanced Watch Connectivity Manager

class WatchConnectivityManager: NSObject, @preconcurrency WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    private let session: WCSession = .default
    
    // Retry mechanism state
    private var pendingTransfers: [UUID: TransferAttempt] = [:]
    private let retryQueue = DispatchQueue(label: "connectivity.retry", qos: .utility)
    private let accessQueue = DispatchQueue(label: "connectivity.access", qos: .userInitiated)
    
    // Transfer completion handlers
    private var transferCompletionHandlers: [UUID: (Result<Void, Error>) -> Void] = [:]
    
    override private init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
        
        // Start retry timer
        startRetryTimer()
    }
    
    // MARK: - WCSessionDelegate Methods
    
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
    
    // MARK: - Enhanced Data Validation Methods
    
    func validatePayload(_ data: Data) -> ValidationResult {
        // Check minimum data size
        guard data.count > 0 else {
            return .invalid("Empty data payload")
        }
        
        // Check maximum reasonable size (10MB)
        guard data.count < 10_000_000 else {
            return .invalid("Payload too large: \(data.count) bytes")
        }
        
        // Attempt to decode as ValidatedPitchDataTransfer
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let validatedData = try decoder.decode(ValidatedPitchDataTransfer.self, from: data)
            
            // Validate checksum
            guard validatedData.isValid() else {
                return .invalid("Checksum validation failed")
            }
            
            // Validate data ranges
            guard validatedData.duration > 0 else {
                return .invalid("Invalid workout duration")
            }
            
            guard validatedData.totalDistance >= 0 else {
                return .invalid("Invalid total distance")
            }
            
            guard validatedData.corners.count == 4 else {
                return .invalid("Invalid corner count: \(validatedData.corners.count)")
            }
            
            return .valid(validatedData)
            
        } catch {
            return .invalid("Failed to decode payload: \(error.localizedDescription)")
        }
    }
    
    enum ValidationResult {
        case valid(ValidatedPitchDataTransfer)
        case invalid(String)
    }
    
    // MARK: - Enhanced Send Methods with Retry Logic
    
    func sendPitchDataWithRetry(_ pitchData: PitchDataTransfer, completion: @escaping (Result<Void, Error>) -> Void) {
        let validatedData = ValidatedPitchDataTransfer(from: pitchData)
        
        accessQueue.async {
            // Store completion handler
            self.transferCompletionHandlers[validatedData.transferId] = completion
            
            // Create transfer attempt
            let attempt = TransferAttempt(
                data: validatedData,
                timestamp: Date(),
                attemptCount: 0,
                transferMethod: .messageData
            )
            
            self.pendingTransfers[validatedData.transferId] = attempt
            
            // Attempt initial transfer
            self.attemptTransfer(attempt)
        }
    }
    
    private func attemptTransfer(_ attempt: TransferAttempt) {
        guard session.activationState == .activated else {
            retryTransferLater(attempt, error: NSError(domain: "WatchConnectivity", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session not activated"]))
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(attempt.data)
            
            switch attempt.transferMethod {
            case .messageData:
                attemptMessageDataTransfer(data, attempt: attempt)
            case .userInfo:
                attemptUserInfoTransfer(data, attempt: attempt)
            case .fileTransfer:
                attemptFileTransfer(data, attempt: attempt)
            }
            
        } catch {
            retryTransferLater(attempt, error: error)
        }
    }
    
    private func attemptMessageDataTransfer(_ data: Data, attempt: TransferAttempt) {
        guard session.isReachable else {
            // Fall back to userInfo transfer
            let fallbackAttempt = TransferAttempt(
                data: attempt.data,
                timestamp: attempt.timestamp,
                attemptCount: attempt.attemptCount,
                transferMethod: .userInfo
            )
            attemptTransfer(fallbackAttempt)
            return
        }
        
        session.sendMessageData(data, replyHandler: { [weak self] replyData in
            self?.handleTransferSuccess(attempt.data.transferId)
        }) { [weak self] error in
            self?.retryTransferLater(attempt, error: error)
        }
    }
    
    private func attemptUserInfoTransfer(_ data: Data, attempt: TransferAttempt) {
        let userInfo = [
            "validatedWorkoutData": data,
            "transferId": attempt.data.transferId.uuidString
        ]
        
        do {
            session.transferUserInfo(userInfo)
            // UserInfo transfers don't have immediate feedback, so we rely on confirmation
            scheduleTransferTimeout(attempt)
        } catch {
            retryTransferLater(attempt, error: error)
        }
    }
    
    private func attemptFileTransfer(_ data: Data, attempt: TransferAttempt) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("workout_\(attempt.data.transferId.uuidString).json")
        
        do {
            try data.write(to: tempURL)
            session.transferFile(tempURL, metadata: [
                "transferId": attempt.data.transferId.uuidString,
                "type": "validatedWorkoutData"
            ])
            scheduleTransferTimeout(attempt)
        } catch {
            retryTransferLater(attempt, error: error)
        }
    }
    
    private func scheduleTransferTimeout(_ attempt: TransferAttempt) {
        retryQueue.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.accessQueue.async {
                // Check if transfer is still pending
                if self?.pendingTransfers[attempt.data.transferId] != nil {
                    self?.retryTransferLater(attempt, error: NSError(domain: "WatchConnectivity", code: -2, userInfo: [NSLocalizedDescriptionKey: "Network timeout"]))
                }
            }
        }
    }
    
    private func retryTransferLater(_ attempt: TransferAttempt, error: Error) {
        guard attempt.shouldRetry else {
            handleTransferFailure(attempt.data.transferId, error: error)
            return
        }
        
        let nextAttempt = TransferAttempt(
            data: attempt.data,
            timestamp: Date(),
            attemptCount: attempt.attemptCount + 1,
            transferMethod: getNextTransferMethod(attempt.transferMethod)
        )
        
        pendingTransfers[attempt.data.transferId] = nextAttempt
        
        let delay = attempt.nextRetryDelay
        print("Retrying transfer \(attempt.data.transferId) in \(delay) seconds (attempt \(nextAttempt.attemptCount))")
        
        retryQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.attemptTransfer(nextAttempt)
        }
    }
    
    private func getNextTransferMethod(_ currentMethod: TransferAttempt.TransferMethod) -> TransferAttempt.TransferMethod {
        switch currentMethod {
        case .messageData:
            return .userInfo
        case .userInfo:
            return .fileTransfer
        case .fileTransfer:
            return .messageData // Cycle back
        }
    }
    
    private func handleTransferSuccess(_ transferId: UUID) {
        accessQueue.async {
            self.pendingTransfers.removeValue(forKey: transferId)
            if let completion = self.transferCompletionHandlers.removeValue(forKey: transferId) {
                completion(.success(()))
            }
        }
    }
    
    private func handleTransferFailure(_ transferId: UUID, error: Error) {
        accessQueue.async {
            self.pendingTransfers.removeValue(forKey: transferId)
            if let completion = self.transferCompletionHandlers.removeValue(forKey: transferId) {
                completion(.failure(error))
            }
        }
        
        print("WatchConnectivity transfer failure for \(transferId): \(error.localizedDescription)")
    }
    
    // MARK: - Retry Timer
    
    private func startRetryTimer() {
        retryQueue.async {
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.processRetries()
            }
        }
    }
    
    private func processRetries() {
        accessQueue.async {
            let expiredTransfers = self.pendingTransfers.filter { _, attempt in
                !attempt.shouldRetry
            }
            
            for (transferId, attempt) in expiredTransfers {
                self.handleTransferFailure(transferId, error: NSError(domain: "WatchConnectivity", code: -2, userInfo: [NSLocalizedDescriptionKey: "Network timeout"]))
            }
        }
    }
    
    // MARK: - Legacy Methods (Backward Compatibility)
    
    func sendWorkout(_ workout: WorkoutSessionDTO) {
        // Convert to new format and use enhanced sending
        let pitchData = PitchDataTransfer(
            workoutId: workout.id,
            date: workout.date,
            duration: workout.duration,
            totalDistance: workout.totalDistance,
            heartRateData: workout.heartRateData,
            corners: [], // Legacy workouts don't have corners
            locationData: workout.locationData
        )
        
        sendPitchDataWithRetry(pitchData) { result in
            switch result {
            case .success:
                print("Legacy workout sent successfully")
            case .failure(let error):
                print("Failed to send legacy workout: \(error.localizedDescription)")
            }
        }
    }
    
    func sendPitchData(_ pitchData: PitchDataTransfer) {
        sendPitchDataWithRetry(pitchData) { result in
            switch result {
            case .success:
                print("Pitch data sent successfully")
            case .failure(let error):
                print("Failed to send pitch data: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Enhanced Receive Methods
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        // Handle legacy workout data
        if let data = userInfo["workoutData"] as? Data {
            handleLegacyWorkoutData(data)
            return
        }
        
        // Handle validated workout data
        if let data = userInfo["validatedWorkoutData"] as? Data,
           let transferIdString = userInfo["transferId"] as? String,
           let transferId = UUID(uuidString: transferIdString) {
            handleValidatedWorkoutData(data, transferId: transferId)
            return
        }
        
        print("WatchConnectivity: Unknown userInfo format received")
    }
    
    @MainActor func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        let validation = validatePayload(messageData)
        
        switch validation {
        case .valid(let validatedData):
            processValidatedWorkoutData(validatedData)
            sendTransferConfirmation(transferId: validatedData.transferId, success: true)
            
        case .invalid(let reason):
            print("WatchConnectivity: Data validation failed - \(reason)")
        }
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let transferIdString = file.metadata?["transferId"] as? String,
              let transferId = UUID(uuidString: transferIdString),
              file.metadata?["type"] as? String == "validatedWorkoutData" else {
            ErrorLogger.shared.logError(
                PivotPlayError.corruptData("Invalid file transfer metadata"),
                context: ErrorContext(component: "WatchConnectivityManager", operation: "didReceiveFile"),
                severity: .warning
            )
            return
        }
        
        do {
            let data = try Data(contentsOf: file.fileURL)
            handleValidatedWorkoutData(data, transferId: transferId)
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: file.fileURL)
        } catch {
            ErrorLogger.shared.logError(
                error,
                context: ErrorContext(component: "WatchConnectivityManager", operation: "didReceiveFile"),
                severity: .error
            )
        }
    }
    
    // MARK: - Data Processing Methods
    
    private func handleLegacyWorkoutData(_ data: Data) {
        do {
            let decoder = JSONDecoder()
            let workoutDTO = try decoder.decode(WorkoutSessionDTO.self, from: data)
            
            #if os(iOS)
            if let workout = WorkoutSession(from: workoutDTO) {
                Task {
                    await MainActor.run {
                        let saveResult = WorkoutStorage.shared.saveWorkout(workout)
                        switch saveResult {
                        case .success:
                            ErrorLogger.shared.logDebug("Legacy workout saved successfully", component: "WatchConnectivityManager")
                        case .failure(let error):
                            ErrorLogger.shared.logError(error, context: ErrorContext(component: "WatchConnectivityManager", operation: "save legacy workout"), severity: .error)
                        }
                    }
                }
            }
            #endif
        } catch {
            ErrorLogger.shared.logError(
                PivotPlayError.corruptData("Failed to decode legacy workout: \(error.localizedDescription)"),
                context: ErrorContext(component: "WatchConnectivityManager", operation: "handleLegacyWorkoutData"),
                severity: .error
            )
        }
    }
    
    private func handleValidatedWorkoutData(_ data: Data, transferId: UUID) {
        let validation = validatePayload(data)
        
        switch validation {
        case .valid(let validatedData):
            Task {
                await MainActor.run {
                    self.processValidatedWorkoutData(validatedData)
                }
            }
            sendTransferConfirmation(transferId: transferId, success: true)
            
        case .invalid(let reason):
            ErrorLogger.shared.logError(
                PivotPlayError.dataValidationFailed(reason),
                context: ErrorContext(component: "WatchConnectivityManager", operation: "handleValidatedWorkoutData"),
                severity: .error
            )
            sendTransferConfirmation(transferId: transferId, success: false, error: reason)
        }
    }
    
    @MainActor private func processValidatedWorkoutData(_ validatedData: ValidatedPitchDataTransfer) {
        #if os(iOS)
        let workout = WorkoutSession(
            id: validatedData.workoutId,
            date: validatedData.date,
            duration: validatedData.duration,
            totalDistance: validatedData.totalDistance,
            heartRateData: validatedData.heartRateData,
            locationData: validatedData.locationData,
            corners: validatedData.corners
        )
        
        let saveResult = WorkoutStorage.shared.saveWorkout(workout)
        switch saveResult {
        case .success:
            ErrorLogger.shared.logDebug("Validated workout saved successfully", component: "WatchConnectivityManager")
            
            // Process heatmap data
            Task {
                await HeatmapPipeline.shared.ingest(validatedData.pitchData)
            }
            
        case .failure(let error):
            ErrorLogger.shared.logError(error, context: ErrorContext(component: "WatchConnectivityManager", operation: "save validated workout"), severity: .error)
        }
        #endif
    }
    
    private func sendTransferConfirmation(transferId: UUID, success: Bool, error: String? = nil) {
        let confirmation = TransferConfirmation(transferId: transferId, success: success, error: error)
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(confirmation)
            
            if session.isReachable {
                session.sendMessageData(data, replyHandler: nil) { error in
                    ErrorLogger.shared.logError(
                        error,
                        context: ErrorContext(component: "WatchConnectivityManager", operation: "sendTransferConfirmation"),
                        severity: .warning
                    )
                }
            }
        } catch {
            ErrorLogger.shared.logError(
                error,
                context: ErrorContext(component: "WatchConnectivityManager", operation: "encode confirmation"),
                severity: .warning
            )
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
