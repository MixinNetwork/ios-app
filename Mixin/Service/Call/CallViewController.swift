import UIKit
import AVFoundation.AVFAudio
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
    
    @IBOutlet weak var topSafeAreaPlaceholderHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var hangUpButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var hangUpButtonCenterXConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomSafeAreaPlaceholderHeightConstraint: NSLayoutConstraint!
    
    weak var service: CallService!
    
    private let animationDuration: TimeInterval = 0.3
    
    private weak var timer: Timer?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if service.isMinimized {
            return AppDelegate.current.mainWindow.rootViewController?.preferredStatusBarStyle ?? .default
        } else {
            return .lightContent
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusLabel.setFont(scaledFor: .monospacedDigitSystemFont(ofSize: 14, weight: .regular),
                            adjustForContentSize: true)
        
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(callServiceMutenessDidChange),
                           name: CallService.mutenessDidChangeNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(audioSessionRouteChange(_:)),
                           name: AVAudioSession.routeChangeNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(updateViews(_:)),
                           name: Call.statusDidChangeNotification,
                           object: nil)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        topSafeAreaPlaceholderHeightConstraint.constant = max(topSafeAreaPlaceholderHeightConstraint.constant, view.safeAreaInsets.top)
        bottomSafeAreaPlaceholderHeightConstraint.constant = max(bottomSafeAreaPlaceholderHeightConstraint.constant, view.safeAreaInsets.bottom)
    }
    
    func disableConnectionDurationTimer() {
        setConnectionDurationTimerEnabled(false)
    }
    
    func reload(userId: String, username: String) {
        nameLabel.text = username
        avatarImageView.prepareForReuse()
        avatarImageView.setImage(userId: userId, name: username)
        muteButton.isSelected = service.isMuted
        speakerButton.isSelected = service.usesSpeaker
    }
    
    func reload(user: UserItem) {
        nameLabel.text = user.fullName
        avatarImageView.prepareForReuse()
        avatarImageView.setImage(with: user)
        muteButton.isSelected = service.isMuted
        speakerButton.isSelected = service.usesSpeaker
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
    
    @IBAction func minimizeAction(_ sender: Any) {
        service.setInterfaceMinimized(!service.isMinimized, animated: true)
    }
    
}

extension CallViewController {
    
    @objc private func callServiceMutenessDidChange() {
        muteButton.isSelected = service.isMuted
    }
    
    @objc private func audioSessionRouteChange(_ notification: Notification) {
        let routeContainsSpeaker = AVAudioSession.sharedInstance().currentRoute
            .outputs.map(\.portType)
            .contains(.builtInSpeaker)
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .active && (self.service.usesSpeaker != routeContainsSpeaker) {
                // The audio route changes for mysterious reason on iOS 13, It says category changes
                // but I have intercept every category change request only to find AVAudioSessionCategoryPlayAndRecord
                // with AVAudioSessionCategoryOptionDefaultToSpeaker is properly passed into AVAudioSession.
                // According to stack trace result, the route changes is triggered by avfaudio::AVAudioSessionPropertyListener
                // Don't quite know why the heck this is happening, but overriding the port immediately like this seems to work
                self.service.usesSpeaker = self.service.usesSpeaker
                self.speakerButton.isSelected = self.service.usesSpeaker
            } else {
                self.speakerButton.isSelected = routeContainsSpeaker
            }
        }
    }
    
    @objc private func updateViews(_ notification: Notification) {
        guard let status = notification.userInfo?[Call.newCallStatusUserInfoKey] as? Call.Status else {
            return
        }
        if status == .connected {
            statusLabel.text = CallService.shared.connectionDuration
        } else {
            statusLabel.text = status.localizedDescription
        }
        switch status {
        case .incoming:
            hangUpTitleLabel.text = Localized.CALL_FUNC_DECLINE
            setFunctionSwitchesHidden(true)
            setAcceptButtonHidden(false)
            setConnectionButtonsEnabled(true)
        case .outgoing:
            hangUpTitleLabel.text = Localized.CALL_FUNC_HANGUP
            setFunctionSwitchesHidden(false)
            setAcceptButtonHidden(true)
            setConnectionButtonsEnabled(true)
        case .connecting:
            hangUpTitleLabel.text = Localized.CALL_FUNC_HANGUP
            UIView.animate(withDuration: animationDuration) {
                self.setFunctionSwitchesHidden(false)
                self.setAcceptButtonHidden(true)
                self.setConnectionButtonsEnabled(true)
                self.view.layoutIfNeeded()
            }
        case .connected:
            hangUpTitleLabel.text = Localized.CALL_FUNC_HANGUP
            UIView.animate(withDuration: animationDuration) {
                self.setAcceptButtonHidden(true)
                self.setFunctionSwitchesHidden(false)
                self.setConnectionButtonsEnabled(true)
                self.view.layoutIfNeeded()
            }
            setConnectionDurationTimerEnabled(true)
        case .disconnecting:
            setAcceptButtonHidden(true)
            setConnectionButtonsEnabled(false)
            setConnectionDurationTimerEnabled(false)
        }
    }
    
}

extension CallViewController {
    
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
        if enabled {
            let timer = Timer(timeInterval: 1, repeats: true) { (_) in
                self.statusLabel.text = CallService.shared.connectionDuration
            }
            RunLoop.main.add(timer, forMode: .default)
            self.timer = timer
        }
    }
    
}
