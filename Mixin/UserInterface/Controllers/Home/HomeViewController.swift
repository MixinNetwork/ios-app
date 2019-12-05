import UIKit
import AVFoundation
import StoreKit
import UserNotifications
import WCDBSwift

class HomeViewController: UIViewController {
    
    static var hasTriedToRequestReview = false
    static var showChangePhoneNumberTips = false
    
    @IBOutlet weak var navigationBarView: UIView!
    @IBOutlet weak var searchContainerView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var guideView: UIView!
    @IBOutlet weak var cameraButtonWrapperView: UIView!
    @IBOutlet weak var qrcodeImageView: UIImageView!
    @IBOutlet weak var connectingView: ActivityIndicatorView!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var showCameraButtonConstraint: NSLayoutConstraint!
    @IBOutlet weak var hideCameraButtonConstraint: NSLayoutConstraint!
    @IBOutlet weak var cameraWrapperSafeAreaPlaceholderHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchContainerTopConstraint: NSLayoutConstraint!
    
    private let dragDownThreshold: CGFloat = 80
    private let dragDownIndicator = DragDownIndicator()
    private let feedback = UISelectionFeedbackGenerator()
    private let messageCountPerPage = 30

    private var conversations = [ConversationItem]()
    private var needRefresh = true
    private var refreshing = false
    private var beginDraggingOffset: CGFloat = 0
    private var searchViewController: SearchViewController!
    private var searchContainerBeginTopConstant: CGFloat!
    private var loadMoreMessageThreshold = 10
    
