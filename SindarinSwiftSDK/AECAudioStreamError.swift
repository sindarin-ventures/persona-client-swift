import Foundation

/**
 The `AECAudioStreamError` enumeration defines errors that can be thrown by the `AECAudioStream` class.
 
 - Version: 1.0
 */
public enum AECAudioStreamError: Error {
    /// An error that indicates an `OSStatus` error occurred.
    case osStatusError(status: OSStatus)
}
