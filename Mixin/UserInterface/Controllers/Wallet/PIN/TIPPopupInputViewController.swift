import UIKit
import MixinServices

final class TIPPopupInputViewController: PinValidationViewController {
    
    enum Action {
        case migrate((_ pin: String) -> Void)
        case `continue`(TIP.InterruptionContext, _ onSuccess: @MainActor @Sendable () -> Void)
    }
    
    struct ReportingError: Error, CustomNSError {
        
        let underlying: Error
        let location: String
        
        var errorUserInfo: [String : Any] {
            ["underlying": "\(underlying)", "location": location]
        }
        
    }
    
    private let action: Action
    
    private var oldPIN: String?
    
    init(action: Action) {
        self.action = action
        let nib = R.nib.pinValidationView
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = presentationManager
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch action {
        case .migrate:
            titleLabel.text = R.string.localizable.enter_your_pin()
        case let .continue(context, _):
            switch context.action {
            case .change:
                if oldPIN == nil {
                    titleLabel.text = R.string.localizable.enter_your_old_pin()
                } else {
                    titleLabel.text = R.string.localizable.enter_your_new_pin()
                }
            case .create:
                titleLabel.text = R.string.localizable.enter_your_pin()
            case .migrate:
                if oldPIN == nil {
                    titleLabel.text = R.string.localizable.enter_your_old_pin()
                } else {
                    titleLabel.text = R.string.localizable.enter_your_new_pin()
                }
            }
        }
        descriptionLabel.text = nil
    }
    
    override func validate(pin: String) {
        switch action {
        case .migrate(let completion):
            AccountAPI.verify(pin: pin) { result in
                switch result {
                case .success:
                    self.presentingViewController?.dismiss(animated: true) {
                        completion(pin)
                    }
                case .failure(let error):
                    self.handle(error: error)
                }
            }
        case let .continue(context, onSuccess):
            switch context.action {
            case .create:
                switch context.situation {
                case .pendingSign(let failedSigners):
                    continueCreate(with: pin, failedSigners: failedSigners, onSuccess: onSuccess)
                case .pendingUpdate:
                    continueCreate(with: pin, failedSigners: [], onSuccess: onSuccess)
                }
            case .change:
                if let old = oldPIN {
                    switch context.situation {
                    case .pendingSign(let failedSigners):
                        continueChange(old: old, isOldPINLegacy: false, new: pin, failedSigners: failedSigners, onSuccess: onSuccess)
                    case .pendingUpdate:
                        continueChange(old: old, isOldPINLegacy: false, new: pin, failedSigners: [], onSuccess: onSuccess)
                    }
                } else {
                    loadingIndicator.stopAnimating()
                    titleLabel.text = R.string.localizable.enter_your_new_pin()
                    descriptionLabel.text = nil
                    pinField.clear()
                    pinField.isHidden = false
                    pinField.receivesInput = true
                    self.oldPIN = pin
                }
            case .migrate:
                if let old = oldPIN {
                    let failedSigners: [TIPSigner]
                    switch context.situation {
                    case .pendingSign(let signers):
                        failedSigners = signers
                    case .pendingUpdate:
                        failedSigners = []
                    }
                    continueChange(old: old, isOldPINLegacy: true, new: pin, failedSigners: failedSigners, onSuccess: onSuccess)
                } else {
                    loadingIndicator.stopAnimating()
                    titleLabel.text = R.string.localizable.enter_your_new_pin()
                    descriptionLabel.text = nil
                    pinField.clear()
                    pinField.isHidden = false
                    pinField.receivesInput = true
                    self.oldPIN = pin
                }
            }
        }
    }
    
