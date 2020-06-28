import UIKit
import AVFoundation.AVFAudio
import RDHCollectionViewGridLayout
import MixinServices

class CallViewController: UIViewController {
    
    @IBOutlet weak var inviteButton: UIButton!
    @IBOutlet weak var singleUserStackView: UIStackView!
    @IBOutlet weak var multipleUserCollectionView: GroupCallMembersCollectionView!
    @IBOutlet weak var multipleUserCollectionLayout: RDHCollectionViewGridLayout!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var muteSwitch: CallSwitch!
    @IBOutlet weak var speakerSwitch: CallSwitch!
    @IBOutlet weak var hangUpButton: UIButton!
    @IBOutlet weak var hangUpTitleLabel: UILabel!
    @IBOutlet weak var acceptStackView: UIStackView!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var muteStackView: UIStackView!
    @IBOutlet weak var speakerStackView: UIStackView!
    
    @IBOutlet weak var topSafeAreaPlaceholderHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var multipleUserCollectionViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var multipleUserCollectionViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var hangUpButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var hangUpButtonCenterXConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomSafeAreaPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private unowned let service: CallService
    
    private weak var call: Call?
    private weak var timer: Timer?
    
    private var statusObservation: NSKeyValueObservation?
    private var groupCallMembers = [UserItem]()
    private var connectedGroupCallMemberUserIds = Set<String>()
    
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
        multipleUserCollectionView.register(R.nib.groupCallMemberCell)
        multipleUserCollectionView.dataSource = self
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(callServiceMutenessDidChange),
                           name: CallService.mutenessDidChangeNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(audioSessionRouteChange(_:)),
                           name: AVAudioSession.routeChangeNotification,
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
        guard let call = call as? GroupCall else {
            return
        }
        if call.membersDataSource.allMembers.count <= 9 {
            let itemLength: CGFloat = 76
            let itemCount: UInt = 3
            multipleUserCollectionLayout.lineSize = itemLength
            multipleUserCollectionLayout.lineItemCount = itemCount
            let totalSpacing = view.bounds.width - itemLength * CGFloat(itemCount)
            let interitemSpacing = floor(totalSpacing / 6)
            multipleUserCollectionLayout.itemSpacing = interitemSpacing
            let sectionInset = interitemSpacing * 2
            multipleUserCollectionViewLeadingConstraint.constant = sectionInset
            multipleUserCollectionViewTrailingConstraint.constant = sectionInset
        } else {
            let itemLength: CGFloat = 64
            let itemCount: UInt = 4
            multipleUserCollectionLayout.lineSize = itemLength
            multipleUserCollectionLayout.lineItemCount = itemCount
            let totalSpacing = view.bounds.width - itemLength * CGFloat(itemCount)
            let interitemSpacing = floor(totalSpacing / 6)
            multipleUserCollectionLayout.itemSpacing = interitemSpacing
            let sectionInset = floor(interitemSpacing / 2 * 3)
            multipleUserCollectionViewLeadingConstraint.constant = sectionInset
            multipleUserCollectionViewTrailingConstraint.constant = sectionInset
        }
    }
    
    func disableConnectionDurationTimer() {
        setConnectionDurationTimerEnabled(false)
    }
    
    func reloadAndObserve(call: Call?) {
        self.call = call
        
        statusObservation?.invalidate()
        statusObservation = call?.observe(\.status) { [weak self] (call, _) in
            performSynchronouslyOnMainThread {
                self?.updateViews(status: call.status)
            }
        }
        
        avatarImageView.prepareForReuse()
        if let call = call as? PeerToPeerCall {
            inviteButton.isHidden = true
            singleUserStackView.isHidden = false
            multipleUserCollectionView.isHidden = true
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
            inviteButton.isHidden = false
            singleUserStackView.isHidden = true
            multipleUserCollectionView.isHidden = false
            updateViews(status: call.status)
            call.membersDataSource.collectionView = multipleUserCollectionView
        }
        muteSwitch.isOn = service.isMuted
        speakerSwitch.isOn = service.usesSpeaker
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
    
    @IBAction func minimizeAction(_ sender: Any) {
        service.setInterfaceMinimized(!service.isMinimized, animated: true)
    }
    
    @IBAction func addMemberAction(_ sender: Any) {
        guard let call = self.call as? GroupCall else {
            return
        }
        let picker = GroupCallMemberPickerViewController(conversation: call.conversation)
        picker.appearance = .appendToExistedCall
        picker.fixedSelections = call.membersDataSource.allMembers
        picker.onConfirmation = { users in
            guard !users.isEmpty else {
                return
            }
            call.invite(users: users)
        }
        present(picker, animated: true, completion: nil)
    }
    
}

extension CallViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        groupCallMembers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.group_call_member, for: indexPath)!
        let member = groupCallMembers[indexPath.row]
        cell.avatarImageView.setImage(with: member)
        cell.connectingView.isHidden = connectedGroupCallMemberUserIds.contains(member.userId)
        return cell
    }
    
}

extension CallViewController {
    
    @objc private func callServiceMutenessDidChange() {
        muteSwitch.isOn = service.isMuted
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
    
    private func updateViews(status: Call.Status) {
        let animationDuration: TimeInterval = 0.3
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
