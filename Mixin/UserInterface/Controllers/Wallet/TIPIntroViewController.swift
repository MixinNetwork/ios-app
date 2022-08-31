import UIKit
import Alamofire
import MixinServices

class TIPIntroViewController: UIViewController {
    
    enum Intent {
        case create
        case change
        case migrate
    }
    
    enum Interruption {
        case unknown
        case none
        case confirmed(TIP.InterruptionContext)
    }
    
    private enum Status {
        case checkingCounter
        case counterCheckingFails
        case waitingForUser
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionTextLabel: TextLabel!
    @IBOutlet weak var noticeTextView: UITextView!
    @IBOutlet weak var nextButton: RoundedButton!
    @IBOutlet weak var actionDescriptionLabel: UILabel!
    
    private let intent: Intent
    
    private var interruption: Interruption
    
    init(intent: Intent, interruption: Interruption) {
        self.intent = intent
        self.interruption = interruption
        let nib = R.nib.tipIntroView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentStackView.setCustomSpacing(24, after: iconImageView)
        switch intent {
        case .create:
            titleLabel.text = "Create PIN"
            switch interruption {
            case .unknown, .none:
                descriptionTextLabel.text = "设置 6 位数字 PIN 创建你的第一个加密货币钱包，PIN 基于去中心化密钥派生协议 Throttled Identity Protocol，阅读文档以了解更多。"
            case .confirmed:
                descriptionTextLabel.text = "创建 PIN 于 2022-21-22 00:00:00 意外中止"
            }
            setNoticeHidden(false)
        case .change:
            titleLabel.text = "Change PIN"
            switch interruption {
            case .unknown, .none:
                descriptionTextLabel.text = "PIN 基于去中心化密钥派生协议 Throttled Identity Protocol，阅读文档以了解更多。"
            case .confirmed:
                descriptionTextLabel.text = "更新 PIN 于 2022-21-22 00:00:00 意外中止"
            }
            setNoticeHidden(false)
        case .migrate:
            titleLabel.text = "Upgrade to TIP"
            switch interruption {
            case .unknown, .none:
                descriptionTextLabel.text = "PIN 基于去中心化密钥派生协议 Throttled Identity Protocol，阅读文档以了解更多。"
            case .confirmed:
                descriptionTextLabel.text = "升级 PIN 于 2022-21-22 00:00:00 意外中止"
            }
            setNoticeHidden(false)
        }
        switch interruption {
        case .unknown:
            checkCounter()
        case .confirmed, .none:
            updateNextButtonAndStatusLabel(with: .waitingForUser)
        }
    }
    
    @IBAction func continueToNext(_ sender: Any) {
        switch interruption {
        case .unknown:
            checkCounter()
        case .none:
            switch intent {
            case .create:
                let input = TIPInputPINViewController(action: .create(.input))
                navigationController?.pushViewController(input, animated: true)
            case .change:
                let input = TIPInputPINViewController(action: .change(.verify))
                navigationController?.pushViewController(input, animated: true)
            case .migrate:
                let validator = TIPValidatePINViewController(action: .create({ pin in
                    let action = TIPActionViewController(action: .migrate(pin: pin), context: nil)
                    self.navigationController?.pushViewController(action, animated: true)
                }))
                present(validator, animated: true)
            }
        case .confirmed(let context):
            switch intent {
            case .create:
                let validator = TIPValidatePINViewController(action: .create({ pin in
                    let action = TIPActionViewController(action: .create(pin: pin), context: context)
                    self.navigationController?.pushViewController(action, animated: true)
                }))
                present(validator, animated: true)
            case .change:
                let validator = TIPValidatePINViewController(action: .change({ (old, new) in
                    let action = TIPActionViewController(action: .change(old: old, new: new), context: context)
                    self.navigationController?.pushViewController(action, animated: true)
                }))
                present(validator, animated: true)
            case .migrate:
                let validator = TIPValidatePINViewController(action: .create({ pin in
                    let action = TIPActionViewController(action: .migrate(pin: pin), context: context)
                    self.navigationController?.pushViewController(action, animated: true)
                }))
                present(validator, animated: true)
            }
        }
    }
    
    private func setNoticeHidden(_ hidden: Bool) {
        if hidden {
            noticeTextView.isHidden = true
        } else {
            noticeTextView.text = "· 请在网络流畅的环境下进行此操作\n· 请保持 App 在前台，设置过程中不要 强退 App 或关机\n· 流程一旦开始无法取消，请牢记新设置的 PIN，意外中止流程可能需要再次输入"
            noticeTextView.isHidden = false
        }
    }
    
    private func checkCounter() {
        guard let account = LoginManager.shared.account else {
            return
        }
        updateNextButtonAndStatusLabel(with: .checkingCounter)
        Task {
            do {
                let status = try await TIP.checkCounter(account.tipCounter)
                await MainActor.run {
                    switch status {
                    case .balanced:
                        interruption = .none
                        updateNextButtonAndStatusLabel(with: .waitingForUser)
                    case .greaterThanServer(let context), .inconsistency(let context):
                        interruption = .confirmed(context)
                        let intro = TIPIntroViewController(intent: self.intent, interruption: .confirmed(context))
                        navigationController?.setViewControllers([intro], animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    interruption = .unknown
                    updateNextButtonAndStatusLabel(with: .counterCheckingFails)
                }
            }
        }
    }
    
    private func updateNextButtonAndStatusLabel(with status: Status) {
        switch status {
        case .checkingCounter:
            setNextButtonTitleByIntent()
            nextButton.isBusy = true
            actionDescriptionLabel.text = "正在尝试链接 TIP网络"
            actionDescriptionLabel.textColor = R.color.text_desc()
        case .counterCheckingFails:
            nextButton.setTitle("Retry", for: .normal)
            nextButton.isBusy = false
            actionDescriptionLabel.text = "无法连接 TIP 网络，请尝试切换4G、Wi-Fi 或 VPN 后重试"
            actionDescriptionLabel.textColor = .mixinRed
        case .waitingForUser:
            switch interruption {
            case .unknown, .none:
                setNextButtonTitleByIntent()
            case .confirmed:
                nextButton.setTitle(R.string.localizable.continue(), for: .normal)
            }
            nextButton.isBusy = false
            actionDescriptionLabel.text = nil
        }
    }
    
    private func setNextButtonTitleByIntent() {
        switch intent {
        case .create, .change:
            nextButton.setTitle("Start", for: .normal)
        case .migrate:
            nextButton.setTitle("Upgrade", for: .normal)
        }
    }
    
}
