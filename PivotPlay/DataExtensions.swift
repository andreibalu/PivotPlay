import Foundation
import CryptoKit

// MARK: - Data Extensions for Checksum Calculation

extension Data {
    /// Calculate SHA256 hash of the data
    var sha256: String {
        let digest = SHA256.hash(data: self)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}