import UIKit
import SnapKit
import LocalAuthentication
import MixinServices

fileprivate enum ScreenLockState: String {
    case none
    case validAuthenticationFailed
    case validAuthenticationSuccess
    case didEnterBackground
    case willResignActive
    case didBecomeActive
}

final class ScreenLockManager: NSObject {

    static let shared = ScreenLockManager()

    private let screenLockView = ScreenLockView()
    private var pendingValidBiometricAuthentication = false
    private var state: ScreenLockState = .none {
        didSet {
            updateState(from: oldValue, to: state)
        }
    }

    override init() {
        super.init()
        
        guard let controller = AppDelegate.current.mainWindow.rootViewController else {
            return
        }
        controller.view.addSubview(screenLockView)
        screenLockView.snp.makeEdgesEqualToSuperview()
        screenLockView.isHidden = true
        screenLockView.tapUnlockAction = { [weak self] in
            guard let self = self else { return }
            self.validateBiometricAuthentication()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    class func checkIfNeedLockScreen() {
        guard Self.shared.shouldValidateBiometricAuthentication() else {
            return
        }
        Self.shared.showScreenLockView()
        Self.shared.validateBiometricAuthentication()
    }

}

extension ScreenLockManager {

    private func validateBiometricAuthentication() {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: R.string.localizable.screen_lock_unlock_description(biometryType.localizedName)) { success, error in
            DispatchQueue.main.async {
                self.state = success ? .validAuthenticationSuccess : .validAuthenticationFailed
            }
        }
    }
    
    private func shouldValidateBiometricAuthentication() -> Bool {
        guard isEnableBiometricAuthentication() else {
            return false
        }
        let shouldValidateBiometric: Bool
        if let date = AppGroupUserDefaults.User.lastLockScreenBiometricVerifiedDate {
            shouldValidateBiometric = -date.timeIntervalSinceNow > AppGroupUserDefaults.User.lockScreenTimeoutInterval
        } else {
            shouldValidateBiometric = true
        }
        return shouldValidateBiometric
    }

    private func isEnableBiometricAuthentication() -> Bool {
        return biometryType != .none && AppGroupUserDefaults.User.lockScreenWithBiometricAuthentication
    }
    
    private func showScreenLockView() {
        screenLockView.isHidden = false
        screenLockView.showUnlockOption(false)
    }
    
    private func hideScreenLockView() {
        screenLockView.isHidden = true
    }

}

extension ScreenLockManager {

    @objc private func applicationWillResignActive() {
        state = .willResignActive
    }

    @objc private func applicationDidBecomeActive() {
        state = .didBecomeActive
    }

    @objc private func applicationDidEnterBackground() {
        state = .didEnterBackground
    }

}

extension ScreenLockManager {
    
    private func updateState(from: ScreenLockState, to: ScreenLockState) {
        switch to {
        case .willResignActive:
            if isEnableBiometricAuthentication() && !pendingValidBiometricAuthentication {
                showScreenLockView()
            }
        case .didBecomeActive:
            if from == .didEnterBackground {
                if shouldValidateBiometricAuthentication() {
                    showScreenLockView()
                    validateBiometricAuthentication()
                } else {
                    hideScreenLockView()
                }
            } else if from == .willResignActive {
                if !pendingValidBiometricAuthentication {
                    hideScreenLockView()
                }
            }
        case .didEnterBackground:
            if shouldValidateBiometricAuthentication() {
                screenLockView.showUnlockOption(false)
            }
        case .validAuthenticationSuccess:
            pendingValidBiometricAuthentication = false
            hideScreenLockView()
            AppGroupUserDefaults.User.lastLockScreenBiometricVerifiedDate = Date()
        case .validAuthenticationFailed:
            pendingValidBiometricAuthentication = true
            screenLockView.showUnlockOption(true)
        default:
            break
        }
    }
    
}


