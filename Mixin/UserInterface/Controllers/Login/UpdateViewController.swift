import UIKit
import MixinServices

final class UpdateViewController: UIViewController {
    
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var updateButton: UIButton!
    @IBOutlet weak var contactButton: UIButton!
    @IBOutlet weak var versionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        descriptionLabel.text = R.string.localizable.mixin_version_expired_description()
        updateButton.configuration?.attributedTitle = AttributedString(
            string: R.string.localizable.update(),
            scalingByFontSize: 16,
            weight: .medium
        )
        contactButton.configuration?.attributedTitle = AttributedString(
            string: R.string.localizable.wallet_home_contact_us(),
            scalingByFontSize: 16,
            weight: .medium
        )
        versionLabel.text = Bundle.main.fullVersion
        versionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        Logger.login.info(category: "UpdateViewController", message: "View did load")
    }
    
    @IBAction func update(_ sender: Any) {
        UIApplication.shared.open(.mixinMessenger, options: [:], completionHandler: nil)
    }
    
    @IBAction func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(
            reportingTags: ["source": "update"]
        )
        present(customerService, animated: true)
    }
    
}