    private func continueCreate(
        with pin: String,
        failedSigners: [TIPSigner],
        onSuccess: @MainActor @Sendable @escaping () -> Void
    ) {
#if DEBUG
        if TIPDiagnostic.uiTestOnly {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: onSuccess)
            return
        }
#endif
        Logger.tip.info(category: "TIPPopupInput", message: "Continue create with failed signers: \(failedSigners.map(\.index))")
        Task {
            do {
                let (_, account) = try await TIP.createTIPPriv(
                    pin: pin,
                    failedSigners: failedSigners,
                    legacyPIN: nil,
                    forRecover: false,
                    progressHandler: nil
                )
                AppGroupUserDefaults.Wallet.lastPINVerifiedDate = Date()
                try await TIP.registerToSafeIfNeeded(account: account, pin: pin)
                Logger.tip.info(category: "TIPPopupInput", message: "Registered to safe")
                try await TIP.registerDefaultCommonWalletIfNeeded(pin: pin)
                Logger.tip.info(category: "TIPPopupInput", message: "Registered classic wallet")
                AppGroupUserDefaults.User.loginPINValidated = true
                await MainActor.run(body: onSuccess)
            } catch {
                let reportingError = ReportingError(underlying: error, location: "ContinueCreate")
                reporter.report(error: reportingError)
                Logger.tip.error(category: "TIPPopupInput", message: "Failed to create: \(error)")
                await MainActor.run {
                    if let error = error as? MixinAPIError {
                        handle(error: error)
                    } else {
                        handle(error: .pinEncryptionFailed(error))
                    }
                }
            }
        }
    }
    
    private func continueChange(
        old: String,
        isOldPINLegacy: Bool,
        new: String,
        failedSigners: [TIPSigner],
        onSuccess: @MainActor @Sendable @escaping () -> Void
    ) {
#if DEBUG
        if TIPDiagnostic.uiTestOnly {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: onSuccess)
            return
        }
#endif
        Logger.tip.info(category: "TIPPopupInput", message: "Continue change with failed signers: \(failedSigners.map(\.index))")
        Task {
            do {
                let account: Account?
                if isOldPINLegacy {
                    (_, account) = try await TIP.createTIPPriv(
                        pin: new,
                        failedSigners: failedSigners,
                        legacyPIN: old,
                        forRecover: false,
                        progressHandler: nil
                    )
                } else {
                    let isCounterBalanced: Bool
                    switch action {
                    case .continue(let context, _):
                        isCounterBalanced = context.maxNodeCounter == context.accountTIPCounter
                    case .migrate:
                        isCounterBalanced = true
                    }
                    account = try await TIP.updateTIPPriv(
                        oldPIN: old,
                        newPIN: new,
                        isCounterBalanced: isCounterBalanced,
                        failedSigners: failedSigners,
                        progressHandler: nil
                    )
                }
                try await TIP.registerToSafeIfNeeded(account: account, pin: new)
                try await TIP.registerDefaultCommonWalletIfNeeded(pin: new)
                if AppGroupUserDefaults.Wallet.payWithBiometricAuthentication {
                    Keychain.shared.storePIN(pin: new)
                }
                AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = PeriodicPinVerificationInterval.min
                AppGroupUserDefaults.Wallet.lastPINVerifiedDate = Date()
                AppGroupUserDefaults.User.loginPINValidated = true
                Logger.tip.info(category: "TIPPopupInput", message: "Changed successfully")
                await MainActor.run(body: onSuccess)
            } catch let error as TIPNode.Error {
                let reportingError = ReportingError(underlying: error, location: "ContinueChange.Node")
                reporter.report(error: reportingError)
                Logger.tip.error(category: "TIPPopupInput", message: "Failed to change: \(error)")
                await MainActor.run {
                    loadingIndicator.stopAnimating()
                    titleLabel.text = R.string.localizable.enter_your_old_pin()
                    descriptionLabel.textColor = .mixinRed
                    descriptionLabel.text = error.localizedDescription
                    pinField.isHidden = false
                    pinField.clear()
                    pinField.receivesInput = true
                    oldPIN = nil
                }
            } catch {
                let reportingError = ReportingError(underlying: error, location: "ContinueChange")
                reporter.report(error: reportingError)
                Logger.tip.error(category: "TIPPopupInput", message: "Failed to change: \(error)")
                await MainActor.run {
                    if let error = error as? MixinAPIError {
                        handle(error: error)
                    } else {
                        handle(error: .pinEncryptionFailed(error))
                    }
                    titleLabel.text = R.string.localizable.enter_your_old_pin()
                    oldPIN = nil
                }
            }
        }
    }
    
}
