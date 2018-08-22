import UIKit

extension UIViewController {
    
    public func isPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    func alert(_ message: String, actionTitle: String = Localized.DIALOG_BUTTON_OK, cancelHandler: ((UIAlertAction) -> Void)? = nil) {
        let alc = UIAlertController(title: message, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alc.addAction(UIAlertAction(title: actionTitle, style: UIAlertActionStyle.default, handler: cancelHandler))

        if let window = UIApplication.shared.windows.last, window.windowLevel == 10000001.0 {
            window.rootViewController?.present(alc, animated: true, completion: nil)
        } else {
            present(alc, animated: true, completion: nil)
        }
    }

    func alert(_ title: String?, message: String?, handler: ((UIAlertAction) -> Void)? = nil) {
        let alc = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_OK, style: UIAlertActionStyle.cancel, handler: handler))
        self.present(alc, animated: true, completion: nil)
    }

    func alert(_ title: String, message: String? = nil, cancelTitle: String = Localized.DIALOG_BUTTON_CANCEL, actionTitle: String, handler: @escaping ((UIAlertAction) -> Void)) {
        let alc = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alc.addAction(UIAlertAction(title: cancelTitle, style: UIAlertActionStyle.default, handler: nil))
        alc.addAction(UIAlertAction(title: actionTitle, style: UIAlertActionStyle.destructive, handler: handler))
        self.present(alc, animated: true, completion: nil)
    }

    func alertSettings(_ message: String) {
        let alc = UIAlertController(title: message, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: UIAlertActionStyle.cancel, handler: nil))
        alc.addAction(UIAlertAction(title: Localized.SETTING_TITLE, style: .default, handler: { (_) in
            UIApplication.openAppSettings()
        }))
        self.present(alc, animated: true, completion: nil)
    }

    func alertInput(title: String, placeholder: String, actionTitle: String = Localized.DIALOG_BUTTON_CHANGE, handler: @escaping ((UIAlertAction) -> Void)) -> UIAlertController {
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        controller.addTextField { (textField) in
            textField.placeholder = placeholder
        }
        controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        controller.addAction(UIAlertAction(title: actionTitle, style: .default, handler: handler))
        controller.actions[1].isEnabled = false
        return controller
    }

    func showOnWindow() {
        let win = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        win.rootViewController = vc
        win.windowLevel = UIWindowLevelAlert + 1
        win.makeKeyAndVisible()
        vc.present(self, animated: true, completion: nil)
    }
}
