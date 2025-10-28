import UIKit

final class RecoveryContactIntroduction1ViewController: IntroductionViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = R.image.recovery_contact()
        titleLabel.text = R.string.localizable.recovery_contact()
        let items = [
            R.string.localizable.add_recovery_contact_instruction_1(),
            R.string.localizable.add_recovery_contact_instruction_2(),
            R.string.localizable.add_recovery_contact_instruction_3(),
            R.string.localizable.add_recovery_contact_instruction_4(),
        ]
        contentTextView.attributedText = .orderedList(items: items) { index in
            index == 3 ? R.color.error_red()! : R.color.text()!
        }
        actionButton.setTitle(R.string.localizable.add_emergency_contact(), for: .normal)
        actionButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        actionButton.addTarget(self, action: #selector(continueToNext(_:)), for: .touchUpInside)
        let cancelButton = UIButton(type: .system)
        actionStackView.addArrangedSubview(cancelButton)
        cancelButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        cancelButton.setTitle(R.string.localizable.not_now(), for: .normal)
        if let label = cancelButton.titleLabel {
            label.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
            label.textColor = R.color.theme()
        }
        cancelButton.addTarget(self, action: #selector(cancel(_:)), for: .touchUpInside)
    }
    
    @objc private func continueToNext(_ sender: Any) {
        let next = RecoveryContactIntroduction2ViewController()
        navigationController?.pushViewController(replacingCurrent: next, animated: true)
    }
    
    @objc private func cancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
}
