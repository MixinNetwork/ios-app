import UIKit
import AcknowList

class AcknowledgementsViewController: AcknowListViewController {
    
    class func instance() -> UIViewController {
        let urls = [
            Bundle.main.url(forResource: "Pods-\(Bundle.main.bundleName)-acknowledgements", withExtension: "plist"),
            Bundle.main.url(forResource: "Custom-acknowledgements", withExtension: "plist"),
        ]
        let paths = urls.compactMap { $0?.path }
        let acknow = AcknowledgementsViewController(acknowledgementsPlistPaths: paths)
        let title = R.string.localizable.about_acknowledgements()
        return ContainerViewController.instance(viewController: acknow, title: title)
    }
    
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
