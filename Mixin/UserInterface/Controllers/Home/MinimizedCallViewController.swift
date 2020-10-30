import UIKit
import MixinServices

class MinimizedCallViewController: HomeOverlayViewController {
    
    @IBOutlet weak var statusLabel: UILabel!
    
    weak var call: Call? {
        didSet {
            updateLabel(status: call?.status)
        }
    }
    
    private weak var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        updateLabel(status: CallService.shared.activeCall?.status)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(callStatusDidChange(_:)),
                                               name: Call.statusDidChangeNotification,
                                               object: nil)
    }
    
    @IBAction func maximizeAction(_ sender: Any) {
        CallService.shared.setInterfaceMinimized(false, animated: true)
    }
    
    @objc private func callStatusDidChange(_ notification: Notification) {
        guard (notification.object as? Call) == self.call else {
            return
        }
        guard let status = notification.userInfo?[Call.statusUserInfoKey] as? Call.Status else {
            return
        }
        DispatchQueue.main.async {
            self.updateLabel(status: status)
        }
    }
    
    private func beginUpdatingDuration() {
        guard timer == nil else {
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (_) in
            self.statusLabel.text = CallService.shared.connectionDuration
            self.updateViewSize()
            self.panningController.stickViewToEdgeIfNotPanning(animated: true)
        })
    }
    
    private func endUpdatingDuration() {
        timer?.invalidate()
    }
    
    private func updateLabel(status: Call.Status?) {
        defer {
            updateViewSize()
            panningController.stickViewToEdgeIfNotPanning(animated: true)
        }
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
