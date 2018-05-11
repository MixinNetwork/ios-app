import UIKit

class AboutViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView()
    }

}

extension AboutViewController {


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: indexPath.row > 0)

        switch indexPath.row {
        case 1:
            UIApplication.shared.openURL(url: "https://twitter.com/MixinMessenger")
        case 2:
            UIApplication.shared.openURL(url: "https://fb.com/MixinMessenger")
        case 3:
            UIApplication.shared.openURL(url: URL.terms)
        case 4:
            UIApplication.shared.openURL(url: URL.privacy)
        case 5:
            UIApplication.shared.openURL(url: "https://mixin.one")
        default:
            break
        }

    }

}
