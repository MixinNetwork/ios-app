import UIKit

final class MobileNumberIntroductionViewController: IntroductionViewController {
    
    enum Action {
        case add
        case change
    }
    
    private let action: Action
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    init(action: Action) {
        self.action = action
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = R.image.mobile_number()
        titleLabel.text = switch action {
        case .add:
            R.string.localizable.add_mobile_number()
        case .change:
            R.string.localizable.change_mobile_number()
        }
        contentLabelTopConstraint.constant = 16
        contentTextView.attributedText = {
            let attributedString = NSMutableAttributedString(attributedString: .walletIntroduction())
            attributedString.append(.init(string: "\n\n"))
            attributedString.append(.orderedList(items: [
                R.string.localizable.add_phone_instruction_1(),
                R.string.localizable.add_phone_instruction_2(),
                R.string.localizable.add_phone_instruction_3(),
                R.string.localizable.add_phone_instruction_4(),
            ], textColor: { index in
                index < 3 ? R.color.text()! : R.color.error_red()!
            }))
            return attributedString
        }()
        actionButton.setTitle(R.string.localizable.continue(), for: .normal)
        actionButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        actionButton.addTarget(self, action: #selector(continueToNext(_:)), for: .touchUpInside)
    }
    
    @objc private func continueToNext(_ sender: Any) {
        let next = VerifyMobileNumberPINValidationViewController(intent: .changeMobileNumber)
        navigationController?.pushViewController(replacingCurrent: next, animated: true)
    }
    
}
