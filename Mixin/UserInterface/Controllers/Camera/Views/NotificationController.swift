import UIKit

protocol NotificationControllerDelegate: class {
    func notificationControllerDidSelectNotification(_ controller: NotificationController)
}

class NotificationController: NSObject {
    
    weak var delegate: NotificationControllerDelegate?
    
    private var view: NotificationView!
    private var isPresenting = false
    
    private var presentingViewFrameY: CGFloat {
        return AppDelegate.current.window.safeAreaInsets.top
    }
    
    override init() {
        super.init()
        view = R.nib.notificationView(owner: self)!
    }
    
    init(delegate: NotificationControllerDelegate) {
        super.init()
        view = R.nib.notificationView(owner: self)!
        self.delegate = delegate
    }
    
    deinit {
        guard isPresenting else {
            return
        }
        let view = self.view!
        UIView.animate(withDuration: 0.3, animations: {
            view.frame.origin.y = -view.frame.height
        }, completion: { (finished) in
            view.removeFromSuperview()
        })
    }
    
    func present(urlString: String) {
        if let url = MixinURL(string: urlString) {
            switch url {
            case .codes, .pay, .users, .apps, .transfer, .withdrawal, .address:
                present(text: Localized.CAMERA_QRCODE_CODES)
            case .send:
                present(text: urlString)
            case .upgradeDesktop:
                UIApplication.currentActivity()?.alert(R.string.localizable.desktop_upgrade())
            case let .device(id, publicKey):
                LoginConfirmWindow.instance(id: id, publicKey: publicKey).presentView()
            case .unknown:
                present(text: urlString)
            }
        } else {
            present(text: urlString)
        }
    }
    
    func dismiss() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.frame.origin.y = -self.view.frame.height
        }, completion: { (finished) in
            self.isPresenting = false
            self.view.removeFromSuperview()
        })
    }
    
    @IBAction func tapAction(_ sender: Any) {
        dismiss()
        delegate?.notificationControllerDidSelectNotification(self)
    }
    
    @IBAction func panAction(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            recognizer.setTranslation(.zero, in: view)
        case .changed:
            let translation = recognizer.translation(in: view)
            let maxY = presentingViewFrameY
            let targetY = view.frame.origin.y + translation.y
            if targetY > maxY {
                view.frame.origin.y += translation.y / 10
            } else {
                view.frame.origin.y = targetY
            }
            recognizer.setTranslation(.zero, in: view)
        case .ended:
            let shouldDismiss = recognizer.velocity(in: view).y < -100
                || view.frame.origin.y < presentingViewFrameY / 2
            if shouldDismiss {
                dismiss()
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.view.frame.origin.y = self.presentingViewFrameY
                }
            }
        default:
            break
        }
    }
    
    private func present(text: String) {
        view.subtitleLabel.text = text
        if isPresenting {
            UIView.animateKeyframes(withDuration: 0.6, delay: 0, options: .beginFromCurrentState, animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5, animations: {
                    self.view.frame.origin.y = self.presentingViewFrameY + 10
                })
                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5, animations: {
                    self.view.frame.origin.y = self.presentingViewFrameY
                })
            }, completion: nil)
        } else {
            isPresenting = true
            let window = AppDelegate.current.window
            view.frame = CGRect(x: window.safeAreaInsets.left,
                                y: -view.frame.height,
                                width: window.bounds.width - window.safeAreaInsets.horizontal,
                                height: view.frame.height)
            window.addSubview(view)
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 5, options: [], animations: {
                self.view.frame.origin.y = self.presentingViewFrameY
            }) { (_) in
                
            }
        }
    }
    
}
