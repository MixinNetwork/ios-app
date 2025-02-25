import Foundation
import DeviceCheck
import MixinServices

final class SessionReporter {
    
    private let reportInterval: TimeInterval = 6 * .hour
    
    private var lastReportDate: Date?
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reportIfOutdated),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc func reportIfOutdated() {
        assert(Thread.isMainThread)
        let isOutdated = if let lastReportDate {
            -lastReportDate.timeIntervalSinceNow > reportInterval
        } else {
            true
        }
        guard isOutdated else {
            return
        }
        self.lastReportDate = Date()
        DCDevice.current.generateToken { (data, error) in
            if let error {
                Logger.general.error(category: "SessionReporter", message: "\(error)")
            }
            guard let token = data?.base64EncodedString() else {
                Logger.general.error(category: "SessionReporter", message: "Missing data")
                return
            }
            guard LoginManager.shared.isLoggedIn else {
                Logger.general.error(category: "SessionReporter", message: "Not logged in")
                return
            }
            Logger.general.info(category: "SessionReporter", message: "Report at \(Date())")
            AccountAPI.updateSession(deviceCheckToken: token, completion: nil)
        }
    }
    
}
