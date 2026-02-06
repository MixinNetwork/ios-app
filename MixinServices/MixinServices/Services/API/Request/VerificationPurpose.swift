import Foundation

public enum VerificationPurpose: String {
    case session = "SESSION"
    case anonymousSession = "ANONYMOUS_SESSION"
    case phone = "PHONE"
    case deactivate = "DEACTIVATED"
    case none = "NONE"
}
