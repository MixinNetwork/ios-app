import UIKit
import MixinServices

final class UnlockCommonWalletChainsViewController: UIViewController {
        
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var mainTitleLabel: UILabel!
    @IBOutlet weak var featureStackView: UIStackView!
    @IBOutlet weak var unlockButton: UIButton!
    
    private let content: UnlockableCommonWalletChain
    
    init(content: UnlockableCommonWalletChain) {
        self.content = content
        let nib = R.nib.unlockCommonWalletChainsView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch content {
        case .bitcoin:
            iconImageView.image = R.image.bitcoin_chain()
            mainTitleLabel.text = R.string.localizable.common_wallet_now_supports_btc()
        case .pearl:
            iconImageView.image = R.image.pearl_chain()
            mainTitleLabel.text = R.string.localizable.classic_wallet_pearl_intro_title()
        }
        
        let featureItemViews = [
            FeatureItemView(
                image: R.image.feature_decentralize()!,
                title: R.string.localizable.feature_decentralized(),
                description: R.string.localizable.feature_decentralized_description()
            ),
            FeatureItemView(
                image: R.image.feature_seamless()!,
                title: R.string.localizable.feature_seamless(),
                description: R.string.localizable.feature_seamless_description()
            ),
            FeatureItemView(
                image: R.image.feature_compatibility()!,
                title: R.string.localizable.feature_compatibility(),
                description: R.string.localizable.feature_compatibility_description()
            ),
        ]
        featureItemViews.forEach(featureStackView.addArrangedSubview(_:))
        
        unlockButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            attributes.foregroundColor = .white
            return AttributedString(
                R.string.localizable.unlock_by_pin(),
                attributes: attributes
            )
        }()
        unlockButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    @IBAction func unlock(_ sender: Any) {
        let inputPIN = UnlockCommonWalletChainsInputPINViewController()
        navigationController?.setViewControllers([inputPIN], animated: true)
    }
    
}
