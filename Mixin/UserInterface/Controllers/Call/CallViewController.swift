import UIKit
import AVFoundation.AVFAudio
import MixinServices

class CallViewController: ResizablePopupViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var minimizeButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton! // Preserved
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleButton: UIButton!
    @IBOutlet weak var membersWrapperView: UIView!
    @IBOutlet weak var membersCollectionView: UICollectionView!
    @IBOutlet weak var membersCollectionLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var membersCountLabel: UILabel!
    @IBOutlet weak var trayView: UIView!
    @IBOutlet weak var muteSwitch: UIButton!
    @IBOutlet weak var speakerSwitch: UIButton!
    @IBOutlet weak var hangUpStackView: UIStackView!
    @IBOutlet weak var hangUpButton: UIButton!
    @IBOutlet weak var acceptStackView: UIStackView!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var muteStackView: UIStackView!
    @IBOutlet weak var speakerStackView: UIStackView!
    @IBOutlet weak var statusLabel: UILabel!
    
    @IBOutlet weak var hideContentViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var showContentViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var hangUpButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var hangUpButtonCenterXConstraint: NSLayoutConstraint!
    @IBOutlet weak var acceptButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var acceptButtonCenterXConstraint: NSLayoutConstraint!
    @IBOutlet weak var trayContentViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var membersCountBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var trayContentViewBottomConstraint: NSLayoutConstraint!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if service.isInterfaceMinimized {
            return AppDelegate.current.mainWindow.rootViewController?.preferredStatusBarStyle ?? .default
        } else {
            return .lightContent
        }
    }
    
    override var resizableScrollView: UIScrollView? {
        membersCollectionView
    }
    
    override var automaticallyAdjustsResizableScrollViewBottomInset: Bool {
        false
    }
    
    unowned let service: CallService
    
    var members: [UserItem] = []
    
    private let membersCountBottomMargin: CGFloat = 32
    private let numberOfGroupCallMembersPerRow: CGFloat = 4
    
    private lazy var resizeRecognizerDelegate = PopupResizeGestureCoordinator(scrollView: resizableScrollView)
    
    private weak var call: Call?
    private weak var timer: Timer?
    
    private var isShowingContentView = false
    
    private var membersCountFont: UIFont {
        let font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        return UIFontMetrics.default.scaledFont(for: font)
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
        resizeRecognizer.delegate = resizeRecognizerDelegate
        view.addGestureRecognizer(resizeRecognizer)
        view.layer.cornerRadius = 0
        view.layer.maskedCorners = []
        for button in [hangUpButton, acceptButton, muteSwitch, speakerSwitch] {
            button!.imageView?.contentMode = .center
        }
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentView.layer.cornerRadius = 13
        hideContentViewConstraint.priority = .defaultHigh
        showContentViewConstraint.priority = .defaultLow
        let statusFont = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        statusLabel.setFont(scaledFor: statusFont, adjustForContentSize: true)
        UIView.performWithoutAnimation(subtitleButton.layoutIfNeeded) // Remove the animation by setText:
        collectionViewHeightConstraint.constant = calculatedCollectionViewHeight(size: .expanded)
        membersCollectionView.register(R.nib.callMemberCell)
        membersCollectionView.dataSource = self
        membersCollectionView.delegate = self
        membersCollectionLayout.headerReferenceSize = .zero
        membersCollectionLayout.footerReferenceSize = .zero
        membersCollectionLayout.minimumInteritemSpacing = 0
        membersCountLabel.font = membersCountFont
        membersCountLabel.adjustsFontForContentSizeCategory = true
        trayView.layer.shadowColor = UIColor.black.withAlphaComponent(0.2).cgColor
        trayView.layer.shadowOpacity = 1
        trayView.layer.shadowRadius = 10
        trayView.layer.shadowOffset = CGSize(width: 0, height: 2)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateSpeakerSwitch),
                                               name: CallService.audioOutputDidChangeNotification,
                                               object: nil)
        updateSpeakerSwitch()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let labelHeight: CGFloat = ceil(CallMemberCell.labelFont.lineHeight)
        if call is PeerCall {
            let itemSize = CGSize(width: CallMemberCell.Layout.bigger.avatarWrapperWidth,
                                  height: CallMemberCell.Layout.bigger.avatarWrapperWidth + labelHeight + CallMemberCell.Layout.bigger.labelTopMargin)
            membersCollectionLayout.itemSize = itemSize
            membersCollectionLayout.minimumLineSpacing = 0
            let horizontalInset = floor((view.bounds.width - itemSize.width) / 2)
            membersCollectionLayout.sectionInset = UIEdgeInsets(top: 88, left: horizontalInset, bottom: 0, right: horizontalInset)
        } else {
            var horizontalInset = view.bounds.width - numberOfGroupCallMembersPerRow * CallMemberCell.Layout.normal.avatarWrapperWidth
            horizontalInset /= 2 + 2 * numberOfGroupCallMembersPerRow
            horizontalInset = floor(horizontalInset)
            let verticalInset = round(horizontalInset * 2)
            let itemSize = CGSize(width: CallMemberCell.Layout.normal.avatarWrapperWidth + horizontalInset * 2,
                                  height: CallMemberCell.Layout.normal.avatarWrapperWidth + labelHeight + CallMemberCell.Layout.normal.labelTopMargin)
            membersCollectionLayout.itemSize = itemSize
            membersCollectionLayout.minimumLineSpacing = 16
            membersCollectionLayout.sectionInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
        }
        updateCollectionViewBottomInset()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        trayContentViewBottomConstraint.constant = calculatedTrayContentViewBottomMargin
        view.layoutIfNeeded()
    }
    
    override func viewWillResize() {
        let height = calculatedCollectionViewHeight(size: .expanded)
        collectionViewHeightConstraint.constant = round(height)
        UIView.performWithoutAnimation(view.layoutIfNeeded)
    }
    
    override func viewDidResize(to size: Size) {
        if collectionViewHeightConstraint.constant != membersWrapperView.bounds.height {
            collectionViewHeightConstraint.constant = membersWrapperView.bounds.height
        }
    }
    
    override func preferredContentHeight(forSize size: Size) -> CGFloat {
        let window = AppDelegate.current.mainWindow
        let maxHeight = window.bounds.height - window.safeAreaInsets.top
        switch size {
        case .expanded, .unavailable:
            return maxHeight
        case .compressed:
            switch ScreenHeight.current {
            case .short, .medium:
                return round(maxHeight * 0.8) + 14
            case .long, .extraLong:
                return round(maxHeight * 0.6) + 14
            }
        }
    }
    
    override func updatePreferredContentSizeHeight(size: Size) {
        contentViewHeightConstraint.constant = preferredContentHeight(forSize: size)
        updateMembersCountPosition()
        view.layoutIfNeeded()
    }
    
    func showContentViewIfNeeded(animated: Bool) {
        guard !isShowingContentView else {
            return
        }
        AppDelegate.current.mainWindow.endEditing(true)
        isShowingContentView = true
        hideContentViewConstraint.priority = .defaultLow
        showContentViewConstraint.priority = .defaultHigh
        let layout = {
            self.view.layoutIfNeeded()
            self.view.backgroundColor = .black.withAlphaComponent(0.4)
        }
        if animated {
            UIView.animate(withDuration: 0.5) {
                UIView.setAnimationCurve(.overdamped)
                layout()
            }
        } else {
            layout()
        }
        if let call = self.call as? GroupCall {
            call.beginSpeakingStatusPolling()
        }
    }
    
    func hideContentView(completion: (() -> Void)?) {
        isShowingContentView = false
        hideContentViewConstraint.priority = .defaultHigh
        showContentViewConstraint.priority = .defaultLow
        UIView.animate(withDuration: 0.5) {
            UIView.setAnimationCurve(.overdamped)
            self.view.layoutIfNeeded()
            self.view.backgroundColor = .black.withAlphaComponent(0)
        } completion: { _ in
            if let call = self.call as? GroupCall {
                call.endSpeakingStatusPolling()
            }
            completion?()
        }
    }
    
    func disableConnectionDurationTimer() {
        setConnectionDurationTimerEnabled(false)
    }
    
    func reload(call: Call?) {
        let notificationCenter = NotificationCenter.default
        if let call = self.call {
            notificationCenter.removeObserver(self, name: Call.mutenessDidChangeNotification, object: call)
            notificationCenter.removeObserver(self, name: Call.stateDidChangeNotification, object: call)
            if let call = call as? GroupCall {
                notificationCenter.removeObserver(self, name: GroupCallMembersDataSource.membersCountDidChangeNotification, object: call.membersDataSource)
            }
        }
        self.call = call
        
        guard let call = call else {
            return
        }
        notificationCenter.addObserver(self,
                                       selector: #selector(callMutenessDidChange),
                                       name: Call.mutenessDidChangeNotification,
                                       object: call)
        notificationCenter.addObserver(self,
                                       selector: #selector(callStateDidChange(_:)),
                                       name: Call.stateDidChangeNotification,
                                       object: call)
        if let call = call as? PeerCall {
            titleLabel.text = R.string.localizable.chat_menu_call()
            if let user = call.remoteUser {
                members = [user]
            } else {
                let item = UserItem.createUser(userId: call.remoteUserId, fullName: call.remoteUsername, identityNumber: "", avatarUrl: "", appId: nil)
                members = [item]
            }
            membersCollectionView.reloadData()
        } else if let call = call as? GroupCall {
            notificationCenter.addObserver(self,
                                           selector: #selector(updateMembersCountLabel),
                                           name: GroupCallMembersDataSource.membersCountDidChangeNotification,
                                           object: call.membersDataSource)
            titleLabel.text = call.conversationName
            membersCollectionView.isHidden = false
            call.membersDataSource.collectionView = membersCollectionView
            view.layoutIfNeeded()
            call.beginSpeakingStatusPolling()
        }
        updateMembersCountLabel()
        updateViews(call: call)
        muteSwitch.isSelected = call.isMuted
    }
    
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
    
    func learnMoreAboutEncryption() {
        guard let container = UIApplication.currentActivity() else {
            return
        }
        self.minimize {
            MixinWebViewController.presentInstance(with: .init(conversationId: "", initialUrl: .aboutEncryption), asChildOf: container)
        }
    }
    
    @IBAction func minimizeAction(_ sender: Any) {
        minimize(completion: nil)
    }
    
    @IBAction func addMemberAction(_ sender: Any) {
        
    }
    
    @IBAction func showEncryptionHintAction(_ sender: Any) {
        let alert = UIAlertController(title: R.string.localizable.call_encryption_title(),
                                      message: R.string.localizable.call_encryption_description(),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.action_learn_more(), style: .default, handler: { (_) in
            self.learnMoreAboutEncryption()
        }))
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func hangUpAction(_ sender: Any) {
        guard let call = call else {
            return
        }
        updateViews(call: call) // Signaling may take a while, update views first
        service.requestEndCall(with: call.uuid)
    }
    
    @IBAction func acceptAction(_ sender: Any) {
        guard let call = call else {
            return
        }
        service.requestAnswerCall(with: call.uuid)
    }
    
    @IBAction func setMuteAction(_ sender: Any) {
        guard let call = call else {
            return
        }
        muteSwitch.isSelected.toggle()
        let isMuted = muteSwitch.isSelected
        service.requestSetMute(with: call.uuid, muted: isMuted) { error in
            guard let error = error else {
                return
            }
            self.muteSwitch.isSelected = !isMuted
            Logger.call.error(category: "CallViewController", message: "Failed to set mute: \(error)")
        }
    }
    
    @IBAction func setSpeakerAction(_ sender: Any) {
        speakerSwitch.isSelected.toggle()
        if speakerSwitch.isSelected {
            service.setAudioOutput(.builtInSpeaker)
        } else {
            service.setAudioOutput(.builtInReceiver)
        }
    }
    
}

