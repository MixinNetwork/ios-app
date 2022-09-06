import UIKit
import MixinServices

class TIPActionViewController: UIViewController {
    
    enum Action {
        case create(pin: String)
        case change(old: String?, new: String)
        case migrate(pin: String)
    }
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var activityIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var progressLabel: UILabel!
    
    private let action: Action
    private let context: TIP.InterruptionContext?
    
    private var tipNavigationController: TIPNavigationViewController? {
        navigationController as? TIPNavigationViewController
    }
    
    init(action: Action, context: TIP.InterruptionContext?) {
        self.action = action
        self.context = context
        let nib = R.nib.tipActionView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let failedSigners = context?.failedSigners ?? []
        switch action {
        case let .create(pin):
            titleLabel.text = "创建钱包"
#if DEBUG
            if TIPDiagnostic.uiTestOnly {
                emulateProgress()
                return
            }
#endif
            Task {
                do {
                    try await TIP.createTIPPriv(pin: pin,
                                                failedSigners: failedSigners,
                                                legacyPIN: nil,
                                                forRecover: false,
                                                progressHandler: showProgress(step:))
                    AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                    await MainActor.run(body: finish)
                } catch {
                    Logger.general.warn(category: "TIPActionViewController", message: "Failed to create: \(error)")
                    await handleError()
                }
            }
        case let .change(old, new):
            titleLabel.text = "修改 PIN"
#if DEBUG
            if TIPDiagnostic.uiTestOnly {
                emulateProgress()
                return
            }
#endif
            Task {
                do {
                    try await TIP.updateTIPPriv(oldPIN: old,
                                                newPIN: new,
                                                failedSigners: failedSigners,
                                                progressHandler: showProgress(step:))
                    if AppGroupUserDefaults.Wallet.payWithBiometricAuthentication {
                        Keychain.shared.storePIN(pin: new)
                    }
                    AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = PeriodicPinVerificationInterval.min
                    AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                    await MainActor.run(body: finish)
                } catch {
                    // FIXME: Catch `TIPNode.Error.differentIdentity` and tell user PIN is different from previous input
                    Logger.general.warn(category: "TIPActionViewController", message: "Failed to change: \(error)")
                    await handleError()
                }
            }
        case let .migrate(pin):
            titleLabel.text = "升级 TIP"
#if DEBUG
            if TIPDiagnostic.uiTestOnly {
                emulateProgress()
                return
            }
#endif
            Task {
                do {
                    try await TIP.createTIPPriv(pin: pin,
                                                failedSigners: failedSigners,
                                                legacyPIN: pin,
                                                forRecover: false,
                                                progressHandler: showProgress(step:))
                    AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                    await MainActor.run(body: finish)
                } catch {
                    Logger.general.warn(category: "TIPActionViewController", message: "Failed to migrate: \(error)")
                    await handleError()
                }
            }
        }
    }
    
    @MainActor @Sendable
    private func finish() {
        let title: String
        switch action {
        case .create:
            title = R.string.localizable.set_pin_successfully()
        case .change:
            title = R.string.localizable.change_pin_successfully()
        case .migrate:
            title = "Migrated"
        }
        alert(title) { (_) in
            self.tipNavigationController?.dismissToDestination(animated: true)
        }
    }
    
    private func handleError() async {
        do {
            guard let tipCounter = LoginManager.shared.account?.tipCounter else {
                return
            }
            let status = try await TIP.checkCounter(tipCounter)
            switch status {
            case .balanced:
                assertionFailure("")
            case .greaterThanServer(let context), .inconsistency(let context):
                await MainActor.run {
                    let intro: TIPIntroViewController
                    switch action {
                    case .create:
                        intro = TIPIntroViewController(intent: .create, interruption: .confirmed(context))
                    case .change:
                        intro = TIPIntroViewController(intent: .change, interruption: .confirmed(context))
                    case .migrate:
                        intro = TIPIntroViewController(intent: .migrate, interruption: .confirmed(context))
                    }
                    navigationController?.setViewControllers([intro], animated: true)
                }
            }
        } catch {
            await MainActor.run {
                let intro: TIPIntroViewController
                switch action {
                case .create:
                    intro = TIPIntroViewController(intent: .create, interruption: .unknown)
                case .change:
                    intro = TIPIntroViewController(intent: .change, interruption: .unknown)
                case .migrate:
                    intro = TIPIntroViewController(intent: .migrate, interruption: .unknown)
                }
                navigationController?.setViewControllers([intro], animated: true)
            }
        }
    }
    
    private func showProgress(step: TIP.Step) {
        switch step {
        case .creating:
            activityIndicatorView.startAnimating()
            progressView.isHidden = true
            progressLabel.text = "正在创建密钥..."
        case .connecting:
            activityIndicatorView.startAnimating()
            progressView.isHidden = true
            progressLabel.text = "正在连接节点..."
        case .synchronizing(let fractionCompleted):
            activityIndicatorView.stopAnimating()
            progressView.isHidden = false
            progressView.progress = fractionCompleted
            let percent = Int(fractionCompleted * 100)
            progressLabel.text = "正在同步密钥分片，进度 \(percent)%"
        }
    }
    
#if DEBUG
    private func emulateProgress() {
        DispatchQueue.main.async {
            self.showProgress(step: .creating)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showProgress(step: .connecting)
        }
        for i in 0...6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(i + 4)) {
                let fractionComplete = Float(i + 1) / 7
                if !TIPDiagnostic.failLastSignerOnce || i < 6 {
                    self.showProgress(step: .synchronizing(fractionComplete))
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 13) {
            if TIPDiagnostic.failLastSignerOnce || TIPDiagnostic.failPINUpdateOnce {
                if TIPDiagnostic.failLastSignerOnce {
                    TIPDiagnostic.failLastSignerOnce = false
                }
                if TIPDiagnostic.failPINUpdateOnce {
                    TIPDiagnostic.failPINUpdateOnce = false
                }
                
                let intro: TIPIntroViewController
                switch self.action {
                case .create:
                    intro = TIPIntroViewController(intent: .create, interruption: .confirmed(.testCreate))
                case .change:
                    intro = TIPIntroViewController(intent: .change, interruption: .confirmed(.testChange))
                case .migrate:
                    intro = TIPIntroViewController(intent: .migrate, interruption: .confirmed(.testMigrate))
                }
                self.navigationController?.setViewControllers([intro], animated: true)
            } else {
                self.finish()
            }
        }
    }
#endif
    
}
