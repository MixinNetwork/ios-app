import Foundation
import MixinServices

extension WebSocketService.SendingError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .timedOut:
            R.string.localizable.error_connection_timeout()
        case let .response(error):
            error.localizedDescription
        }
    }
    
}
