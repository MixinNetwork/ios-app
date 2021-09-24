import UIKit
import MixinServices

protocol PinMessagesPreviewViewControllerDelegate: AnyObject {
    func pinMessagesPreviewViewController(_ controller: PinMessagesPreviewViewController, needsShowMessage messageId: String)
}

final class PinMessagesPreviewViewController: StaticMessagesViewController {
    
    weak var delegate: PinMessagesPreviewViewControllerDelegate?
    
    private let isGroup: Bool
    private let conversationId: String
    private let unpinAllButtonHeight: CGFloat = 50
    private let additionalBottomInsetWhenUnpinAllIsAvailable: CGFloat = 20
    
    private var showMessageButtons: [MessageCell: UIButton] = [:]
    private var pinnedMessageItems: [MessageItem] = []
    private var ignoresPinMessageChangeNotification = false
    private var canUnpinMessages = false
    
    private var layoutWidth: CGFloat {
        Queue.main.autoSync {
            AppDelegate.current.mainWindow.bounds.width
        }
    }
    
    private weak var bottomBarViewIfAdded: UIView?
    
    init(conversationId: String, isGroup: Bool) {
        self.conversationId = conversationId
        self.isGroup = isGroup
        super.init(conversationId: conversationId, audioManager: StaticAudioMessagePlayingManager())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        super.canPerformAction(action, withSender: sender) || action == #selector(unpinSelectedMessage)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        factory.delegate = self
        reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(pinMessagesDidChange(_:)), name: PinMessageDAO.didSaveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pinMessagesDidChange(_:)), name: PinMessageDAO.didDeleteNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(participantDidChange(_:)), name: ParticipantDAO.participantDidChangeNotification, object: nil)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        reloadData()
    }
    
    override func menuItems(for viewModel: MessageViewModel) -> [UIMenuItem]? {
        guard canUnpinMessages else {
            return super.menuItems(for: viewModel)
        }
        var items = super.menuItems(for: viewModel) ?? []
        items.append(UIMenuItem(title: R.string.localizable.menu_unpin(), action: #selector(unpinSelectedMessage)))
        return items
    }
    
    @available(iOS 13.0, *)
    override func contextMenuActions(for viewModel: MessageViewModel) -> [UIAction]? {
        guard canUnpinMessages else {
            return super.contextMenuActions(for: viewModel)
        }
        var actions = super.contextMenuActions(for: viewModel) ?? []
        let unpinAction = UIAction(title: R.string.localizable.menu_unpin(), image: R.image.conversation.ic_action_unpin()) { (_) in
            SendMessageService.shared.sendPinMessages(items: [viewModel.message],
                                                      conversationId: self.conversationId,
                                                      action: .unpin)
        }
        actions.append(unpinAction)
        return actions
    }
    
}

// MARK: - Override
extension PinMessagesPreviewViewController {
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        guard let cell = cell as? MessageCell, let viewModel = viewModel(at: indexPath) else {
            return
        }
        let showMessageButton: UIButton
        if let button = showMessageButtons[cell] {
            showMessageButton = button
        } else {
            showMessageButton = UIButton()
            showMessageButton.setImage(R.image.ic_pin_right_arrow(), for: .normal)
            showMessageButton.addTarget(self, action: #selector(showMessageAction(_:)), for: .touchUpInside)
            showMessageButtons[cell] = showMessageButton
        }
        let isSentByMe = viewModel.message.userId == myUserId
        let size = CGSize(width: 36, height: 36)
        let origin = CGPoint(x: isSentByMe ? cell.contentFrame.minX - size.width : cell.contentFrame.maxX,
                             y: cell.contentFrame.midY - size.height / 2)
        showMessageButton.frame = CGRect(origin: origin, size: size)
        if isSentByMe {
            showMessageButton.transform = CGAffineTransform(rotationAngle: .pi)
        } else {
            showMessageButton.transform = .identity
        }
        cell.contentView.addSubview(showMessageButton)
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
    
    @objc private func unpinSelectedMessage() {
        guard let indexPath = tableView.indexPathForSelectedRow else {
            return
        }
        guard let message = viewModel(at: indexPath)?.message else {
            return
        }
        SendMessageService.shared.sendPinMessages(items: [message],
                                                  conversationId: conversationId,
                                                  action: .unpin)
    }
    
    @objc private func unpinAllAction() {
        let controller = UIAlertController(title: R.string.localizable.chat_alert_unpin_all_messages(), message: nil, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        controller.addAction(UIAlertAction(title: R.string.localizable.menu_unpin(), style: .default) { _ in
            self.ignoresPinMessageChangeNotification = true
            SendMessageService.shared.sendPinMessages(items: self.pinnedMessageItems, conversationId: self.conversationId, action: .unpin)
            self.dismissAsChild(completion: nil)
        })
        present(controller, animated: true, completion: nil)
    }
    
    @objc private func showMessageAction(_ sender: UIButton) {
        let location = tableView.convert(sender.center, from: sender.superview)
        guard let indexPath = tableView.indexPathForRow(at: location) else {
            return
        }
        guard let viewModel = viewModel(at: indexPath) else {
            return
        }
        delegate?.pinMessagesPreviewViewController(self, needsShowMessage: viewModel.message.messageId)
    }
    
    @objc private func pinMessagesDidChange(_ notification: Notification) {
        guard !ignoresPinMessageChangeNotification else {
            return
        }
        guard let conversationId = notification.userInfo?[PinMessageDAO.UserInfoKey.conversationId] as? String else {
            return
        }
        guard conversationId == self.conversationId else {
            return
        }
        queue.async {
            guard PinMessageDAO.shared.hasMessage(conversationId: conversationId) else {
                DispatchQueue.main.async {
                    self.dismissAsChild(completion: nil)
                }
                return
            }
            let pinnedMessageItems = self.messageItems()
            let (dates, viewModels) = self.categorizedViewModels(with: pinnedMessageItems, fits: self.layoutWidth)
            DispatchQueue.main.async {
                self.pinnedMessageItems = pinnedMessageItems
                self.titleLabel.text = R.string.localizable.chat_pinned_messages_count(pinnedMessageItems.count)
                self.dates = dates
                self.viewModels = viewModels
                self.tableView.reloadData()
            }
        }
    }
    
    @objc private func participantDidChange(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[ParticipantDAO.UserInfoKey.conversationId] as? String else {
            return
        }
        guard conversationId == self.conversationId else {
            return
        }
        queue.async {
            self.updateUnpinAllButtonVisibility()
        }
    }
    
}

// MARK: - Helper
extension PinMessagesPreviewViewController {
    
    private func addBottomBarViewIfNeverAdded() {
        guard bottomBarViewIfAdded == nil else {
            return
        }
        
        let button = UIButton()
        button.setTitle(R.string.localizable.chat_unpin_all_messages(), for: .normal)
        button.setTitleColor(R.color.theme(), for: .normal)
        button.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16), adjustForContentSize: true)
        button.addTarget(self, action: #selector(unpinAllAction), for: .touchUpInside)
        
        let bottomBarView = UIView()
        bottomBarView.backgroundColor = R.color.background()
        bottomBarView.addSubview(button)
        button.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(unpinAllButtonHeight)
            make.bottom.equalTo(bottomBarView.safeAreaLayoutGuide.snp.bottom)
        }
        
        contentView.addSubview(bottomBarView)
        bottomBarView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
        }
        bottomBarViewIfAdded = bottomBarView
    }
    
    private func reloadData() {
        queue.async {
            let pinnedMessageItems = self.messageItems()
            let (dates, viewModels) = self.categorizedViewModels(with: pinnedMessageItems, fits: self.layoutWidth)
            DispatchQueue.main.async {
                self.pinnedMessageItems = pinnedMessageItems
                self.titleLabel.text = R.string.localizable.chat_pinned_messages_count(self.pinnedMessageItems.count)
                self.dates = dates
                self.viewModels = viewModels
                self.tableView.reloadData()
            }
            self.updateUnpinAllButtonVisibility()
        }
    }
    
    private func updateUnpinAllButtonVisibility() {
        let canUnpinMessages = !isGroup || ParticipantDAO.shared.isAdmin(conversationId: conversationId, userId: myUserId)
        DispatchQueue.main.async {
            self.canUnpinMessages = canUnpinMessages
            if canUnpinMessages {
                self.addBottomBarViewIfNeverAdded()
                self.tableView.contentInset.bottom = self.unpinAllButtonHeight
                    + self.additionalBottomInsetWhenUnpinAllIsAvailable
            } else {
                self.bottomBarViewIfAdded?.removeFromSuperview()
                self.tableView.contentInset.bottom = 0
            }
        }
    }
    
    private func messageItems() -> [MessageItem] {
        let items = PinMessageDAO.shared.messageItems(conversationId: conversationId)
        items.forEach { $0.isPinned = false } // No need to display pin icon
        return items
    }
    
}
