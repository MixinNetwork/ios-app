import UIKit

protocol TransferViewControllerContextAccessible: class {
    var transferViewController: TransferViewController? { get }
    var context: PaymentContext? { get set }
}

extension TransferViewControllerContextAccessible where Self: UIViewController {
    
    var transferViewController: TransferViewController? {
        assert(navigationController!.parent! is TransferViewController)
        return navigationController?.parent as? TransferViewController
    }
    
    var context: PaymentContext? {
        get {
            return transferViewController?.context
        }
        set {
            transferViewController?.context = newValue
        }
    }
    
}