extension CallViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        members.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.call_member, for: indexPath)!
        let member = members[indexPath.row]
        if let call = call {
            cell.hasBiggerLayout = call is PeerCall
        }
        cell.avatarImageView.setImage(with: member)
        cell.connectingView.isHidden = true
        cell.label.text = member.fullName
        return cell
    }
    
}

extension CallViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView)  {
        updateMembersCountPosition()
    }
    
}

extension CallViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let call = call as? PeerCall {
            guard let user = call.remoteUser else {
                return
            }
            minimize {
                let profile = UserProfileViewController(user: user)
                UIApplication.homeContainerViewController?.present(profile, animated: true, completion: nil)
            }
        } else if let call = call as? GroupCall {
            if indexPath.item == 0 {
                if call.membersDataSource.members.count < GroupCall.maxNumberOfMembers {
                    let picker = GroupCallMemberPickerViewController(conversation: call.conversation)
                    picker.appearance = .appendToExistedCall
                    picker.fixedSelections = call.membersDataSource.members.map(\.item)
                    picker.onConfirmation = { members in
                        let inCallUserIds = call.membersDataSource.members.map(\.item.userId)
                        let filteredMembers = members.filter { (member) -> Bool in
                            !inCallUserIds.contains(member.userId)
                        }
                        if !filteredMembers.isEmpty {
                            call.invite(members: filteredMembers)
                        }
                    }
                    present(picker, animated: true, completion: nil)
                } else {
                    let message = R.string.localizable.group_call_selections_reach_limit("\(GroupCall.maxNumberOfMembers)")
                    alert(message)
                }
            } else if let member = call.membersDataSource.member(at: indexPath) {
                minimize {
                    let profile = UserProfileViewController(user: member.item)
                    UIApplication.homeContainerViewController?.present(profile, animated: true, completion: nil)
                }
            }
        }
    }
    
}

