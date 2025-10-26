import UIKit
import MixinServices

final class SignUpWithMnemonicIntroductionViewController: IntroductionViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = .customerService(target: self, action: #selector(presentCustomerService(_:)))
        imageViewTopConstraint.constant = switch ScreenHeight.current {
        case .short:
            40
        case .medium:
            80
        case .long, .extraLong:
            120
        }
        imageView.image = R.image.mnemonic_phrase()
        titleLabel.text = R.string.localizable.create_mnemonic_phrase()
        contentTextView.attributedText = .orderedList(items: [
            R.string.localizable.mnemonic_phrase_instruction_1(),
            R.string.localizable.mnemonic_phrase_instruction_2(),
        ], textColor: { _ in R.color.text()! })
        actionButton.setTitle(R.string.localizable.create(), for: .normal)
        actionButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        actionButton.addTarget(self, action: #selector(continueToNext(_:)), for: .touchUpInside)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "sign_up_mnemonic_phrase"])
    }
    
    @objc private func continueToNext(_ sender: Any) {
        guard let navigationController else {
            return
        }
        let signUp = LoginWithMnemonicViewController(action: .signUp)
        navigationController.pushViewController(replacingCurrent: signUp, animated: true)
    }
    
}
