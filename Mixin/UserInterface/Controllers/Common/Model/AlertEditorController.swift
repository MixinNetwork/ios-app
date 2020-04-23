import UIKit

class AlertEditorController {
    
    var isNumericOnly = false
    
    private weak var viewController: UIViewController?
    private weak var alertController: UIAlertController?
    
    init(presentingViewController viewController: UIViewController) {
        self.viewController = viewController
    }
    
    func present(title: String, actionTitle: String, currentText: String? = nil, placeholder: String? = nil, handler: @escaping (UIAlertController) -> Void) {
        guard let viewController = viewController else {
            return
        }
        let cancel = R.string.localizable.dialog_button_cancel()
        
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.text = currentText
            textField.placeholder = placeholder
            if self.isNumericOnly {
                textField.keyboardType = .numberPad
            }
            textField.addTarget(self, action: #selector(self.alertInputChangedAction(_:)), for: .editingChanged)
        }
        alert.addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
        let action = UIAlertAction(title: actionTitle, style: .default, handler: { [unowned alert] _ in
            handler(alert)
        })
        action.isEnabled = false
        alert.addAction(action)
        
        self.alertController = alert
        viewController.present(alert, animated: true, completion: {
            alert.textFields?.first?.selectAll(nil)
        })
    }
    
    @objc private func alertInputChangedAction(_ sender: UITextField) {
        guard let controller = alertController, let text = controller.textFields?.first?.text else {
            return
        }
        controller.actions[1].isEnabled = !text.isEmpty && (!isNumericOnly || text.isNumeric)
    }
    
}
