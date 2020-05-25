import UIKit
import MixinServices

class CallViewController: UIViewController {
    
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
    
    weak var service: CallService!
    
    var style = Style.disconnecting {
        didSet {
            layout(for: style)
        }
    }
    
    private let animationDuration: TimeInterval = 0.3
    
    private weak var timer: Timer?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusLabel.setFont(scaledFor: .monospacedDigitSystemFont(ofSize: 14, weight: .regular), adjustForContentSize: true)
    }
    
    func disableConnectionDurationTimer() {
        setConnectionDurationTimerEnabled(false)
    }
    
    func reload(user: UserItem) {
        avatarImageView.setImage(with: user)
        nameLabel.text = user.fullName
        muteButton.isSelected = false
        speakerButton.isSelected = false
    }
    
    @IBAction func hangUpAction(_ sender: Any) {
        service.requestEndCall()
    }
    
    @IBAction func acceptAction(_ sender: Any) {
        service.requestAnswerCall()
    }
    
    @IBAction func setMuteAction(_ sender: Any) {
        muteButton.isSelected = !muteButton.isSelected
        service.isMuted = muteButton.isSelected
    }
    
    @IBAction func setSpeakerAction(_ sender: Any) {
        speakerButton.isSelected = !speakerButton.isSelected
        service.usesSpeaker = speakerButton.isSelected
    }
    
}

extension CallViewController {
    
    enum Style {
        case incoming
        case outgoing
        case connecting
        case connected
        case disconnecting
    }
    
    private var localizedStatus: String? {
        switch style {
        case .incoming:
            return Localized.CALL_STATUS_BEING_CALLING
        case .outgoing:
            return Localized.CALL_STATUS_CALLING
        case .connecting:
            return Localized.CALL_STATUS_CONNECTING
        case .connected:
            return nil
        case .disconnecting:
            return Localized.CALL_STATUS_DISCONNECTING
        }
    }
    
    @objc private func updateStatusLabelWithCallingDuration() {
        if style == .connected, let timeIntervalSinceNow = service.call?.connectedDate?.timeIntervalSinceNow {
            let duration = abs(timeIntervalSinceNow)
            statusLabel.text = mediaDurationFormatter.string(from: duration)
        } else {
            statusLabel.text = nil
        }
    }
    
    private func layout(for style: Style) {
        if style == .connected {
            statusLabel.text = mediaDurationFormatter.string(from: 0)
        } else {
            statusLabel.text = localizedStatus
        }
        switch style {
        case .incoming:
            hangUpTitleLabel.text = Localized.CALL_FUNC_DECLINE
            setFunctionSwitchesHidden(true)
            setAcceptButtonHidden(false)
            setConnectionButtonsEnabled(true)
        case .outgoing:
            hangUpTitleLabel.text = Localized.CALL_FUNC_HANGUP
            setFunctionSwitchesHidden(true)
            setAcceptButtonHidden(true)
            setConnectionButtonsEnabled(true)
        case .connecting:
            hangUpTitleLabel.text = Localized.CALL_FUNC_HANGUP
            UIView.animate(withDuration: animationDuration) {
                self.setFunctionSwitchesHidden(true)
                self.setAcceptButtonHidden(true)
                self.setConnectionButtonsEnabled(true)
                self.view.layoutIfNeeded()
            }
        case .connected:
            hangUpTitleLabel.text = Localized.CALL_FUNC_HANGUP
            UIView.animate(withDuration: animationDuration) {
                self.setAcceptButtonHidden(true)
                self.setFunctionSwitchesHidden(false)
                self.view.layoutIfNeeded()
            }
            setConnectionDurationTimerEnabled(true)
        case .disconnecting:
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
