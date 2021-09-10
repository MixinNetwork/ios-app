import UIKit
import MixinServices

protocol PinMessagesPreviewViewControllerDelegate: AnyObject {
    func pinMessagesPreviewViewController(_ controller: PinMessagesPreviewViewController, needsShowMessage messageId: String)
}

final class PinMessagesPreviewViewController: StaticMessagesViewController {
    
    weak var delegate: PinMessagesPreviewViewControllerDelegate?
    
    private let isGroup: Bool
    private let conversationId: String
    private let bottomBarViewHeight: CGFloat = 50
    private let processDispatchQueue = DispatchQueue(label: "one.mixin.messenger.PinMessagesPreviewViewController")
    private let layoutWidth = AppDelegate.current.mainWindow.bounds.width
    
    private var showMessageButtons: [MessageCell: UIButton] = [:]
    private var pinnedMessageItems: [MessageItem] = []
    private var isCellFlashed = false
    private var isPresented = false
    private var isUnpinAllMessages = false
    
    private weak var bottomBarViewIfLoaded: UIView?

    private lazy var bottomBarView: UIView = {
        let button = UIButton()
        button.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16), adjustForContentSize: true)
        button.setTitle(R.string.localizable.chat_unpin_all_messages(), for: .normal)
        button.setTitleColor(R.color.theme(), for: .normal)
        button.addTarget(self, action: #selector(unpinAllAction), for: .touchUpInside)
        let view = UIView()
        view.backgroundColor = R.color.background()
        view.addSubview(button)
        button.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(bottomBarViewHeight)
        }
        bottomBarViewIfLoaded = view
        return view
    }()
    
    init(conversationId: String, isGroup: Bool) {
        self.conversationId = conversationId
        self.isGroup = isGroup
        super.init(conversationId: conversationId, audioManager: StaticAudioMessagePlayingManager())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        factory.delegate = self
        presentCompletion = { [weak self] in
            guard let self = self else {
                return
            }
            self.isPresented = true
            self.flashCellBackgroundIfNeeded()
        }
        reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(pinMessagesDidChange(_:)), name: PinMessageDAO.pinMessageDidChangeNotification, object: nil)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        reloadData()
    }
    
}

// MARK: - Override
extension PinMessagesPreviewViewController {
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        guard let cell = cell as? MessageCell, let viewModel = viewModel(at: indexPath), viewModel.message.userId != myUserId else {
            return
        }
        let showMessageButton: UIButton
        if let button = showMessageButtons[cell] {
            showMessageButton = button
        } else {
            showMessageButton = UIButton()
            showMessageButton.addTarget(self, action: #selector(showMessageAction(sender:)), for: .touchUpInside)
            showMessageButton.setImage(R.image.ic_pin_right_arrow(), for: .normal)
            showMessageButtons[cell] = showMessageButton
        }
        cell.contentView.addSubview(showMessageButton)
        let size = CGSize(width: 36, height: 36)
        showMessageButton.snp.makeConstraints { make in
            make.size.equalTo(size)
            make.left.equalTo(cell.contentFrame.maxX)
            make.top.equalTo(cell.contentFrame.midY - size.height / 2)
        }
    }
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, didEndDisplaying: cell, forRowAt: indexPath)
        guard let cell = cell as? MessageCell, let button = showMessageButtons[cell] else {
            return
        }
        button.removeFromSuperview()
    }
    
}

// MARK: - MessageViewModelFactoryDelegate
extension PinMessagesPreviewViewController: MessageViewModelFactoryDelegate {
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, showUsernameForMessageIfNeeded message: MessageItem) -> Bool {
        message.userId != myUserId
    }
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, isMessageForwardedByBot message: MessageItem) -> Bool {
        false
    }
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, updateViewModelForPresentation viewModel: MessageViewModel) {
        
    }
    
}

// MARK: - Actions
extension PinMessagesPreviewViewController {
    
