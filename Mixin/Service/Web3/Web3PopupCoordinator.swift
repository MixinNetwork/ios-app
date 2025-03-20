import UIKit

protocol Web3PopupViewController: UIViewController {
    
    var onDismiss: (() -> Void)? { get set }
    
    func reject()
    
}

struct Web3PopupCoordinator {
    
    private class AlertController: UIAlertController {
        
        var onDismiss: (() -> Void)?
        
        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            onDismiss?()
        }
        
    }
    
    enum Popup {
        case request(Web3PopupViewController)
        case rejection(title: String, message: String)
    }
    
    private static var popups: [Popup] = []
    
    static func enqueue(popup: Popup) {
        popups.append(popup)
        if popups.count == 1 {
            presentNextPopupIfNeeded()
        }
    }
    
    static func rejectAllPopups() {
        for popup in popups {
            switch popup {
            case .request(let controller):
                controller.reject()
            case .rejection:
                break
            }
        }
        popups = []
    }
    
    private static func presentNextPopupIfNeeded() {
        guard let container = UIApplication.homeContainerViewController else {
            return
        }
        guard let popup = popups.first else {
            return
        }
        let viewController: UIViewController
        switch popup {
        case .request(let controller):
            controller.onDismiss = {
                popups.removeFirst()
                presentNextPopupIfNeeded()
            }
            viewController = controller
        case .rejection(let title, let message):
            let alert = AlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: R.string.localizable.ok(), style: .cancel))
            alert.onDismiss = {
                popups.removeFirst()
                presentNextPopupIfNeeded()
            }
            viewController = alert
        }
        container.presentOnTopMostPresentedController(viewController, animated: true)
    }
    
}
