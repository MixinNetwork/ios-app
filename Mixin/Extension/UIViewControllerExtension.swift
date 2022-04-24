import UIKit

extension UIViewController {
    
    public func isPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    func alert(_ message: String, actionTitle: String = R.string.localizable.oK(), cancelHandler: ((UIAlertAction) -> Void)? = nil) {
        let alc = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alc.addAction(UIAlertAction(title: actionTitle, style: .default, handler: cancelHandler))

        if let window = UIApplication.shared.windows.last, window.windowLevel.rawValue == 10000001.0, window.isOpaque {
            window.rootViewController?.present(alc, animated: true, completion: nil)
        } else {
            present(alc, animated: true, completion: nil)
        }
    }

    func alert(_ title: String?, message: String?, handler: ((UIAlertAction) -> Void)? = nil) {
        let alc = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alc.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .cancel, handler: handler))
        self.present(alc, animated: true, completion: nil)
    }

    func alert(_ title: String, message: String? = nil, cancelTitle: String = R.string.localizable.cancel(), actionTitle: String, handler: @escaping ((UIAlertAction) -> Void)) {
        let alc = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alc.addAction(UIAlertAction(title: cancelTitle, style: .default, handler: nil))
        alc.addAction(UIAlertAction(title: actionTitle, style: .destructive, handler: handler))
        self.present(alc, animated: true, completion: nil)
    }

    func alertSettings(_ message: String) {
        let alc = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alc.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        alc.addAction(UIAlertAction(title: R.string.localizable.settings(), style: .default, handler: { (_) in
            UIApplication.openAppSettings()
        }))
        self.present(alc, animated: true, completion: nil)
    }

    func alertInput(title: String, placeholder: String, actionTitle: String = R.string.localizable.change(), handler: @escaping ((UIAlertAction) -> Void)) -> UIAlertController {
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        controller.addTextField { (textField) in
            textField.placeholder = placeholder
        }
        controller.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        controller.addAction(UIAlertAction(title: actionTitle, style: .default, handler: handler))
        controller.actions[1].isEnabled = false
        return controller
    }
    
    func presentGotItAlertController(title: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.got_it(), style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}
