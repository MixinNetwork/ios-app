import UIKit
import MixinServices

class TIPValidatePINViewController: PinValidationViewController {
    
    enum Action {
        case migrate((_ pin: String) -> Void)
        case `continue`(TIP.InterruptionContext, _ onSuccess: @MainActor @Sendable () -> Void)
    }
    
    private let action: Action
    
    private var oldPIN: String?
    
    init(action: Action) {
        switch action {
        case let .continue(context, _) where context.action == .migrate:
            assertionFailure("Continue migration with `Action.migrate`")
        default:
            break
        }
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
                switch context.situation {
                case .pendingUpdate:
                    titleLabel.text = "Enter your new PIN"
                case .pendingSign:
                    if oldPIN == nil {
                        titleLabel.text = "Enter your old PIN"
                    } else {
                        titleLabel.text = "Enter your new PIN"
                    }
                }
            case .create, .migrate:
                titleLabel.text = R.string.localizable.enter_your_pin()
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
                switch context.situation {
                case .pendingSign(let failedSigners):
                    if let old = oldPIN {
                        continueChange(old: old, new: pin, failedSigners: failedSigners, onSuccess: onSuccess)
                    } else {
                        continueChangeIfVerified(oldPIN: pin)
                    }
                case .pendingUpdate:
                    continueChange(old: nil, new: pin, failedSigners: [], onSuccess: onSuccess)
                }
            case .migrate:
                assertionFailure("Continue migration with `Action.migrate`")
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
        Task {
            do {
                try await TIP.createTIPPriv(pin: pin,
                                            failedSigners: failedSigners,
                                            legacyPIN: nil,
                                            forRecover: false,
                                            progressHandler: nil)
                AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                await MainActor.run(body: onSuccess)
            } catch {
                Logger.general.warn(category: "TIPValidatePINViewController", message: "Failed to create: \(error)")
                await MainActor.run {
                    if let error = error as? MixinAPIError {
                        handle(error: error)
                    } else {
                        handle(error: .pinEncryption(error))
                    }
                }
            }
        }
    }
    
    private func continueChangeIfVerified(oldPIN: String) {
        AccountAPI.verify(pin: oldPIN) { result in
            switch result {
            case .success:
                self.titleLabel.text = "Enter your new PIN"
                self.pinField.clear()
                self.pinField.isHidden = false
                self.pinField.receivesInput = true
                self.descriptionLabel.text = nil
                self.loadingIndicator.stopAnimating()
                self.oldPIN = oldPIN
            case .failure(let error):
                self.handle(error: error)
            }
        }
    }
    
    private func continueChange(
        old: String?,
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
        Task {
            do {
                try await TIP.updateTIPPriv(oldPIN: old,
                                            newPIN: new,
                                            failedSigners: failedSigners,
                                            progressHandler: nil)
                if AppGroupUserDefaults.Wallet.payWithBiometricAuthentication {
                    Keychain.shared.storePIN(pin: new)
                }
                AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = PeriodicPinVerificationInterval.min
                AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                await MainActor.run(body: onSuccess)
            } catch TIPNode.Error.differentIdentity, TIPNode.Error.notAllSignersSucceed {
                await MainActor.run {
                    loadingIndicator.stopAnimating()
                    pinField.isHidden = false
                    pinField.clear()
                    descriptionLabel.textColor = .mixinRed
                    descriptionLabel.text = "Wrong New PIN?"
                    pinField.receivesInput = true
                }
            } catch {
                Logger.general.warn(category: "TIPActionViewController", message: "Failed to change: \(error)")
                await MainActor.run {
                    if let error = error as? MixinAPIError {
                        handle(error: error)
                    } else {
                        handle(error: .pinEncryption(error))
                    }
                }
            }
        }
    }
    
}