    private lazy var deleteAction = UITableViewRowAction(style: .destructive, title: Localized.MENU_DELETE, handler: tableViewCommitDeleteAction)
    private lazy var pinAction: UITableViewRowAction = {
        let action = UITableViewRowAction(style: .normal, title: Localized.HOME_CELL_ACTION_PIN, handler: tableViewCommitPinAction)
        action.backgroundColor = .theme
        return action
    }()
    private lazy var unpinAction: UITableViewRowAction = {
        let action = UITableViewRowAction(style: .normal, title: Localized.HOME_CELL_ACTION_UNPIN, handler: tableViewCommitPinAction)
        action.backgroundColor = .theme
        return action
    }()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let vc = (segue.destination as? UINavigationController)?.viewControllers.first as? SearchViewController {
            searchViewController = vc
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateCameraWrapperHeight()
        searchContainerBeginTopConstant = searchContainerTopConstraint.constant
        searchViewController.cancelButton.addTarget(self, action: #selector(hideSearch), for: .touchUpInside)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.tableFooterView = UIView()
        dragDownIndicator.bounds.size = CGSize(width: 40, height: 40)
        dragDownIndicator.center = CGPoint(x: tableView.frame.width / 2, y: -40)
        tableView.addSubview(dragDownIndicator)
        view.layoutIfNeeded()
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange(_:)), name: .ConversationDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange(_:)), name: .UserDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(webSocketDidConnect(_:)), name: WebSocketService.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(webSocketDidDisconnect(_:)), name: WebSocketService.didDisconnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(syncStatusChange), name: .SyncMessageDidAppear, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UNUserNotificationCenter.current().checkNotificationSettings { (authorizationStatus: UNAuthorizationStatus) in
                switch authorizationStatus {
                case .authorized, .notDetermined, .provisional:
                    UNUserNotificationCenter.current().registerForRemoteNotifications()
                case .denied:
                    break
                @unknown default:
                    break
                }
            }
        }
        ConcurrentJobQueue.shared.addJob(job: RefreshAccountJob())
        ConcurrentJobQueue.shared.addJob(job: RefreshStickerJob())
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        qrcodeImageView.isHidden = CommonUserDefault.shared.hasPerformedQRCodeScanning
        if needRefresh {
            fetchConversations()
        }
        showCameraButton()
        checkServerStatus()
    }

    private func checkServerStatus() {
        guard AccountAPI.shared.didLogin else {
            return
        }
        guard !WebSocketService.shared.isConnected else {
            return
        }
        AccountAPI.shared.me { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            if case let .failure(error) = result, error.code == 10006 {
                weakSelf.alert(Localized.TOAST_UPDATE_TIPS)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if RELEASE
        requestAppStoreReviewIfNeeded()
        #endif
        if HomeViewController.showChangePhoneNumberTips {
            HomeViewController.showChangePhoneNumberTips = false
            let alert = UIAlertController(title: R.string.localizable.emergency_change_number_tip(), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: R.string.localizable.action_later(), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_change(), style: .default, handler: { (_) in
                let vc = VerifyPinNavigationController(rootViewController: ChangeNumberVerifyPinViewController())
                self.present(vc, animated: true, completion: nil)
            }))
            present(alert, animated: true, completion: nil)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        dragDownIndicator.center.x = tableView.frame.width / 2
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCameraWrapperHeight()
    }
    
    @IBAction func cameraAction(_ sender: Any) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            navigationController?.pushViewController(CameraViewController.instance(), animated: true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak self](granted) in
                guard granted else {
                    return
                }
                DispatchQueue.main.async {
                    self?.navigationController?.pushViewController(CameraViewController.instance(), animated: true)
                }
            })
        case .denied, .restricted:
            alertSettings(Localized.PERMISSION_DENIED_CAMERA)
        @unknown default:
            alertSettings(Localized.PERMISSION_DENIED_CAMERA)
        }
    }
    
    @IBAction func walletAction(_ sender: Any) {
        guard let account = AccountAPI.shared.account else {
            return
        }
        if account.has_pin {
            if Date().timeIntervalSince1970 - WalletUserDefault.shared.lastInputPinTime > WalletUserDefault.shared.checkPinInterval {
                let validator = PinValidationViewController(onSuccess: { [weak self](_) in
                    self?.navigationController?.pushViewController(WalletViewController.instance(), animated: false)
                })
                present(validator, animated: true, completion: nil)
            } else {
                WalletUserDefault.shared.initPinInterval()
                navigationController?.pushViewController(WalletViewController.instance(), animated: true)
            }
        } else {
            navigationController?.pushViewController(WalletPasswordViewController.instance(walletPasswordType: .initPinStep1, dismissTarget: .wallet), animated: true)
        }
    }
    
    @IBAction func showSearchAction() {
        searchViewController.prepareForReuse()
        searchContainerTopConstraint.constant = 0
        UIView.animate(withDuration: 0.2, animations: {
            self.navigationBarView.alpha = 0
            self.searchContainerView.alpha = 1
            self.view.layoutIfNeeded()
        }) { (_) in
            self.searchViewController.searchTextField.becomeFirstResponder()
        }
    }
    
    @IBAction func contactsAction(_ sender: Any) {
        navigationController?.pushViewController(ContactViewController.instance(), animated: true)
    }
    
    @objc func applicationDidBecomeActive(_ sender: Notification) {
        guard needRefresh else {
            return
        }
        fetchConversations()
    }
    
    @objc func dataDidChange(_ sender: Notification) {
        guard view?.isVisibleInScreen ?? false else {
            needRefresh = true
            return
        }
        guard !refreshing else {
            needRefresh = true
            return
        }
        fetchConversations()
    }
    
    @objc func webSocketDidConnect(_ notification: Notification) {
        connectingView.stopAnimating()
        titleLabel.text = "Mixin"
    }
    
    @objc func webSocketDidDisconnect(_ notification: Notification) {
        connectingView.startAnimating()
        titleLabel.text = R.string.localizable.dialog_progress_connect()
    }
    
    @objc func syncStatusChange(_ notification: Notification) {
        guard WebSocketService.shared.isConnected, view?.isVisibleInScreen ?? false else {
            return
        }
        guard let progress = notification.object as? Int else {
            return
        }
        if progress >= 100 {
            titleLabel.text = "Mixin"
            connectingView.stopAnimating()
        } else {
            titleLabel.text = Localized.CONNECTION_HINT_PROGRESS(progress)
            connectingView.startAnimating()
        }
    }
    
    @objc func hideSearch() {
        searchViewController.willHide()
        searchContainerTopConstraint.constant = searchContainerBeginTopConstant
        UIView.animate(withDuration: 0.2) {
            self.navigationBarView.alpha = 1
            self.searchContainerView.alpha = 0
            self.view.layoutIfNeeded()
        }
        view.endEditing(true)
    }
    
}

