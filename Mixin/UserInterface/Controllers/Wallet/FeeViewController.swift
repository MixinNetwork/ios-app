import UIKit

class FeeViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    class func instance() -> UIViewController {
        return ContainerViewController.instance(viewController: Storyboard.wallet.instantiateViewController(withIdentifier: "fee"), title: Localized.WALLET_TRANSFER_OUT)
    }

}

extension FeeViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
