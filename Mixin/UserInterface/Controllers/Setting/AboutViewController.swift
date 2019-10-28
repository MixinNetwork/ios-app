import UIKit

class AboutViewController: UITableViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var versionLabel: UILabel!

    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.about()!
        return ContainerViewController.instance(viewController: vc, title: "")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        versionLabel.text = Bundle.main.shortVersion + "(\(Bundle.main.bundleVersion))"
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 17, weight: .semibold), adjustForContentSize: true)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: indexPath.row > 0)
        
        switch indexPath.row {
        case 1:
            UIApplication.shared.openURL(url: "https://twitter.com/MixinMessenger")
        case 2:
            UIApplication.shared.openURL(url: "https://fb.com/MixinMessenger")
        case 3:
            UIApplication.shared.openURL(url: "https://mixinmessenger.zendesk.com")
        case 4:
            UIApplication.shared.openURL(url: URL.terms)
        case 5:
            UIApplication.shared.openURL(url: URL.privacy)
        case 6:
            UIApplication.shared.openURL(url: "https://mixin.one")
        default:
            break
        }
        
    }
    
}