    @objc private func unpinAllAction() {
        let controller = UIAlertController(title: R.string.localizable.chat_alert_unpin_all_messages(), message: nil, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil)
        let unpinAction = UIAlertAction(title: R.string.localizable.menu_unpin(), style: .default) { _ in
            self.isUnpinAllMessages = true
            SendMessageService.shared.sendPinMessages(items: self.pinnedMessageItems, conversationId: self.conversationId, action: .unpin)
            self.dismissAsChild(completion: nil)
        }
        controller.addAction(cancelAction)
        controller.addAction(unpinAction)
        present(controller, animated: true, completion: nil)
    }
    
    @objc private func showMessageAction(sender: UIButton) {
        guard let cell = sender.superview?.superview as? MessageCell,
              let indexPath = tableView.indexPath(for: cell),
              let viewModel = viewModel(at: indexPath) else {
            return
        }
        delegate?.pinMessagesPreviewViewController(self, needsShowMessage: viewModel.message.messageId)
    }
    
    @objc func pinMessagesDidChange(_ notification: Notification) {
        guard !isUnpinAllMessages else {
            return
        }
        guard let conversationId = notification.userInfo?[PinMessageDAO.UserInfoKey.conversationId] as? String else {
            return
        }
        guard conversationId == self.conversationId else {
            return
        }
        processDispatchQueue.sync { [weak self] in
            guard let self = self else {
                return
            }
            guard PinMessageDAO.shared.hasMessages(conversationId: self.conversationId) else {
                DispatchQueue.main.async {
                    self.dismissAsChild(completion: nil)
                }
                return
            }
            self.pinnedMessageItems = PinMessageDAO.shared.messageItems(conversationId: self.conversationId)
            let (dates, viewModels) = self.categorizedViewModels(with: self.pinnedMessageItems, fits: self.layoutWidth)
            DispatchQueue.main.async {
                self.titleLabel.text = R.string.localizable.chat_pinned_messages_count(self.pinnedMessageItems.count)
                self.dates = dates
                self.viewModels = viewModels
                self.tableView.reloadData()
            }
        }
    }
    
}

// MARK: - Helper
extension PinMessagesPreviewViewController {
    
    private func reloadData() {
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.pinnedMessageItems = PinMessageDAO.shared.messageItems(conversationId: self.conversationId)
            let (dates, viewModels) = self.categorizedViewModels(with: self.pinnedMessageItems, fits: self.layoutWidth)
            let needsAddBottomBar = self.bottomBarViewIfLoaded == nil &&
                (!self.isGroup || ParticipantDAO.shared.isAdmin(conversationId: self.conversationId, userId: myUserId))
            DispatchQueue.main.async {
                if needsAddBottomBar {
                    let safeAreaInsets = AppDelegate.current.mainWindow.safeAreaInsets
                    self.view.addSubview(self.bottomBarView)
                    self.bottomBarView.snp.makeConstraints { make in
                        make.left.right.equalToSuperview()
                        make.height.equalTo(safeAreaInsets.bottom + self.bottomBarViewHeight)
                        make.bottom.equalTo(-safeAreaInsets.top)
                    }
                    self.tableViewBottomConstraint.constant += self.bottomBarViewHeight
                }
                self.titleLabel.text = R.string.localizable.chat_pinned_messages_count(self.pinnedMessageItems.count)
                self.dates = dates
                self.viewModels = viewModels
                self.tableView.reloadData()
                self.flashCellBackgroundIfNeeded()
            }
        }
    }
    
    private func flashCellBackgroundIfNeeded() {
        guard isPresented && !isCellFlashed && !pinnedMessageItems.isEmpty else {
            return
        }
        isCellFlashed = true
        let conversationId = self.conversationId
        queue.async { [weak self] in
            let messageId: String?
            if let id = AppGroupUserDefaults.User.visiblePinMessage(for: conversationId)?.pinnedMessageId {
                messageId = id
            } else if let lastPinnedMessage = PinMessageDAO.shared.lastPinnedMessage(conversationId: conversationId) {
                messageId = lastPinnedMessage.messageId
            } else {
                messageId = nil
            }
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                guard let messageId = messageId, let indexPath = self.indexPath(where: { $0.messageId == messageId }) else {
                    return
                }
                self.tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
                self.flashCellBackground(at: indexPath)
            }
        }
    }
    
}
