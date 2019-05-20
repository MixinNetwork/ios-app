import UIKit

protocol NotificationControllerDelegate: class {
    func notificationControllerDidSelectNotification(_ controller: NotificationController)
}

class NotificationController: NSObject {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    weak var delegate: NotificationControllerDelegate?
    
    private var view: UIView!
    private var isPresenting = false
    
    private var presentingViewFrameY: CGFloat {
        return AppDelegate.current.window?.compatibleSafeAreaInsets.top ?? 0
    }
    
    override init() {
        super.init()
        view = R.nib.notificationView(owner: self)!
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
    
    func present(text: String) {
        guard let window = AppDelegate.current.window else {
            return
        }
        subtitleLabel.text = text
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
            view.frame = CGRect(x: window.compatibleSafeAreaInsets.left,
                                y: -view.frame.height,
                                width: window.bounds.width - window.compatibleSafeAreaInsets.horizontal,
                                height: view.frame.height)
            window.addSubview(view)
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 5, options: [], animations: {
                self.view.frame.origin.y = self.presentingViewFrameY
            }) { (_) in
                
            }
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
    
}
