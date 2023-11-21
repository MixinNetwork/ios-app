import UIKit

final class PaymentSuccessView: UIView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var doneButton: RoundedButton!
    @IBOutlet weak var titleLabel: UILabel!
    
    private weak var stayInMixinButton: UIButton?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(40, after: titleLabel)
    }
    
    func insertStayInMixinButtonIfNeeded() -> UIButton {
        if let button = stayInMixinButton {
            return button
        }
        let button = UIButton(type: .system)
        button.setTitle(R.string.localizable.stay_in_mixin(), for: .normal)
        button.dynamicTextSize = "regular14"
        button.titleLabel?.textColor = .theme
        contentStackView.addArrangedSubview(button)
        stayInMixinButton = button
        return button
    }
    
}