extension HomeViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.conversation, for: indexPath)!
        cell.render(item: conversations[indexPath.row])
        return cell
    }
    
}

extension HomeViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let conversation = conversations[indexPath.row]
        if conversation.status == ConversationStatus.START.rawValue {
            let job = RefreshConversationJob(conversationId: conversation.conversationId)
            ConcurrentJobQueue.shared.addJob(job: job)
        } else {
            conversation.unseenMessageCount = 0
            let vc = ConversationViewController.instance(conversation: conversations[indexPath.row])
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let conversation = conversations[indexPath.row]
        if conversation.pinTime == nil {
            return [deleteAction, pinAction]
        } else {
            return [deleteAction, unpinAction]
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard conversations.count >= messageCountPerPage else {
            return
        }
        guard indexPath.row > conversations.count - loadMoreMessageThreshold else {
            return
        }
        guard !refreshing else {
            needRefresh = true
            return
        }

        fetchConversations()
    }
    
}

extension HomeViewController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        beginDraggingOffset = scrollView.contentOffset.y
        feedback.prepare()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if abs(scrollView.contentOffset.y - beginDraggingOffset) > 10 {
            if scrollView.contentOffset.y > beginDraggingOffset {
                hideCameraButton()
            } else {
                showCameraButton()
            }
        }
        if scrollView.contentOffset.y <= -dragDownThreshold && !dragDownIndicator.isHighlighted {
            dragDownIndicator.isHighlighted = true
            feedback.selectionChanged()
        } else if scrollView.contentOffset.y > -dragDownThreshold && dragDownIndicator.isHighlighted {
            dragDownIndicator.isHighlighted = false
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if tableView.contentOffset.y <= -dragDownThreshold {
            showSearchAction()
        } else {
            hideSearch()
        }
    }
    
}

extension HomeViewController {
    
    private func updateCameraWrapperHeight() {
        cameraWrapperSafeAreaPlaceholderHeightConstraint.constant = view.safeAreaInsets.bottom
        cameraButtonWrapperView.layoutIfNeeded()
    }
    
