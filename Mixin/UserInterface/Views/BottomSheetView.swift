import UIKit

class BottomSheetView: UIView {

    @IBOutlet weak var popupView: UIView!

    @IBOutlet weak var contentBottomConstraint: NSLayoutConstraint!

    var isShowing = false
    var windowBackgroundColor = UIColor(white: 0.0, alpha: 0.5)
    
    private var animationOriginPoint: CGPoint {
        return CGPoint(x: self.center.x, y: self.bounds.size.height + self.popupView.bounds.size.height)
    }
    private var animationEndPoint: CGPoint {
        return CGPoint(x: self.center.x, y: self.bounds.size.height-(self.popupView.bounds.size.height * 0.5))
    }

    func presentPopupControllerAnimated() {
        UIApplication.currentActivity()?.view.endEditing(true)
        guard !isShowing, let window = UIApplication.shared.keyWindow else {
            return
        }

        isShowing = true
        self.frame = window.bounds

        self.backgroundColor = windowBackgroundColor
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissPopupControllerAnimated))
        gestureRecognizer.delegate = self
        self.addGestureRecognizer(gestureRecognizer)

        self.popupView.center = getAnimationStartPoint()
        window.addSubview(self)
        self.alpha = 0

        UIView.animate(withDuration: 0.5, animations: {
            UIView.setAnimationCurve(.overdamped)
            self.popAnimationBody()
        })
    }

    @objc func dismissPopupControllerAnimated() {
        self.alpha = 1.0
        isShowing = false
        UIView.animate(withDuration: 0.5, animations: {
            UIView.setAnimationCurve(.overdamped)
            self.alpha = 0
            self.popupView.center = self.getAnimationStartPoint()
        }, completion: { (finished: Bool) -> Void in
            self.removeFromSuperview()
        })
    }

    internal func popAnimationBody() {
        self.alpha = 1.0
        self.popupView.center = self.getAnimationEndPoint()
    }

    func getAnimationStartPoint() -> CGPoint {
        return animationOriginPoint
    }

    func getAnimationEndPoint() -> CGPoint {
        return animationEndPoint
    }
}

extension BottomSheetView: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if popupView.point(inside: touch.location(in: popupView), with: nil) {
            return false
        }
        return true
    }

}

extension BottomSheetView {

    func presentView() {
        guard !isShowing, let superView = UIApplication.currentActivity()?.view else {
            return
        }
        superView.endEditing(true)

        isShowing = true

        if self.superview == nil {
            self.frame = superView.bounds

            self.backgroundColor = windowBackgroundColor
            let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissView))
            gestureRecognizer.delegate = self
            self.addGestureRecognizer(gestureRecognizer)

            superView.addSubview(self)
        }
        self.alpha = 0
        self.popupView.center = getAnimationStartPoint()
        UIView.animate(withDuration: 0.5, animations: {
            UIView.setAnimationCurve(.overdamped)
            self.popAnimationBody()
        })
    }

    @objc func dismissView() {
        self.alpha = 1.0
        isShowing = false
        UIView.animate(withDuration: 0.5, animations: {
            UIView.setAnimationCurve(.overdamped)
            self.alpha = 0
            self.popupView.center = self.getAnimationStartPoint()
        })
    }

}

extension BottomSheetView {

	func alert(_ message: String, actionTitle: String = Localized.DIALOG_BUTTON_OK, cancelHandler: ((UIAlertAction) -> Void)? = nil) {
        let alc = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alc.addAction(UIAlertAction(title: actionTitle, style: .default, handler: cancelHandler))
        AppDelegate.current.mainWindow.rootViewController?.present(alc, animated: true, completion: nil)
    }
}
