import UIKit

final class AddWalletIntroductionViewController: IntroductionViewController {
    
    enum Action {
        case addWallet(AddWalletMethod)
        case exportSecret(ExportingSecret)
    }
    
    private let action: Action
    
    init(action: Action) {
        self.action = action
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        imageViewTopConstraint.constant = switch ScreenHeight.current {
        case .short:
            24
        case .medium:
            48
        case .long, .extraLong:
            72
        }
        contentLabelTopConstraint.constant = 16
        imageView.image = R.image.introduction_warning()
        titleLabel.text = R.string.localizable.before_you_proceed()
        contentTextView.attributedText = switch action {
        case .addWallet(.create):
                .orderedList(
                    items: [
                        R.string.localizable.add_wallet_instruction_tip_derivation(),
                        R.string.localizable.add_wallet_instruction_multiple_network(),
                        R.string.localizable.add_wallet_instruction_delete_unsupported(),
                    ],
                    font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                ) { index in
                    index < 2 ? R.color.text()! : R.color.error_red()!
                }
        case .addWallet(.privateKey), .exportSecret(.privateKey), .exportSecret(.privateKeyFromMnemonics):
                .orderedList(
                    items: [
                        R.string.localizable.export_secret_warning_1(R.string.localizable.private_key()),
                        R.string.localizable.export_secret_warning_2(R.string.localizable.private_key()),
                        R.string.localizable.export_secret_warning_3(R.string.localizable.private_key()),
                        R.string.localizable.export_secret_warning_4(),
                    ],
                    font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                ) { index in
                    index < 2 ? R.color.text()! : R.color.error_red()!
                }
        case .addWallet(.mnemonics), .exportSecret(.mnemonics):
                .orderedList(
                    items: [
                        R.string.localizable.export_secret_warning_1(R.string.localizable.mnemonic_phrases()),
                        R.string.localizable.export_secret_warning_2(R.string.localizable.mnemonic_phrases()),
                        R.string.localizable.export_secret_warning_3(R.string.localizable.mnemonic_phrases()),
                        R.string.localizable.export_secret_warning_4(),
                    ],
                    font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                ) { index in
                    index < 2 ? R.color.text()! : R.color.error_red()!
                }
        case .addWallet(.watch):
                .orderedList(
                    items: [
                        R.string.localizable.watch_wallet_instruction_benefit(),
                        R.string.localizable.add_wallet_instruction_multiple_network(),
                        R.string.localizable.watch_wallet_instruction_restriction(),
                    ],
                    font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                ) { index in
                    index < 2 ? R.color.text()! : R.color.error_red()!
                }
        }
        actionButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        actionButton.setTitle(R.string.localizable.proceed(), for: .normal)
        UIView.performWithoutAnimation(actionButton.layoutIfNeeded)
        actionButton.addTarget(self, action: #selector(proceed(_:)), for: .touchUpInside)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
    }
    
    @objc private func proceed(_ sender: Any) {
        let validation = switch action {
        case .addWallet(let method):
            AddWalletPINValidationViewController(action: .addWallet(method))
        case .exportSecret(let secret):
            ExportImportedSecretValidationViewController(secret: secret)
        }
        navigationController?.pushViewController(replacingCurrent: validation, animated: true)
    }
    
}
