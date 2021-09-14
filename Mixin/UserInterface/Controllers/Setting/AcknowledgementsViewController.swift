import UIKit
import AcknowList

class AcknowledgementsViewController: AcknowListViewController {
    
    class func instance() -> UIViewController {
        let acknows: [Acknow] = {
            ["Pods-Mixin-acknowledgements", "Custom-acknowledgements"].reduce(into: []) { result, resource in
                guard let url = Bundle.main.url(forResource: resource, withExtension: "plist") else {
                    return
                }
                let acknows = AcknowParser(plistPath: url.path).parseAcknowledgements()
                result += acknows
            }
        }()
        let controller = AcknowledgementsViewController(acknowledgements: acknows)
        let title = R.string.localizable.about_acknowledgements()
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
