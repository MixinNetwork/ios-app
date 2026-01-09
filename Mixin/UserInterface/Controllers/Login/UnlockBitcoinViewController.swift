import UIKit
import MixinServices

final class UnlockBitcoinViewController: UIViewController {
    
    @IBOutlet weak var mainTitleLabel: UILabel!
    
    @IBOutlet weak var featureTitleLabel0: UILabel!
    @IBOutlet weak var featureDescriptionLabel0: UILabel!
    
    @IBOutlet weak var featureTitleLabel1: UILabel!
    @IBOutlet weak var featureDescriptionLabel1: UILabel!
    
    @IBOutlet weak var featureTitleLabel2: UILabel!
    @IBOutlet weak var featureDescriptionLabel2: UILabel!
    
    @IBOutlet weak var unlockButton: UIButton!
    
    init() {
        let nib = R.nib.unlockBitcoinView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mainTitleLabel.text = R.string.localizable.common_wallet_now_supports_btc()
        let featureTitleLabels: [UILabel] = [
            featureTitleLabel0,
            featureTitleLabel1,
            featureTitleLabel2,
        ]
        let featureDescriptionLabels: [UILabel] = [
            featureDescriptionLabel0,
            featureDescriptionLabel1,
            featureDescriptionLabel2,
        ]
        let featureTitles = [
            R.string.localizable.feature_decentralized(),
            R.string.localizable.feature_seamless(),
            R.string.localizable.feature_compatibility(),
        ]
        let featureDescriptions = [
            R.string.localizable.feature_decentralized_description(),
            R.string.localizable.feature_seamless_description(),
            R.string.localizable.feature_compatibility_description(),
        ]
        for i in 0..<3 {
            featureTitleLabels[i].text = featureTitles[i]
            featureTitleLabels[i].setFont(
                scaledFor: .systemFont(ofSize: 16, weight: .medium),
                adjustForContentSize: true
            )
            featureDescriptionLabels[i].text = featureDescriptions[i]
            featureDescriptionLabels[i].setFont(
                scaledFor: .systemFont(ofSize: 14),
                adjustForContentSize: true
            )
        }
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
        let inputPIN = UnlockBitcoinInputPINViewController()
        navigationController?.setViewControllers([inputPIN], animated: true)
    }
    
}
