import Foundation

extension URLError {
    
    public var worthReporting: Bool {
        switch code {
        case .cancelled, .timedOut, .cannotFindHost, .networkConnectionLost,
                .dnsLookupFailed, .notConnectedToInternet, .badServerResponse,
                .userCancelledAuthentication:
            false
        default:
            true
        }
    }
    
}
