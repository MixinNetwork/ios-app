import UIKit
import AcknowList

class AcknowledgementsViewController: AcknowListViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let acknowledgements = self.acknowledgements,
           let acknowledgement = acknowledgements[(indexPath as NSIndexPath).row] as Acknow?,
           let navigationController = self.navigationController {
            let viewController = AcknowViewController(acknowledgement: acknowledgement)
            let container = ContainerViewController.instance(viewController: viewController,
                                                             title: viewController.title ?? "")
            navigationController.pushViewController(container, animated: true)
        }
    }
    
}
