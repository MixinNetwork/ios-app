import UIKit
import MixinServices

class MinimizedCallViewController: HomeOverlayViewController {
    
    @IBOutlet weak var statusLabel: UILabel!
    
    weak var call: Call? {
        didSet {
            let center = NotificationCenter.default
            if let old = oldValue {
                center.removeObserver(self,
                                      name: Call.stateDidChangeNotification,
                                      object: old)
            }
            if let call = call {
                center.addObserver(self,
                                   selector: #selector(callStateDidChange(_:)),
                                   name: Call.stateDidChangeNotification,
                                   object: call)
            }
            loadViewIfNeeded()
            updateLabel(call: call)
        }
    }
    
    private weak var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
    }
    
    func setViewHidden(_ hidden: Bool) {
        view.alpha = hidden ? 0 : 1
    }
    
    @IBAction func maximizeAction(_ sender: Any) {
        CallService.shared.setInterfaceMinimized(false, animated: true)
    }
    
    @objc private func callStateDidChange(_ notification: Notification) {
        updateLabel(call: call)
    }
    
    private func beginUpdatingDuration() {
        guard timer == nil else {
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (_) in
            if let call = self.call {
                self.statusLabel.text = call.briefLocalizedState
            }
            self.updateViewSize()
            self.panningController.stickViewToEdgeIfNotPanning(animated: true)
        })
    }
    
    private func endUpdatingDuration() {
        timer?.invalidate()
    }
    
    private func updateLabel(call: Call?) {
        defer {
            updateViewSize()
            panningController.stickViewToEdgeIfNotPanning(animated: true)
        }
        guard let call = call else {
            endUpdatingDuration()
            statusLabel.text = nil
            setViewHidden(true)
            Logger.call.warn(category: "MinimizedCallViewController", message: "Update label without a call")
            return
        }
        statusLabel.text = call.briefLocalizedState
        if call.state == .connected {
            beginUpdatingDuration()
        } else {
            endUpdatingDuration()
        }
    }
    
}
