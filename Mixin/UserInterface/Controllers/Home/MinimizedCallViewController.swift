import UIKit

class MinimizedCallViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    
    private weak var timer: Timer?
    
    private var centerRestriction: CGRect {
        let superview = parent?.view ?? AppDelegate.current.mainWindow
        let halfContentWidth = view.frame.size.width / 2
        let halfContentHeight = view.frame.size.height / 2
        let contentInsets = UIEdgeInsets(top: halfContentHeight,
                                         left: halfContentWidth,
                                         bottom: halfContentHeight,
                                         right: halfContentWidth)
        return superview.bounds
            .inset(by: superview.safeAreaInsets)
            .inset(by: contentInsets)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        updateLabel(status: CallService.shared.activeCall?.status)
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.18
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateViews(_:)),
                                               name: Call.statusDidChangeNotification,
                                               object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.shadowPath = CGPath(roundedRect: contentView.frame.offsetBy(dx: 0, dy: 4),
                                       cornerWidth: contentView.layer.cornerRadius,
                                       cornerHeight: contentView.layer.cornerRadius,
                                       transform: nil)
    }
    
    @IBAction func panAction(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            recognizer.setTranslation(.zero, in: nil)
        case .changed:
            view.center = view.center + recognizer.translation(in: nil)
            recognizer.setTranslation(.zero, in: nil)
        case .ended:
            stickViewToEdge(center: view.center, animated: true)
        default:
            break
        }
    }
    
    @IBAction func maximizeAction(_ sender: Any) {
        CallService.shared.setInterfaceMinimized(false, animated: true)
    }
    
    @objc private func updateViews(_ notification: Notification) {
        guard let status = notification.userInfo?[Call.newCallStatusUserInfoKey] as? Call.Status else {
            return
        }
        updateLabel(status: status)
    }
    
    func placeViewToTopRight() {
        view.center = CGPoint(x: centerRestriction.maxX,
                              y: centerRestriction.minY)
    }
    
    func stickViewToEdge(center: CGPoint, animated: Bool) {
        let newCenter: CGPoint = {
            let x = center.x > centerRestriction.midX ? centerRestriction.maxX : centerRestriction.minX
            let y = max(centerRestriction.minY, min(centerRestriction.maxY, center.y))
            return CGPoint(x: x, y: y)
        }()
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.view.center = newCenter
        }, completion: nil)
    }
    
    private func beginUpdatingDuration() {
        guard timer == nil else {
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (_) in
            self.statusLabel.text = CallService.shared.connectionDuration
        })
    }
    
    private func endUpdatingDuration() {
        timer?.invalidate()
    }
    
    private func updateLabel(status: Call.Status?) {
        guard let status = status else {
            endUpdatingDuration()
            statusLabel.text = nil
            return
        }
        if status == .connected {
            statusLabel.text = CallService.shared.connectionDuration
            beginUpdatingDuration()
        } else {
            endUpdatingDuration()
            statusLabel.text = status.briefLocalizedDescription
        }
    }
    
}
