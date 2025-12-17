import UIKit
import MixinServices

final class WalletIdentifyingNavigationTitleView: UIStackView {
    
    weak var titleLabel: UILabel!
    
    init(title: String, wallet: Wallet) {
        super.init(frame: .zero)
        
        axis = .vertical
        distribution = .fill
        alignment = .center
        spacing = 2
        
        let titleLabel = {
            let label = UILabel()
            label.backgroundColor = .clear
            label.textColor = R.color.text()
            label.setFont(
                scaledFor: .systemFont(ofSize: 16, weight: .medium),
                adjustForContentSize: true
            )
            label.text = title
            return label
        }()
        addArrangedSubview(titleLabel)
        self.titleLabel = titleLabel
        
        let subtitleStackView = {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .fill
            stackView.alignment = .center
            stackView.spacing = 4
            
            let subtitleLabel = {
                let label = UILabel()
                label.backgroundColor = .clear
                label.font = .preferredFont(forTextStyle: .caption1)
                label.textColor = R.color.text_quaternary()
                label.text = wallet.localizedName
                return label
            }()
            stackView.addArrangedSubview(subtitleLabel)
            
            switch wallet {
            case .privacy:
                let privacyShieldView = UIImageView(image: R.image.privacy_wallet())
                stackView.addArrangedSubview(privacyShieldView)
                privacyShieldView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
                privacyShieldView.snp.makeConstraints { make in
                    make.width.height.equalTo(16)
                }
            case .common:
                break
            case .safe:
                let vaultView = UIImageView(image: R.image.safe_vault())
                stackView.addArrangedSubview(vaultView)
                vaultView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
                vaultView.snp.makeConstraints { make in
                    make.width.height.equalTo(16)
                }
            }
            
            return stackView
        }()
        addArrangedSubview(subtitleStackView)
    }
    
    required init(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
}
