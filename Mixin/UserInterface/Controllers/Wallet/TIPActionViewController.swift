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
    
    private var tipNavigationController: TIPNavigationViewController? {
        navigationController as? TIPNavigationViewController
    }
    
    init(action: Action) {
        self.action = action
        let nib = R.nib.tipActionView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
                                                failedSigners: [],
                                                legacyPIN: nil,
                                                forRecover: false,
                                                progressHandler: showProgress(step:))
                    AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                    await MainActor.run(body: finish)
                } catch {
                    Logger.general.warn(category: "TIPActionViewController", message: "Failed to create: \(error)")
                    await handle(error: error)
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
                                                failedSigners: [],
                                                progressHandler: showProgress(step:))
                    if AppGroupUserDefaults.Wallet.payWithBiometricAuthentication {
                        Keychain.shared.storePIN(pin: new)
                    }
                    AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = PeriodicPinVerificationInterval.min
                    AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                    await MainActor.run(body: finish)
                } catch {
                    Logger.general.warn(category: "TIPActionViewController", message: "Failed to change: \(error)")
                    await handle(error: error)
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
                                                failedSigners: [],
                                                legacyPIN: pin,
                                                forRecover: false,
                                                progressHandler: showProgress(step:))
                    AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                    await MainActor.run(body: finish)
                } catch {
                    Logger.general.warn(category: "TIPActionViewController", message: "Failed to migrate: \(error)")
                    await handle(error: error)
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
    
    private func handle(error: Error) async {
        do {
            guard let account = LoginManager.shared.account else {
                return
            }
            guard let context = try await TIP.checkCounter(with: account) else {
                await MainActor.run(body: finish)
                return
            }
            await MainActor.run {
                let intro = TIPIntroViewController(context: context)
                navigationController?.setViewControllers([intro], animated: true)
            }
        } catch {
            await MainActor.run {
                let intro: TIPIntroViewController
                switch action {
                case .create:
                    intro = TIPIntroViewController(intent: .create)
                case .change:
                    intro = TIPIntroViewController(intent: .change)
                case .migrate:
                    intro = TIPIntroViewController(intent: .migrate)
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
                let action: TIP.Action
                switch self.action {
                case .create:
                    action = .create
                case .change:
                    action = .change
                case .migrate:
                    action = .migrate
                }
                
                let situation: TIP.InterruptionContext.Situation
                if TIPDiagnostic.failLastSignerOnce {
                    TIPDiagnostic.failLastSignerOnce = false
                    situation = .pendingSign([])
                } else if TIPDiagnostic.failPINUpdateOnce {
                    TIPDiagnostic.failPINUpdateOnce = false
                    situation = .pendingUpdate
                } else {
                    fatalError()
                }
                
                let context = TIP.InterruptionContext(action: action, situation: situation, maxNodeCounter: 2)
                let intro = TIPIntroViewController(context: context)
                self.navigationController?.setViewControllers([intro], animated: true)
            } else {
                self.finish()
            }
        }
    }
#endif
    
}
