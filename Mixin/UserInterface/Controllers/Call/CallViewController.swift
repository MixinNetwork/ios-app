import UIKit
import AVFoundation.AVFAudio
import MixinServices

class CallViewController: UIViewController {
    
    @IBOutlet weak var minimizeButton: UIButton!
    @IBOutlet weak var inviteButton: UIButton!
    @IBOutlet weak var groupNameLabel: UILabel!
    @IBOutlet weak var peerToPeerCallRemoteUserStackView: UIStackView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var groupCallMembersCollectionView: GroupCallMembersCollectionView!
    @IBOutlet weak var groupCallMembersCollectionLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var muteSwitch: CallSwitch!
    @IBOutlet weak var speakerSwitch: CallSwitch!
    @IBOutlet weak var hangUpStackView: UIStackView!
    @IBOutlet weak var hangUpButton: UIButton!
    @IBOutlet weak var hangUpTitleLabel: UILabel!
    @IBOutlet weak var acceptStackView: UIStackView!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var acceptTitleLabel: UILabel!
    @IBOutlet weak var muteStackView: UIStackView!
    @IBOutlet weak var speakerStackView: UIStackView!
    
    @IBOutlet weak var topSafeAreaPlaceholderHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var multipleUserCollectionViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var multipleUserCollectionViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var hangUpButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var hangUpButtonCenterXConstraint: NSLayoutConstraint!
    @IBOutlet weak var acceptButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var acceptButtonCenterXConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomSafeAreaPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private unowned let service: CallService
    
