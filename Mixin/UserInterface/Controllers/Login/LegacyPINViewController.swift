import UIKit
import SafariServices

final class LegacyPINViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var viewDocumentButton: StyledButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.upgrade_tip()
        descriptionLabel.text = R.string.localizable.error_legacy_pin()
        viewDocumentButton.setTitle(R.string.localizable.view_document(), for: .normal)
        viewDocumentButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        viewDocumentButton.style = .filled
        viewDocumentButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 15, trailing: 20)
    }
    
    @IBAction func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
    }
    
    @IBAction func viewDocument(_ sender: Any) {
        let safari = SFSafariViewController(url: .apiUpgrade)
        present(safari, animated: true)
    }
    
}