extension CallViewController {
    
    @objc func updateMembersCountLabel() {
        if let call = call as? GroupCall {
            membersCountLabel.text = R.string.localizable.group_call_participants_count(call.membersDataSource.members.count)
        } else {
            membersCountLabel.text = ""
        }
        updateMembersCountPosition()
        updateCollectionViewBottomInset()
    }
    
    @objc private func callMutenessDidChange() {
        guard let call = call else {
            return
        }
        muteSwitch.isSelected = call.isMuted
    }
    
    @objc private func updateSpeakerSwitch() {
        switch service.audioOutput {
        case .builtInReceiver:
            speakerSwitch.isSelected = false
            speakerSwitch.isEnabled = true
        case .builtInSpeaker:
            speakerSwitch.isSelected = true
            speakerSwitch.isEnabled = true
        case .other:
            speakerSwitch.isEnabled = false
        }
    }
    
    @objc private func callStateDidChange(_ notification: Notification) {
        guard let call = (notification.object as? Call), call == self.call else {
            return
        }
        updateViews(call: call)
        if let call = call as? GroupCall {
            if call.state == .connected {
                call.beginSpeakingStatusPolling()
            } else {
                call.endSpeakingStatusPolling()
            }
        }
    }
    
}

extension CallViewController {
    
    private var calculatedTrayContentViewBottomMargin: CGFloat {
        max(20, view.safeAreaInsets.bottom + 8)
    }
    
