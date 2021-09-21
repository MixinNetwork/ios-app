import UIKit
import AcknowList

class AcknowledgementsViewController: AcknowListViewController {
    
    class func instance() -> UIViewController {
        let filenames = ["Pods-Mixin-acknowledgements", "Custom-acknowledgements"]
        let acknows: [Acknow] = filenames.flatMap { filename -> [Acknow] in
            guard let url = Bundle.main.url(forResource: filename, withExtension: "plist") else {
                return []
            }
            let parser = AcknowParser(plistPath: url.path)
            return parser.parseAcknowledgements()
        }
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
