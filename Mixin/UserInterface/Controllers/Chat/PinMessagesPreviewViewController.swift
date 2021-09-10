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
    private var isPresented = false
    private var isInitialCellFlashingCompleted = false
    private var ignoresPinMessageChangeNotification = false
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        factory.delegate = self
        reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(pinMessagesDidChange(_:)), name: PinMessageDAO.pinMessageDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(participantDidChange(_:)), name: ParticipantDAO.participantDidChangeNotification, object: nil)
    }
    
    override func viewDidPresentAsChild() {
        isPresented = true
        flashCellBackgroundIfNeeded()
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
            showMessageButton.addTarget(self, action: #selector(showMessageAction(_:)), for: .touchUpInside)
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
        guard let viewModel = self.viewModel(at: indexPath) else {
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
            guard PinMessageDAO.shared.hasMessages(conversationId: conversationId) else {
                DispatchQueue.main.async {
                    self.dismissAsChild(completion: nil)
                }
                return
            }
            let pinnedMessageItems = PinMessageDAO.shared.messageItems(conversationId: conversationId)
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
        let conversationId = self.conversationId
        queue.async {
            let pinnedMessageItems = PinMessageDAO.shared.messageItems(conversationId: conversationId)
            let (dates, viewModels) = self.categorizedViewModels(with: pinnedMessageItems, fits: self.layoutWidth)
            DispatchQueue.main.async {
                self.pinnedMessageItems = pinnedMessageItems
                self.titleLabel.text = R.string.localizable.chat_pinned_messages_count(self.pinnedMessageItems.count)
                self.dates = dates
                self.viewModels = viewModels
                self.tableView.reloadData()
                self.flashCellBackgroundIfNeeded()
            }
            self.updateUnpinAllButtonVisibility()
        }
    }
    
    private func flashCellBackgroundIfNeeded() {
        guard isPresented && !isInitialCellFlashingCompleted && !pinnedMessageItems.isEmpty else {
            return
        }
        isInitialCellFlashingCompleted = true
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
    
    private func updateUnpinAllButtonVisibility() {
        let canUnpinMessages = !isGroup || ParticipantDAO.shared.isAdmin(conversationId: conversationId, userId: myUserId)
        DispatchQueue.main.async {
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
    
}