    private var calculatedMembersHeight: CGFloat {
        let numberOfItems = membersCollectionView.dataSource?.collectionView(membersCollectionView, numberOfItemsInSection: 0) ?? 0
        let numberOfLines = ceil(CGFloat(numberOfItems) / numberOfGroupCallMembersPerRow)
        return numberOfLines * membersCollectionLayout.itemSize.height
            + max(0, numberOfLines - 1) * membersCollectionLayout.minimumLineSpacing
            + membersCollectionLayout.sectionInset.vertical
    }
    
    private func calculatedCollectionViewHeight(size: Size) -> CGFloat {
        preferredContentHeight(forSize: size)
            - settingsButton.frame.maxY
            - trayContentViewHeightConstraint.constant
            - calculatedTrayContentViewBottomMargin
    }
    
    private func setConnectionDurationTimerEnabled(_ enabled: Bool) {
        timer?.invalidate()
        if enabled {
            let timer = Timer(timeInterval: 1, repeats: true) { (_) in
                guard let call = self.call else {
                    return
                }
                self.updateStatusLabel(call: call)
            }
            RunLoop.main.add(timer, forMode: .default)
            self.timer = timer
        }
    }
    
    private func minimize(completion: (() -> Void)?) {
        let needsAuthentication = !ScreenLockManager.shared.isLastAuthenticationStillValid
            && ScreenLockManager.shared.needsBiometricAuthentication
            && !service.isInterfaceMinimized
        if needsAuthentication {
            ScreenLockManager.shared.performBiometricAuthentication { success in
                if success {
                    self.service.setInterfaceMinimized(true, animated: true, completion: completion)
                }
            }
        } else {
            service.setInterfaceMinimized(true, animated: true, completion: completion)
        }
    }
    
