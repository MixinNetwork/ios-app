import UIKit
import MixinServices

final class RecoveryContactIntroduction2ViewController: IntroductionViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = R.image.recovery_contact()
        titleLabel.text = R.string.localizable.before_you_proceed()
        let items = [
            R.string.localizable.add_recovery_contact_before_instruction_1(),
            R.string.localizable.add_recovery_contact_before_instruction_2(),
            R.string.localizable.add_recovery_contact_before_instruction_3(myIdentityNumber),
        ]
        contentTextView.attributedText = .orderedList(items: items) { index in
            index == 2 ? R.color.error_red()! : R.color.text()!
        }
        actionButton.addTarget(self, action: #selector(continueToNext(_:)), for: .touchUpInside)
        actionButton.setTitle(R.string.localizable.im_ready(), for: .normal)
        actionButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        let cancelButton = UIButton(type: .system)
        actionStackView.addArrangedSubview(cancelButton)
        cancelButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        cancelButton.setTitle(R.string.localizable.later(), for: .normal)
        if let label = cancelButton.titleLabel {
            label.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
            label.textColor = R.color.theme()
        }
        cancelButton.addTarget(self, action: #selector(cancel(_:)), for: .touchUpInside)
    }
    
    @objc private func continueToNext(_ sender: Any) {
        let next = RecoveryContactVerifyPINViewController()
        navigationController?.pushViewController(replacingCurrent: next, animated: true)
    }
    
    @objc private func cancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
}
