import UIKit
import SnapKit
import LocalAuthentication
import MixinServices

final class ScreenLockManager {
    
    private enum State: String {
        case none
        case authenticationFailed
        case authenticationSucceed
        case didEnterBackground
        case willResignActive
        case didBecomeActive
    }
    
    static let shared = ScreenLockManager()
    
    private let screenLockView = ScreenLockView()
    private var hasLastBiometricAuthenticationFailed = false
    private var state: State = .none {
        didSet {
            updateState(from: oldValue, to: state)
        }
    }
    
    private init() {
        guard let controller = AppDelegate.current.mainWindow.rootViewController else {
            return
        }
        controller.view.addSubview(screenLockView)
        screenLockView.snp.makeEdgesEqualToSuperview()
        screenLockView.isHidden = true
        screenLockView.tapUnlockAction = { [weak self] in
            self?.performBiometricAuthentication()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    func lockScreenIfNeeded() {
        guard needsBiometricAuthentication else {
            return
        }
        showScreenLockView()
        performBiometricAuthentication()
    }
    
}

extension ScreenLockManager {
    
    private var needsBiometricAuthentication: Bool {
        guard isBiometricAuthenticationEnabled else {
            return false
        }
        if let date = AppGroupUserDefaults.User.lastLockScreenBiometricVerifiedDate {
            return -date.timeIntervalSinceNow > AppGroupUserDefaults.User.lockScreenTimeoutInterval
        } else {
            return true
        }
    }
    
    private var isBiometricAuthenticationEnabled: Bool {
        biometryType != .none && AppGroupUserDefaults.User.lockScreenWithBiometricAuthentication
    }
    
    private func performBiometricAuthentication() {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: R.string.localizable.screen_lock_unlock_description(biometryType.localizedName)) { success, error in
            DispatchQueue.main.async {
                self.state = success ? .authenticationSucceed : .authenticationFailed
            }
        }
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
    
    private func updateState(from: State, to: State) {
        switch to {
        case .willResignActive:
            if isBiometricAuthenticationEnabled && !hasLastBiometricAuthenticationFailed {
                showScreenLockView()
            }
        case .didBecomeActive:
            if from == .didEnterBackground {
                if needsBiometricAuthentication {
                    showScreenLockView()
                    performBiometricAuthentication()
                } else {
                    hideScreenLockView()
                }
            } else if from == .willResignActive {
                if !hasLastBiometricAuthenticationFailed {
                    hideScreenLockView()
                }
            }
        case .didEnterBackground:
            if needsBiometricAuthentication {
                screenLockView.showUnlockOption(false)
            }
        case .authenticationSucceed:
            hasLastBiometricAuthenticationFailed = false
            hideScreenLockView()
            AppGroupUserDefaults.User.lastLockScreenBiometricVerifiedDate = Date()
        case .authenticationFailed:
            hasLastBiometricAuthenticationFailed = true
            screenLockView.showUnlockOption(true)
        default:
            break
        }
    }
    
}


