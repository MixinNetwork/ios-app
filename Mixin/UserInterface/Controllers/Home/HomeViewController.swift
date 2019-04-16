import UIKit
import AVFoundation
import StoreKit
import UserNotifications

class HomeViewController: UIViewController {

    static var hasTriedToRequestReview = false
    
    @IBOutlet weak var searchContainerView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var guideView: UIView!
    @IBOutlet weak var bottomNavView: UIView!
    @IBOutlet weak var cameraButton: BouncingButton!
    @IBOutlet weak var qrcodeImageView: UIImageView!
    @IBOutlet weak var connectingView: ActivityIndicatorView!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var bottomNavConstraint: NSLayoutConstraint!
    @IBOutlet weak var navigationBarContentTopConstraint: NSLayoutConstraint!
    
    private var conversations = [ConversationItem]()
    private var needRefresh = true
    private var refreshing = false
    private var currentOffset: CGFloat = 0
    
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
    private lazy var searchViewController: SearchViewController? = {
        let vc = SearchViewController.instance()
        addChild(vc)
        searchContainerView.addSubview(vc.view)
        vc.view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        searchContainerView.layoutIfNeeded()
        vc.didMove(toParent: self)
        vc.cancelButton.addTarget(self, action: #selector(dismissSearch(_:)), for: .touchUpInside)
        return vc
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 11.0, *) {
            navigationBarContentTopConstraint.constant = view.safeAreaInsets.top
        } else {
            navigationBarContentTopConstraint.constant = UIApplication.shared.statusBarFrame.height
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "ConversationCell", bundle: nil), forCellReuseIdentifier: ConversationCell.cellIdentifier)
        tableView.separatorStyle = .singleLine
        tableView.tableFooterView = UIView()
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange(_:)), name: .ConversationDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange(_:)), name: .UserDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(socketStatusChange), name: .SocketStatusChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(syncStatusChange), name: .SyncMessageDidAppear, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(statusBarFrameWillChange(_:)), name: UIApplication.willChangeStatusBarFrameNotification, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.searchViewController?.prepare()
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidBecomeActive(_:)),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UNUserNotificationCenter.current().checkNotificationSettings { (authorizationStatus: UNAuthorizationStatus) in
                switch authorizationStatus {
                case .authorized, .notDetermined, .provisional:
                    UNUserNotificationCenter.current().registerForRemoteNotifications()
                case .denied:
                    break
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        qrcodeImageView.isHidden = CommonUserDefault.shared.hasPerformedQRCodeScanning
        if needRefresh {
            fetchConversations()
        }
        showBottomNav()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if RELEASE
        requestAppStoreReviewIfNeeded()
        #endif
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        navigationBarContentTopConstraint.constant = view.safeAreaInsets.top
    }
    
    private func fetchConversations() {
        refreshing = true
        needRefresh = false
        DispatchQueue.global().async { [weak self] in
            let conversations = ConversationDAO.shared.conversationList()
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

    deinit {
        NotificationCenter.default.removeObserver(self)
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
        }
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
    
    @objc func dismissSearch(_ sender: Any) {
        searchViewController?.dismiss()
        UIView.animate(withDuration: 0.3) {
            self.searchContainerView.alpha = 0
        }
    }

    @objc func socketStatusChange(_ sender: Any) {
        if WebSocketService.shared.connected {
            connectingView.stopAnimating()
            titleLabel.text = "Mixin"
        } else {
            connectingView.startAnimating()
            titleLabel.text = R.string.localizable.dialog_progress_connect()
        }
    }

    @objc func syncStatusChange(_ notification: Notification) {
        guard WebSocketService.shared.connected, view?.isVisibleInScreen ?? false else {
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
    
    @objc func statusBarFrameWillChange(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIApplication.statusBarFrameUserInfoKey] as? CGRect else {
            return
        }
        if #available(iOS 11.0, *) {
            
        } else {
            navigationBarContentTopConstraint.constant = frame.height
        }
    }
    
    @IBAction func walletAction(_ sender: Any) {
        guard let account = AccountAPI.shared.account else {
            return
        }
        if account.has_pin {
            if Date().timeIntervalSince1970 - WalletUserDefault.shared.lastInputPinTime > WalletUserDefault.shared.checkPinInterval {
                let validator = PinValidationViewController.instance(onSuccess: { [weak self](_) in
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

    @IBAction func searchAction(_ sender: Any) {
        guard let searchViewController = searchViewController else {
            return
        }
        searchContainerView.alpha = 1
        searchViewController.present()
    }
    
    @IBAction func contactsAction(_ sender: Any) {
        navigationController?.pushViewController(ContactViewController.instance(), animated: true)
    }

    class func instance() -> HomeViewController {
        return Storyboard.home.instantiateViewController(withIdentifier: "home") as! HomeViewController
    }
    
}

extension HomeViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationCell.cellIdentifier) as! ConversationCell
        cell.render(item: conversations[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let conversation = conversations[indexPath.row]
        if conversation.status == ConversationStatus.START.rawValue {
            ConcurrentJobQueue.shared.addJob(job: RefreshConversationJob(conversationId: conversation.conversationId))
        } else {
            conversation.unseenMessageCount = 0
            navigationController?.pushViewController(ConversationViewController.instance(conversation: conversations[indexPath.row]), animated: true)
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
            destinationIndex = conversations.index(where: { $0.pinTime == nil && $0.createdAt < conversation.createdAt }) ?? conversations.count
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

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        currentOffset = scrollView.contentOffset.y
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard abs(scrollView.contentOffset.y - currentOffset) > 10 else {
            return
        }

        if scrollView.contentOffset.y > currentOffset {
            hideBottomNav()
        } else {
            showBottomNav()
        }
    }

    private func hideBottomNav() {
        guard bottomNavView.alpha != 0 else {
            return
        }
        UIView.animate(withDuration: 0.25, delay: 0, options: [.showHideTransitionViews, .beginFromCurrentState], animations: {
            self.bottomNavView.alpha = 0
            self.bottomNavConstraint.constant = -122
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    private func showBottomNav() {
        guard bottomNavView.alpha != 1 else {
            return
        }
        UIView.animate(withDuration: 0.25, delay: 0, options: [.showHideTransitionViews, .beginFromCurrentState], animations: {
            self.bottomNavView.alpha = 1
            self.bottomNavConstraint.constant = 0
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    private func requestAppStoreReviewIfNeeded() {
        guard #available(iOS 10.3, *) else {
            return
        }
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
