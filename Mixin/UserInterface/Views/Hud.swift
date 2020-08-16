import UIKit

func showAutoHiddenHud(style: Hud.Style, text: String) {
    guard Thread.isMainThread else {
        DispatchQueue.main.async {
            showAutoHiddenHud(style: style, text: text)
        }
        return
    }
    let hud = Hud()
    hud.show(style: style, text: text, on: AppDelegate.current.mainWindow)
    hud.scheduleAutoHidden()
}

final class Hud: NSObject {
    
    enum Style {
        case notification
        case warning
        case error
        case busy
    }
    
    var containerView: UIView!
    
    @IBOutlet weak var hudView: UIVisualEffectView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    @IBOutlet weak var label: UILabel!
    
    private var isViewLoaded = false
    private var isShowing = false
    
    func set(style: Style, text: String) {
        switch style {
        case .notification:
            imageView.image = R.image.ic_hud_notification()
            imageView.isHidden = false
            activityIndicator.stopAnimating()
        case .warning:
            imageView.image = R.image.ic_hud_warning()
            imageView.isHidden = false
            activityIndicator.stopAnimating()
        case .error:
            imageView.image = R.image.ic_hud_error()
            imageView.isHidden = false
            activityIndicator.stopAnimating()
        case .busy:
            imageView.isHidden = true
            activityIndicator.startAnimating()
        }
        label.text = text
        containerView.isUserInteractionEnabled = style == .busy
    }
    
    func scheduleAutoHidden() {
        guard isShowing else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.hide()
        }
    }
    
    func show(style: Style, text: String, on view: UIView) {
        guard !isShowing else {
            return
        }
        isShowing = true
        
        if !isViewLoaded {
            containerView = R.nib.hudView(owner: self)
            containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            isViewLoaded = true
        }
        
        hudView.alpha = 0
        set(style: style, text: text)
        
        containerView.frame = view.bounds
        view.addSubview(containerView)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .beginFromCurrentState, animations: {
            self.hudView.alpha = 1
        }, completion: nil)
    }
    
    func hide() {
        guard isShowing else {
            return
        }
        UIView.animate(withDuration: 0.2, animations: {
            self.hudView.alpha = 0
        }, completion: { (_) in
            self.containerView.removeFromSuperview()
            self.isShowing = false
        })
    }

    func hideInMainThread() {
        if Thread.isMainThread {
            hide()
        } else {
            DispatchQueue.main.async {
                self.hide()
            }
        }
    }
    
}
