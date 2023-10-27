import UIKit
import MixinServices

class TIPPopupInputViewController: PinValidationViewController {
    
    enum Action {
        case migrate((_ pin: String) -> Void)
        case `continue`(TIP.InterruptionContext, _ onSuccess: @MainActor @Sendable () -> Void)
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
                switch context.situation {
                case .pendingUpdate:
                    titleLabel.text = R.string.localizable.enter_your_new_pin()
                case .pendingSign:
                    if oldPIN == nil {
                        titleLabel.text = R.string.localizable.enter_your_old_pin()
                    } else {
                        titleLabel.text = R.string.localizable.enter_your_new_pin()
                    }
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
                switch context.situation {
                case .pendingSign(let failedSigners):
                    if let old = oldPIN {
                        continueChange(old: old, isOldPINLegacy: false, new: pin, failedSigners: failedSigners, onSuccess: onSuccess)
                    } else {
                        loadingIndicator.stopAnimating()
                        titleLabel.text = R.string.localizable.enter_your_new_pin()
                        descriptionLabel.text = nil
                        pinField.clear()
                        pinField.isHidden = false
                        pinField.receivesInput = true
                        self.oldPIN = pin
                    }
                case .pendingUpdate:
                    continueChange(old: nil, isOldPINLegacy: false, new: pin, failedSigners: [], onSuccess: onSuccess)
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
                try await TIP.createTIPPriv(pin: pin,
                                            failedSigners: failedSigners,
                                            legacyPIN: nil,
                                            forRecover: false,
                                            progressHandler: nil)
                AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                try await TIP.registerToSafe(pin: pin)
                Logger.tip.info(category: "TIPPopupInput", message: "Registered to safe")
                await MainActor.run(body: onSuccess)
            } catch {
                reporter.report(error: error)
                Logger.tip.error(category: "TIPPopupInput", message: "Failed to create: \(error)")
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
    
    private func continueChange(
        old: String?,
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
                if isOldPINLegacy {
                    try await TIP.createTIPPriv(pin: new,
                                                failedSigners: failedSigners,
                                                legacyPIN: old,
                                                forRecover: false,
                                                progressHandler: nil)
                } else {
                    try await TIP.updateTIPPriv(oldPIN: old,
                                                newPIN: new,
                                                failedSigners: failedSigners,
                                                progressHandler: nil)
                }
                if AppGroupUserDefaults.Wallet.payWithBiometricAuthentication {
                    Keychain.shared.storePIN(pin: new)
                }
                AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = PeriodicPinVerificationInterval.min
                AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                Logger.tip.info(category: "TIPPopupInput", message: "Changed successfully")
                try await TIP.registerToSafe(pin: new)
                Logger.tip.info(category: "TIPPopupInput", message: "Registered to safe")
                await MainActor.run(body: onSuccess)
            } catch let error as TIPNode.Error {
                reporter.report(error: error)
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
                reporter.report(error: error)
                Logger.tip.error(category: "TIPPopupInput", message: "Failed to change: \(error)")
                await MainActor.run {
                    if let error = error as? MixinAPIError {
                        handle(error: error)
                    } else {
                        handle(error: .pinEncryption(error))
                    }
                    titleLabel.text = R.string.localizable.enter_your_old_pin()
                    oldPIN = nil
                }
            }
        }
    }
    
}