    private func fetchConversations() {
        refreshing = true
        needRefresh = false

        DispatchQueue.main.async {
            let limit = (self.tableView.indexPathsForVisibleRows?.first?.row ?? 0) + self.messageCountPerPage

            DispatchQueue.global().async { [weak self] in
                let conversations = ConversationDAO.shared.conversationList(limit: limit)
                let groupIcons = conversations.filter({ $0.isNeedCachedGroupIcon() })
                for conversation in groupIcons {
                    ConcurrentJobQueue.shared.addJob(job: RefreshGroupIconJob(conversationId: conversation.conversationId))
                }
                DispatchQueue.main.async {
                    guard self?.tableView != nil else {
                        return
                    }
                    self?.guideView.isHidden = conversations.count != 0
                    self?.conversations = conversations
                    self?.tableView.reloadData()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.33, execute: {
                        self?.refreshing = false
                        if self?.needRefresh ?? false {
                            self?.fetchConversations()
                        }
                    })
                }
            }
        }
    }
    
    private func tableViewCommitPinAction(action: UITableViewRowAction, indexPath: IndexPath) {
        let conversation = conversations[indexPath.row]
        let destinationIndex: Int
        if conversation.pinTime == nil {
            let pinTime = Date().toUTCString()
            conversation.pinTime = pinTime
            ConversationDAO.shared.updateConversationPinTime(conversationId: conversation.conversationId, pinTime: pinTime)
            conversations.remove(at: indexPath.row)
            destinationIndex = 0
        } else {
            conversation.pinTime = nil
            ConversationDAO.shared.updateConversationPinTime(conversationId: conversation.conversationId, pinTime: nil)
            conversations.remove(at: indexPath.row)
            destinationIndex = conversations.firstIndex(where: { $0.pinTime == nil && $0.createdAt < conversation.createdAt }) ?? conversations.count
        }
        conversations.insert(conversation, at: destinationIndex)
        let destinationIndexPath = IndexPath(row: destinationIndex, section: 0)
        tableView.moveRow(at: indexPath, to: destinationIndexPath)
        if let cell = tableView.cellForRow(at: destinationIndexPath) as? ConversationCell {
            cell.render(item: conversation)
        }
        tableView.setEditing(false, animated: true)
    }
    
    private func tableViewCommitDeleteAction(action: UITableViewRowAction, indexPath: IndexPath) {
        let conversation = conversations[indexPath.row]
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        if conversation.category == ConversationCategory.CONTACT.rawValue {
            alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_DELETE, style: .destructive, handler: { [weak self](action) in
                self?.deleteAction(indexPath: indexPath)
            }))
        } else {
            alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_CLEAR, style: .default, handler: { [weak self](action) in
                self?.clearChatAction(indexPath: indexPath)
            }))
        }
        if conversation.category == ConversationCategory.GROUP.rawValue {
            alc.addAction(UIAlertAction(title: Localized.GROUP_MENU_EXIT, style: .destructive, handler: { [weak self](action) in
                self?.deleteAndExitAction(indexPath: indexPath)
            }))
        }
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
        tableView.setEditing(false, animated: true)
    }
    
    private func clearChatAction(indexPath: IndexPath) {
        let conversation = conversations[indexPath.row]
        tableView.beginUpdates()
        conversations[indexPath.row].contentType = MessageCategory.UNKNOWN.rawValue
        conversations[indexPath.row].unseenMessageCount = 0
        tableView.reloadRows(at: [indexPath], with: .automatic)
        tableView.endUpdates()
        DispatchQueue.global().async {
            MessageDAO.shared.clearChat(conversationId: conversation.conversationId, autoNotification: false)
            MixinFile.cleanAllChatDirectories()
            NotificationCenter.default.postOnMain(name: .StorageUsageDidChange)
        }
    }
    
    private func deleteAction(indexPath: IndexPath) {
        tableView.beginUpdates()
        let conversation = conversations.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .fade)
        tableView.endUpdates()
        DispatchQueue.global().async {
            ConversationDAO.shared.deleteConversationAndMessages(conversationId: conversation.conversationId)
            MixinFile.cleanAllChatDirectories()
        }
    }
    
    private func deleteAndExitAction(indexPath: IndexPath) {
        let conversation = conversations[indexPath.row]
        tableView.beginUpdates()
        conversations.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .fade)
        tableView.endUpdates()
        DispatchQueue.global().async {
            ConversationDAO.shared.makeQuitConversation(conversationId: conversation.conversationId)
        }
    }
    
    private func hideCameraButton() {
        guard cameraButtonWrapperView.alpha != 0 else {
            return
        }
        UIView.animate(withDuration: 0.25, delay: 0, options: [.showHideTransitionViews, .beginFromCurrentState], animations: {
            self.cameraButtonWrapperView.alpha = 0
            self.hideCameraButtonConstraint.priority = .defaultHigh
            self.showCameraButtonConstraint.priority = .defaultLow
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    private func showCameraButton() {
        guard cameraButtonWrapperView.alpha != 1 else {
            return
        }
        UIView.animate(withDuration: 0.25, delay: 0, options: [.showHideTransitionViews, .beginFromCurrentState], animations: {
            self.cameraButtonWrapperView.alpha = 1
            self.hideCameraButtonConstraint.priority = .defaultLow
            self.showCameraButtonConstraint.priority = .defaultHigh
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    private func requestAppStoreReviewIfNeeded() {
        let sevenDays: Double = 7 * 24 * 60 * 60
        let shouldRequestReview = !HomeViewController.hasTriedToRequestReview
            && CommonUserDefault.shared.hasPerformedTransfer
            && Date().timeIntervalSince1970 - CommonUserDefault.shared.firstLaunchTimeIntervalSince1970 > sevenDays
        if shouldRequestReview {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                SKStoreReviewController.requestReview()
            })
        }
        HomeViewController.hasTriedToRequestReview = true
    }
    
}
