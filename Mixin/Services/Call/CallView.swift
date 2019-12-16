import UIKit

class CallView: UIVisualEffectView {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var speakerButton: UIButton!
    @IBOutlet weak var hangUpButton: UIButton!
    @IBOutlet weak var hangUpTitleLabel: UILabel!
    @IBOutlet weak var acceptStackView: UIStackView!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var muteStackView: UIStackView!
    @IBOutlet weak var speakerStackView: UIStackView!
    
    @IBOutlet weak var hangUpButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var hangUpButtonCenterXConstraint: NSLayoutConstraint!
    
    weak var manager: CallManager!
    
    var style = Style.calling {
        didSet {
            layout(for: style)
        }
    }
    
    private let animationDuration: TimeInterval = 0.3
    
    private var timer: Timer?
    private var isOutgoing: Bool {
        return manager.call?.isOutgoing ?? true
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadSubviews()
    }
    
    override init(effect: UIVisualEffect?) {
        super.init(effect: effect)
        loadSubviews()
    }
    
    func show() {
        let window = AppDelegate.current.window
        window.endEditing(true)
        frame = window.bounds
        window.addSubview(self)
    }
    
    func dismiss() {
        setConnectionDurationTimerEnabled(false)
        removeFromSuperview()
    }
    
    func reload(user: UserItem) {
        avatarImageView.setImage(with: user)
        nameLabel.text = user.fullName
        muteButton.isSelected = false
        speakerButton.isSelected = false
    }
    
    @IBAction func hangUpAction(_ sender: Any) {
        manager.completeCurrentCall(isUserInitiated: true)
    }
    
    @IBAction func acceptAction(_ sender: Any) {
        manager.acceptCurrentCall()
    }
    
    @IBAction func setMuteAction(_ sender: Any) {
        muteButton.isSelected = !muteButton.isSelected
        manager.isMuted = muteButton.isSelected
    }
    
    @IBAction func setSpeakerAction(_ sender: Any) {
        speakerButton.isSelected = !speakerButton.isSelected
        manager.usesSpeaker = speakerButton.isSelected
    }
    
}

extension CallView {
    
    enum Style {
        case calling
        case connecting
        case connected
        case disconnecting
    }
    
    private var localizedStatus: String? {
        switch style {
        case .calling:
            return isOutgoing ? Localized.CALL_STATUS_CALLING : Localized.CALL_STATUS_BEING_CALLING
        case .connecting:
            return Localized.CALL_STATUS_CONNECTING
        case .connected:
            return nil
        case .disconnecting:
            return Localized.CALL_STATUS_DISCONNECTING
        }
    }
    
    @objc private func updateStatusLabelWithCallingDuration() {
        if style == .connected, let timeIntervalSinceNow = manager.call?.connectedDate?.timeIntervalSinceNow {
            let duration = abs(timeIntervalSinceNow)
            statusLabel.text = mediaDurationFormatter.string(from: duration)
        } else {
            statusLabel.text = nil
        }
    }
    
    private func loadSubviews() {
        layoutMargins = .zero
        let nibName = String(describing: type(of: self))
        if let xibView = Bundle.main.loadNibNamed(nibName, owner: self, options: nil)?.first as? UIView {
            xibView.frame = bounds
            contentView.addSubview(xibView)
        }
        statusLabel.setFont(scaledFor: .monospacedDigitSystemFont(ofSize: 14, weight: .regular), adjustForContentSize: true)
    }
    
    private func layout(for style: Style) {
        if style == .connected {
            statusLabel.text = mediaDurationFormatter.string(from: 0)
        } else {
            statusLabel.text = localizedStatus
        }
        switch style {
        case .calling:
            hangUpTitleLabel.text = isOutgoing ? Localized.CALL_FUNC_HANGUP : Localized.CALL_FUNC_DECLINE
            setFunctionSwitchesHidden(true)
            setAcceptButtonHidden(isOutgoing)
            setConnectionButtonsEnabled(true)
        case .connecting:
            hangUpTitleLabel.text = Localized.CALL_FUNC_HANGUP
            UIView.animate(withDuration: animationDuration) {
                self.setFunctionSwitchesHidden(true)
                self.setAcceptButtonHidden(true)
                self.setConnectionButtonsEnabled(true)
                self.layoutIfNeeded()
            }
        case .connected:
            hangUpTitleLabel.text = Localized.CALL_FUNC_HANGUP
            UIView.animate(withDuration: animationDuration) {
                self.setAcceptButtonHidden(true)
                self.setFunctionSwitchesHidden(false)
                self.layoutIfNeeded()
            }
            setConnectionDurationTimerEnabled(true)
        case .disconnecting:
            timer?.invalidate()
            timer = nil
            setAcceptButtonHidden(true)
            setConnectionButtonsEnabled(false)
            setConnectionDurationTimerEnabled(false)
        }
    }
    
    private func setAcceptButtonHidden(_ hidden: Bool) {
        acceptStackView.alpha = hidden ? 0 : 1
        if hidden {
            hangUpButtonLeadingConstraint.priority = .defaultLow
            hangUpButtonCenterXConstraint.priority = .defaultHigh
        } else {
            hangUpButtonLeadingConstraint.priority = .defaultHigh
            hangUpButtonCenterXConstraint.priority = .defaultLow
        }
    }
    
    private func setConnectionButtonsEnabled(_ enabled: Bool) {
        acceptButton.isEnabled = enabled
        hangUpButton.isEnabled = enabled
    }
    
    private func setFunctionSwitchesHidden(_ hidden: Bool) {
        let alpha: CGFloat = hidden ? 0 : 1
        muteStackView.alpha = alpha
        speakerStackView.alpha = alpha
    }
    
    private func setConnectionDurationTimerEnabled(_ enabled: Bool) {
        timer?.invalidate()
        timer = nil
        if enabled {
            let timer = Timer(timeInterval: 1,
                              target: self,
                              selector: #selector(updateStatusLabelWithCallingDuration),
                              userInfo: nil,
                              repeats: true)
            RunLoop.main.add(timer, forMode: .default)
            self.timer = timer
        }
    }
    
}
