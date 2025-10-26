import UIKit
import MixinServices

final class AddWalletErrorViewController: IntroductionViewController {
    
    enum AddWalletError {
        case tooManyWallets(hasPartialSuccess: Bool)
        case tooManyWatchWallets
        case unsupportedWatchAddress
    }
    
    var onUseAnotherAddress: (() -> Void)?
    
    private let error: AddWalletError
    
    private var isMembershipUpgradable: Bool {
        guard let account = LoginManager.shared.account else {
            return false
        }
        if let plan = account.membership?.unexpiredPlan {
            return plan != .prosperity
        } else {
            return true
        }
    }
    
    init(error: AddWalletError) {
        self.error = error
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageViewTopConstraint.constant = switch ScreenHeight.current {
        case .short:
            40
        case .medium:
            80
        case .long, .extraLong:
            120
        }
        contentLabelTopConstraint.constant = 16
        contentTextView.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        contentTextView.textColor = R.color.error_red()
        contentTextView.adjustsFontForContentSizeCategory = true
        contentTextView.textAlignment = .center
        actionButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        actionButton.isHidden = false
        
        imageView.image = R.image.add_wallet_error()
        switch error {
        case let .tooManyWallets(hasPartialSuccess):
            if hasPartialSuccess {
                titleLabel.text = R.string.localizable.partial_import_successful()
            } else {
                titleLabel.text = R.string.localizable.import_failed()
            }
        case .tooManyWatchWallets, .unsupportedWatchAddress:
            titleLabel.text = R.string.localizable.add_failed()
        }
        switch error {
        case .tooManyWallets, .tooManyWatchWallets:
            if isMembershipUpgradable {
                contentTextView.text = R.string.localizable.error_too_many_wallets_upgrade()
                actionButton.setTitle(R.string.localizable.upgrade_plan(), for: .normal)
                actionButton.addTarget(self, action: #selector(upgradePlan(_:)), for: .touchUpInside)
                addNotNowButton()
            } else {
                contentTextView.text = R.string.localizable.error_too_many_wallets()
                actionButton.setTitle(R.string.localizable.ok(), for: .normal)
                actionButton.addTarget(self, action: #selector(leave(_:)), for: .touchUpInside)
            }
        case .unsupportedWatchAddress:
            contentTextView.text = R.string.localizable.error_watch_address_not_supported()
            actionButton.setTitle(R.string.localizable.use_another_address(), for: .normal)
            actionButton.addTarget(self, action: #selector(useAnotherAddress(_:)), for: .touchUpInside)
        }
    }
    
    @objc private func upgradePlan(_ sender: Any) {
        let buy = MembershipPlansViewController(selectedPlan: nil)
        present(buy, animated: true) {
            self.navigationController?.popViewController(animated: false)
        }
    }
    
    @objc private func leave(_ sender: Any) {
        navigationController?.popToRootViewController(animated: true)
    }
    
    @objc private func useAnotherAddress(_ sender: Any) {
        onUseAnotherAddress?()
        navigationController?.popViewController(animated: true)
    }
    
    private func addNotNowButton() {
        let notNowButton = UIButton(type: .system)
        notNowButton.configuration = {
            var config: UIButton.Configuration = .plain()
            config.titleTextAttributesTransformer = .init { incoming in
                var outgoing = incoming
                outgoing.font = UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 16, weight: .medium)
                )
                return outgoing
            }
            config.baseForegroundColor = R.color.theme()
            config.title = R.string.localizable.not_now()
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            return config
        }()
        notNowButton.addTarget(self, action: #selector(leave(_:)), for: .touchUpInside)
        actionStackView.spacing = 20
        actionStackView.addArrangedSubview(notNowButton)
    }
    
}