    private func updateStatusLabel(call: Call) {
        statusLabel.text = call.localizedState
        trayView.layoutIfNeeded()
    }
    
    private func updateViews(call: Call) {
        updateStatusLabel(call: call)
        let animationDuration: TimeInterval = 0.3
        switch call.state {
        case .incoming:
            minimizeButton.isHidden = true
            setFunctionSwitchesHidden(true)
            setAcceptButtonHidden(false)
            setConnectionButtonsEnabled(true)
        case .outgoing:
            minimizeButton.isHidden = false
            setFunctionSwitchesHidden(false)
            setAcceptButtonHidden(true)
            setConnectionButtonsEnabled(true)
        case .connecting:
            minimizeButton.isHidden = false
            UIView.animate(withDuration: animationDuration) {
                self.setFunctionSwitchesHidden(false)
                self.setAcceptButtonHidden(true)
                self.setConnectionButtonsEnabled(true)
                self.view.layoutIfNeeded()
            }
        case .connected:
            minimizeButton.isHidden = false
            UIView.animate(withDuration: animationDuration) {
                self.setAcceptButtonHidden(true)
                self.setFunctionSwitchesHidden(false)
                self.setConnectionButtonsEnabled(true)
                self.view.layoutIfNeeded()
            }
            setConnectionDurationTimerEnabled(true)
        case .restarting:
            break
        case .disconnecting:
            minimizeButton.isHidden = true
            setAcceptButtonHidden(true)
            setConnectionButtonsEnabled(false)
            setConnectionDurationTimerEnabled(false)
        }
    }
    
    private func updateMembersCountPosition() {
        var margin = calculatedCollectionViewHeight(size: size)
            - calculatedMembersHeight
            + membersCollectionView.contentOffset.y
        margin = min(membersCountBottomMargin, margin)
        membersCountBottomConstraint.constant = margin
    }
    
    private func updateCollectionViewBottomInset() {
        let membersCountHeight = membersCountBottomMargin + ceil(membersCountFont.lineHeight)
        if call is GroupCall, membersWrapperView.bounds.height - calculatedMembersHeight < membersCountHeight {
            membersCollectionView.contentInset.bottom = membersCountHeight
        } else {
            membersCollectionView.contentInset.bottom = 0
        }
    }
    
}
