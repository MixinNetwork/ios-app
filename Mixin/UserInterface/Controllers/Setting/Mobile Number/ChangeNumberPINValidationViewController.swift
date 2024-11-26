import UIKit

final class ChangeNumberPINValidationViewController: FullscreenPINValidationViewController {
    
    static func contained() -> ContainerViewController {
        let viewController = ChangeNumberPINValidationViewController()
        let container = ContainerViewController.instance(viewController: viewController, title: "")
        return container
    }
    
    override func pinIsVerified(pin: String) {
        let context = ChangeNumberContext(pin: pin)
        let vc = ChangeNumberNewNumberViewController(context: context)
        let container = ContainerViewController.instance(viewController: vc, title: "")
        navigationController?.pushViewController(container, animated: true)
    }
    
}
