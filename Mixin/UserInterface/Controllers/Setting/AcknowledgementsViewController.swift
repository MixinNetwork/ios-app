import UIKit
import AcknowList

class AcknowledgementsViewController: AcknowListViewController {
    
    class func instance() -> UIViewController {
        let controller = AcknowledgementsViewController()
        if let url = Bundle.main.url(forResource: "Custom-acknowledgements", withExtension: "plist") {
            let parser = AcknowParser(plistPath: url.path)
            let acknows = parser.parseAcknowledgements()
            controller.acknowledgements.append(contentsOf: acknows)
        }
        let title = R.string.localizable.acknowledgements()
        return ContainerViewController.instance(viewController: controller, title: title)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let acknowledgement = acknowledgements[indexPath.row]
        let viewController = AcknowViewController(acknowledgement: acknowledgement)
        let container = ContainerViewController.instance(viewController: viewController,
                                                         title: viewController.title ?? "")
        navigationController?.pushViewController(container, animated: true)
    }
    
}
