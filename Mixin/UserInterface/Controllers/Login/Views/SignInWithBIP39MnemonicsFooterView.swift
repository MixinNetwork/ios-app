import UIKit

final class SignInWithBIP39MnemonicsFooterView: UIView {
    
    @IBOutlet weak var descriptionStackView: UIStackView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let descriptions = [
            R.string.localizable.mnemonic_login_security_title(),
            R.string.localizable.mnemonic_login_security_tip_1(),
            R.string.localizable.mnemonic_login_security_tip_2(),
            R.string.localizable.mnemonic_login_security_tip_3(),
        ]
        for description in descriptions {
            let label = UILabel()
            label.setFont(
                scaledFor: .systemFont(ofSize: 14),
                adjustForContentSize: true
            )
            label.textColor = R.color.text_tertiary()
            label.numberOfLines = 0
            label.text = description
            descriptionStackView.addArrangedSubview(label)
        }
    }
    
}