    private weak var call: Call?
    private weak var timer: Timer?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if service.isMinimized {
            return AppDelegate.current.mainWindow.rootViewController?.preferredStatusBarStyle ?? .default
        } else {
            return .lightContent
        }
    }
    
    init(service: CallService) {
        self.service = service
        let nib = R.nib.callView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        muteSwitch.iconPath = CallIconPath.mute
        speakerSwitch.iconPath = CallIconPath.speaker
        statusLabel.setFont(scaledFor: .monospacedDigitSystemFont(ofSize: 14, weight: .regular),
                            adjustForContentSize: true)
        groupCallMembersCollectionView.register(R.nib.groupCallMemberCell)
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
                           selector: #selector(groupCallMembersDidChange),
                           name: GroupCallMemberDataSource.membersDidChangeNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(callStatusDidChange(_:)),
                           name: Call.statusDidChangeNotification,
                           object: nil)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        let topHeight = max(topSafeAreaPlaceholderHeightConstraint.constant, view.safeAreaInsets.top)
        topSafeAreaPlaceholderHeightConstraint.constant = topHeight
        let bottomHeight = max(bottomSafeAreaPlaceholderHeightConstraint.constant, view.safeAreaInsets.bottom)
        bottomSafeAreaPlaceholderHeightConstraint.constant = bottomHeight
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard let dataSource = groupCallMembersCollectionView.dataSource else {
            return
        }
        let sectionsCount = dataSource.numberOfSections?(in: groupCallMembersCollectionView) ?? 0
        let allMembersCount = (0..<sectionsCount)
            .map({ dataSource.collectionView(groupCallMembersCollectionView, numberOfItemsInSection: $0) })
            .reduce(0, +)
        if allMembersCount <= 9 {
            let itemLength: CGFloat = 76
            groupCallMembersCollectionLayout.itemSize = CGSize(width: itemLength, height: itemLength)
            let totalSpacing = view.bounds.width - itemLength * 3
            let interitemSpacing = floor(totalSpacing / 6)
            let sectionInset = interitemSpacing * 2
            groupCallMembersCollectionLayout.minimumInteritemSpacing = interitemSpacing
            groupCallMembersCollectionLayout.sectionInset = UIEdgeInsets(top: 0, left: sectionInset, bottom: 0, right: sectionInset)
        } else {
            let itemLength: CGFloat = 64
            groupCallMembersCollectionLayout.itemSize = CGSize(width: itemLength, height: itemLength)
            let totalSpacing = view.bounds.width - itemLength * 4
            let interitemSpacing = floor(totalSpacing / 6)
            let sectionInset = floor(interitemSpacing / 2 * 3)
            groupCallMembersCollectionLayout.minimumInteritemSpacing = interitemSpacing
            groupCallMembersCollectionLayout.sectionInset = UIEdgeInsets(top: 0, left: sectionInset, bottom: 0, right: sectionInset)
        }
    }
    
    func disableConnectionDurationTimer() {
        setConnectionDurationTimerEnabled(false)
    }
    
    func reload(call: Call?) {
        self.call = call
        
        avatarImageView.prepareForReuse()
        if let call = call as? PeerToPeerCall {
            groupNameLabel.text = " "
            inviteButton.isHidden = true
            peerToPeerCallRemoteUserStackView.isHidden = false
            groupCallMembersCollectionView.isHidden = true
            if let user = call.remoteUser {
                nameLabel.text = user.fullName
                avatarImageView.setImage(with: user)
            } else {
                nameLabel.text = call.remoteUsername
                avatarImageView.setImage(userId: call.remoteUserId,
                                         name: call.remoteUsername)
            }
            updateViews(status: call.status)
        } else if let call = call as? GroupCall {
            groupNameLabel.text = call.conversationName
            inviteButton.isHidden = false
            inviteButton.isEnabled = call.membersDataSource.members.count < GroupCall.maxNumberOfMembers
            peerToPeerCallRemoteUserStackView.isHidden = true
            groupCallMembersCollectionView.isHidden = false
            updateViews(status: call.status)
            call.membersDataSource.collectionView = groupCallMembersCollectionView
        }
        muteSwitch.isOn = service.isMuted
        speakerSwitch.isOn = service.usesSpeaker
    }
    
    @IBAction func minimizeAction(_ sender: Any) {
        service.setInterfaceMinimized(!service.isMinimized, animated: true)
    }
    
    @IBAction func addMemberAction(_ sender: Any) {
        guard let call = self.call as? GroupCall else {
            return
        }
        let picker = GroupCallMemberPickerViewController(conversation: call.conversation)
        picker.appearance = .appendToExistedCall
        picker.fixedSelections = call.membersDataSource.members
        picker.onConfirmation = { members in
            CallService.shared.queue.async {
                call.invite(members: members)
            }
        }
        present(picker, animated: true, completion: nil)
    }
    
    @IBAction func showEncryptionHintAction(_ sender: Any) {
        let alert = UIAlertController(title: R.string.localizable.call_encryption_title(),
                                      message: R.string.localizable.call_encryption_description(),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.action_learn_more(), style: .default, handler: { (_) in
            MixinWebViewController.presentInstance(with: .init(conversationId: "", initialUrl: .aboutEncryption), asChildOf: self)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func hangUpAction(_ sender: Any) {
        service.requestEndCall()
    }
    
    @IBAction func acceptAction(_ sender: Any) {
        service.requestAnswerCall()
    }
    
    @IBAction func setMuteAction(_ sender: Any) {
        service.isMuted = muteSwitch.isOn
    }
    
    @IBAction func setSpeakerAction(_ sender: Any) {
        service.usesSpeaker = speakerSwitch.isOn
    }
    
}

extension CallViewController {
    
    @objc private func callServiceMutenessDidChange() {
        muteSwitch.isOn = service.isMuted
    }
    
    @objc private func groupCallMembersDidChange(_ notification: Notification) {
        guard let dataSource = notification.object as? GroupCallMemberDataSource else {
            return
        }
        guard dataSource == (call as? GroupCall)?.membersDataSource else {
            return
        }
        inviteButton.isEnabled = dataSource.members.count < GroupCall.maxNumberOfMembers
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
                self.speakerSwitch.isOn = self.service.usesSpeaker
            } else {
                self.speakerSwitch.isOn = routeContainsSpeaker
            }
        }
    }
    
    @objc private func callStatusDidChange(_ notification: Notification) {
        guard (notification.object as? Call) == self.call else {
            return
        }
        guard let status = notification.userInfo?[Call.statusUserInfoKey] as? Call.Status else {
            return
        }
        DispatchQueue.main.async {
            self.updateViews(status: status)
        }
    }
    
    private func updateViews(status: Call.Status) {
        let animationDuration: TimeInterval = 0.3
        if status == .connected {
            statusLabel.text = CallService.shared.connectionDuration
        } else {
            statusLabel.text = status.localizedDescription
        }
        switch status {
        case .incoming:
            minimizeButton.isHidden = true
            hangUpTitleLabel.text = Localized.CALL_FUNC_DECLINE
            setFunctionSwitchesHidden(true)
            setAcceptButtonHidden(false)
            setConnectionButtonsEnabled(true)
        case .outgoing:
            minimizeButton.isHidden = false
            hangUpTitleLabel.text = Localized.CALL_FUNC_HANGUP
            setFunctionSwitchesHidden(false)
            setAcceptButtonHidden(true)
            setConnectionButtonsEnabled(true)
        case .connecting:
            minimizeButton.isHidden = false
            hangUpTitleLabel.text = Localized.CALL_FUNC_HANGUP
            UIView.animate(withDuration: animationDuration) {
                self.setFunctionSwitchesHidden(false)
                self.setAcceptButtonHidden(true)
                self.setConnectionButtonsEnabled(true)
                self.view.layoutIfNeeded()
            }
        case .connected:
            minimizeButton.isHidden = false
            hangUpTitleLabel.text = Localized.CALL_FUNC_HANGUP
            UIView.animate(withDuration: animationDuration) {
                self.setAcceptButtonHidden(true)
                self.setFunctionSwitchesHidden(false)
                self.setConnectionButtonsEnabled(true)
                self.view.layoutIfNeeded()
            }
            setConnectionDurationTimerEnabled(true)
        case .disconnecting:
            minimizeButton.isHidden = true
            setAcceptButtonHidden(true)
            setConnectionButtonsEnabled(false)
            setConnectionDurationTimerEnabled(false)
        }
    }
    
}

extension CallViewController {
    
    func setAcceptButtonHidden(_ hidden: Bool) {
        acceptStackView.alpha = hidden ? 0 : 1
        if hidden {
            hangUpButtonLeadingConstraint.priority = .defaultLow
            hangUpButtonCenterXConstraint.priority = .defaultHigh
        } else {
            hangUpButtonLeadingConstraint.priority = .defaultHigh
            hangUpButtonCenterXConstraint.priority = .defaultLow
        }
    }
    
    func setConnectionButtonsEnabled(_ enabled: Bool) {
        acceptButton.isEnabled = enabled
        hangUpButton.isEnabled = enabled
    }
    
    func setFunctionSwitchesHidden(_ hidden: Bool) {
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
