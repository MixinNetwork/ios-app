import UIKit

final class PopupTipRecoveryKitOptionsView: UIStackView {
    
    init(enabledOptions: [AccountRecoveryOption]) {
        super.init(frame: .zero)
        
        axis = .vertical
        distribution = .fill
        alignment = .fill
        spacing = 12
        
        for option in AccountRecoveryOption.allCases {
            let checkmarkView = if enabledOptions.contains(option) {
                UIImageView(image: R.image.user_checkmark_yes())
            } else {
                UIImageView(image: R.image.user_checkmark_no())
            }
            checkmarkView.setContentCompressionResistancePriority(.required, for: .horizontal)
            checkmarkView.setContentHuggingPriority(.required, for: .horizontal)
            
            let titleLabel = UILabel()
            titleLabel.textColor = R.color.text()
            titleLabel.setFont(
                scaledFor: .systemFont(ofSize: 14),
                adjustForContentSize: true
            )
            titleLabel.text = switch option {
            case .mobileNumber:
                R.string.localizable.mobile_number()
            case .mnemonicPhrase:
                R.string.localizable.mnemonic_phrase()
            case .recoveryContact:
                R.string.localizable.recovery_contact()
            }
            titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            
            let statusLabel = UILabel()
            statusLabel.textColor = R.color.text_tertiary()
            statusLabel.setFont(
                scaledFor: .systemFont(ofSize: 14),
                adjustForContentSize: true
            )
            statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            statusLabel.textAlignment = .right
            statusLabel.text = switch option {
            case .mobileNumber, .recoveryContact:
                enabledOptions.contains(option)
                ? R.string.localizable.added()
                : R.string.localizable.not_added()
            case .mnemonicPhrase:
                enabledOptions.contains(option)
                ? R.string.localizable.backed_up()
                : R.string.localizable.not_backed_up()
            }
            
            let itemStackView = UIStackView(
                arrangedSubviews: [checkmarkView, titleLabel, statusLabel]
            )
            itemStackView.axis = .horizontal
            itemStackView.alignment = .center
            itemStackView.spacing = 8
            addArrangedSubview(itemStackView)
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
}
