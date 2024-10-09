import UIKit
import MixinServices

final class PushNotificationDiagnostic {
    
    enum TokenStatus {
        case never
        case unauthorized
        case requested(Date)
        case failed(Error)
        case sent(Date)
    }
    
    enum RegistrationStatus {
        case unknown
        case success(Date)
        case failed(Error)
    }
    
    static let global = PushNotificationDiagnostic()
    static let statusDidUpdateNotification = Notification.Name("one.mixin.messenger.PushNotificationDiagnostic.StatusChange")
    
    var token: TokenStatus = .never {
        didSet {
            NotificationCenter.default.post(name: Self.statusDidUpdateNotification, object: self)
        }
    }
    
    var registration: RegistrationStatus = .unknown {
        didSet {
            NotificationCenter.default.post(name: Self.statusDidUpdateNotification, object: self)
        }
    }
    
    var description: String {
        let tokenStatus = switch token {
        case .never:
            "Never"
        case .unauthorized:
            "Unauthorized"
        case .requested(let date):
            "Request at \(date)"
        case .failed(let error):
            error.localizedDescription
        case .sent(let date):
            "Sent at \(date)"
        }
        let registrationStatus = switch registration {
        case .unknown:
            "Unknown"
        case .success(let date):
            "Success at \(date)"
        case .failed(let error):
            error.localizedDescription
        }
        return """
        Token: \(tokenStatus)
        Registration: \(registrationStatus)
        """
    }
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reset),
            name: LoginManager.didLogoutNotification,
            object: nil
        )
    }
    
    @objc private func reset() {
        token = .never
        registration = .unknown
    }
    
}
