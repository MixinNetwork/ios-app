import UIKit

protocol ConnectionHintViewDelegate: class {
    func animateAlongsideConnectionHintView(_ view: ConnectionHintView, changingHeightWithDifference heightDifference: CGFloat)
}

class ConnectionHintView: UIView, XibDesignable {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var backgroundView: UIView!
    
    @IBOutlet weak var connectionHintViewHeightConstraint: NSLayoutConstraint!
    
    weak var delegate: ConnectionHintViewDelegate?
    
    private enum Style {
        case connecting
        case error
        case toast
    }

    private var style: Style = .connecting {
        didSet {
            switch style {
            case .connecting:
                activityIndicator.isHidden = false
                label.text = Localized.CONNECTION_HINT_CONNECTING
            case .error:
                activityIndicator.isHidden = true
                label.text = errorMsg
            case .toast:
                activityIndicator.isHidden = true
                label.text = toastMsg
            }
        }
    }

    private var errorMsg = ""
    private var toastMsg = ""
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    private func prepare() {
        loadXib()
        setConnectionHintHidden(WebSocketService.shared.connected, animated: false)
        NotificationCenter.default.addObserver(self, selector: #selector(updateConnectionHint), name: .SocketStatusChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showErrorMessage(_:)), name: .ErrorMessageDidAppear, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showToastMessage(_:)), name: .ToastMessageDidAppear, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setConnectionHintHidden(_ hidden: Bool, animated: Bool = true) {
        switch style {
        case .connecting:
            backgroundView.backgroundColor = UIColor.hintBlue
        case .error:
            backgroundView.backgroundColor = UIColor.hintRed
        case .toast:
            backgroundView.backgroundColor = UIColor.hintGreen
        }
        let newHeight: CGFloat = hidden ? 0 : 36
        let heightDifference = newHeight - connectionHintViewHeightConstraint.constant
        connectionHintViewHeightConstraint.constant = newHeight
        let block = {
            self.delegate?.animateAlongsideConnectionHintView(self, changingHeightWithDifference: heightDifference)
            self.superview?.superview?.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut], animations: {
                block()
            })
        } else {
            block()
        }
    }

    @objc func showErrorMessage(_ notification: Notification) {
        guard let errorMsg = notification.object as? String, isVisibleInScreen, WebSocketService.shared.connected else {
            return
        }
        self.errorMsg = errorMsg
        style = .error
        setConnectionHintHidden(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.setConnectionHintHidden(true, animated: true)
        }
    }

    @objc func showToastMessage(_ notification: Notification) {
        guard let toastMsg = notification.object as? String, isVisibleInScreen else {
            return
        }
        self.toastMsg = toastMsg
        style = .toast
        setConnectionHintHidden(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let weakSelf = self else {
                return
            }
            weakSelf.setConnectionHintHidden(true, animated: true)
        }
    }

    @objc func updateConnectionHint() {
        if !WebSocketService.shared.connected {
            style = .connecting
        }
        setConnectionHintHidden(WebSocketService.shared.connected)
    }
    
}
