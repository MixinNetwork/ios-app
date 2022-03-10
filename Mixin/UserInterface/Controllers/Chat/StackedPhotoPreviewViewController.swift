import UIKit
import MixinServices

class StackedPhotoPreviewViewController: StaticMessagesViewController {
    
    private let conversationId: String
    private let stackedPhotoMessage: MessageItem
    
    private var photoMessageItems: [MessageItem] = []
    private var selectedViewModels = [String: MessageViewModel]()
    private var pinnedMessageIds = Set<String>()
    
    private lazy var multipleSelectionView: MultipleSelectionActionView = {
        let view = R.nib.multipleSelectionActionView(owner: self)!
        view.delegate = self
        view.showCancelButton = true
        return view
    }()
    
    init(conversationId: String, stackedPhotoMessage: MessageItem) {
        self.conversationId = conversationId
        self.stackedPhotoMessage = stackedPhotoMessage
        let audioManager = TranscriptAudioMessagePlayingManager(transcriptId: stackedPhotoMessage.messageId)
        super.init(conversationId: conversationId, audioManager: audioManager)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let messages = stackedPhotoMessage.messageItems {
            photoMessageItems = messages
            titleLabel.text = R.string.localizable.chat_photo_preview_count(messages.count)
        }
        factory.delegate = self
        reloadData()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(pinMessageDidSave(_:)), name: PinMessageDAO.didSaveNotification, object: nil)
        center.addObserver(self, selector: #selector(pinMessageDidDelete(_:)), name: PinMessageDAO.didDeleteNotification, object: nil)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        reloadData()
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? MessageCell {
            CATransaction.performWithoutAnimation {
                cell.setMultipleSelecting(tableView.allowsMultipleSelection, animated: false)
                cell.layoutIfNeeded()
            }
        }
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
    }
    
    override func contextMenuActions(for viewModel: MessageViewModel) -> [UIAction]? {
        let pinningAction: MessageAction = pinnedMessageIds.contains(viewModel.message.messageId) ? .unpin : .pin
        let messageActions: [MessageAction] = [.addToStickers, pinningAction, .forward, .delete]
        let menuActions = messageActions.map { action -> UIAction in
            UIAction(title: action.title, image: action.image) { _ in
                if action == .delete || action == .forward {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.perforAction(action, for: viewModel)
                    }
                } else {
                    self.perforAction(action, for: viewModel)
                }
            }
        }
        return menuActions
    }
    
    override func tapAction(_ recognizer: UIGestureRecognizer) {
        let tappedIndexPath = tableView.indexPathForRow(at: recognizer.location(in: tableView))
        let tappedViewModel: MessageViewModel? = {
            if let indexPath = tappedIndexPath {
                return viewModel(at: indexPath)
            } else {
                return nil
            }
        }()
        if tableView.allowsMultipleSelection {
            if let indexPath = tappedIndexPath, let viewModel = tappedViewModel {
                if let indexPaths = tableView.indexPathsForSelectedRows, indexPaths.contains(indexPath) {
                    tableView.deselectRow(at: indexPath, animated: true)
                    selectedViewModels[viewModel.message.messageId] = nil
                } else {
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                    selectedViewModels[viewModel.message.messageId] = viewModel
                }
            }
            multipleSelectionView.numberOfSelection = selectedViewModels.count
        } else {
            super.tapAction(recognizer)
        }
    }
    
    override func dismissAction(_ sender: Any) {
        endMultipleSelection()
        super.dismissAction(sender)
    }
    
}

extension StackedPhotoPreviewViewController: MultipleSelectionActionViewDelegate {
    
    func multipleSelectionActionViewDidTapAction(_ view: MultipleSelectionActionView) {
        switch multipleSelectionView.intent {
        case .forward:
            let messages = selectedViewModels.values
                .map({ $0.message })
                .sorted(by: { $0.createdAt < $1.createdAt })
            if messages.count == 1 {
                let vc = MessageReceiverViewController.instance(content: .messages(messages))
                navigationController?.pushViewController(vc, animated: true)
            } else {
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                alert.addAction(UIAlertAction(title: R.string.localizable.chat_forward_one_by_one(), style: .default, handler: { (_) in
                    let vc = MessageReceiverViewController.instance(content: .messages(messages))
                    self.navigationController?.pushViewController(vc, animated: true)
                }))
                alert.addAction(UIAlertAction(title: R.string.localizable.chat_forward_combined(), style: .default, handler: { (_) in
                    let vc = MessageReceiverViewController.instance(content: .transcript(messages))
                    self.navigationController?.pushViewController(vc, animated: true)
                }))
                alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        case .delete:
            let viewModels = selectedViewModels.values.map({ $0 })
            let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if !viewModels.contains(where: { $0.message.userId != myUserId || !$0.message.canRecall }) {
                controller.addAction(UIAlertAction(title: Localized.ACTION_DELETE_EVERYONE, style: .destructive, handler: { (_) in
                    if AppGroupUserDefaults.User.hasShownRecallTips {
                        self.deleteForEveryone(viewModels: viewModels)
                    } else {
                        self.showRecallTips(viewModels: viewModels)
                    }
                }))
            }
            controller.addAction(UIAlertAction(title: Localized.ACTION_DELETE_ME, style: .destructive, handler: { (_) in
                self.deleteForMe(viewModels: viewModels)
            }))
            controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
            present(controller, animated: true, completion: nil)
        }
    }
    
    func multipleSelectionActionViewDidTapCancel(_ view: MultipleSelectionActionView) {
        endMultipleSelection()
    }
    
}

// MARK: - MessageViewModelFactoryDelegate
extension StackedPhotoPreviewViewController: MessageViewModelFactoryDelegate {
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, showUsernameForMessageIfNeeded message: MessageItem) -> Bool {
        message.userId != myUserId
    }
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, isMessageForwardedByBot message: MessageItem) -> Bool {
        false
    }
    
    func messageViewModelFactory(_ factory: MessageViewModelFactory, updateViewModelForPresentation viewModel: MessageViewModel) {
        
    }
    
}

extension StackedPhotoPreviewViewController {
    
    private func deleteForMe(viewModels: [MessageViewModel]) {
        for viewModel in viewModels {
            queue.async { [weak self] in
                let message = viewModel.message
                guard let self = self, let indexPath = self.indexPath(where: { $0.messageId == message.messageId }) else {
                    return
                }
                let (deleted, childMessageIds) = MessageDAO.shared.deleteMessage(id: message.messageId)
                if deleted {
                    ReceiveMessageService.shared.stopRecallMessage(item: message, childMessageIds: childMessageIds)
                }
                DispatchQueue.main.sync {
                    _ = self.removeViewModel(at: indexPath)
                    self.tableView.reloadData()
                    self.tableView.setFloatingHeaderViewsHidden(true, animated: true)
                }
            }
        }
        endMultipleSelection()
    }
    
    private func deleteForEveryone(viewModels: [MessageViewModel]) {
        DispatchQueue.global().async {
            for viewModel in viewModels {
                SendMessageService.shared.recallMessage(item: viewModel.message)
            }
        }
        endMultipleSelection()
    }
    
    private func showRecallTips(viewModels: [MessageViewModel]) {
        let alc = UIAlertController(title: R.string.localizable.chat_delete_tip(), message: "", preferredStyle: .alert)
        alc.addAction(UIAlertAction(title: R.string.localizable.action_learn_more(), style: .default, handler: { (_) in
            AppGroupUserDefaults.User.hasShownRecallTips = true
            UIApplication.shared.openURL(url: "https://mixinmessenger.zendesk.com/hc/articles/360028209571")
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_OK, style: .default, handler: { (_) in
            AppGroupUserDefaults.User.hasShownRecallTips = true
            self.deleteForEveryone(viewModels: viewModels)
        }))
        present(alc, animated: true, completion: nil)
    }
    
    private func reloadData() {
        let messages = self.photoMessageItems
        queue.async {
            let pinnedMessageIds = Set(PinMessageDAO.shared.messageItems(conversationId: self.conversationId).map(\.messageId))
            let (dates, viewModels) = self.categorizedViewModels(with: messages, fits: self.layoutWidth)
            DispatchQueue.main.async {
                self.dates = dates
                self.viewModels = viewModels
                self.pinnedMessageIds = pinnedMessageIds
                self.tableView.reloadData()
            }
        }
    }
    
    private func perforAction(_ action: MessageAction, for viewModel: MessageViewModel) {
        let message = viewModel.message
        switch action {
        case .forward:
            beginMultipleSelection(for: viewModel, intent: .forward)
        case .delete:
            beginMultipleSelection(for: viewModel, intent: .delete)
        case .addToStickers:
            let vc = StickerAddViewController.instance(source: .message(message))
            navigationController?.pushViewController(vc, animated: true)
        case .pin:
            SendMessageService.shared.sendPinMessages(items: [message], conversationId: conversationId, action: .pin)
        case .unpin:
            SendMessageService.shared.sendPinMessages(items: [message], conversationId: conversationId, action: .unpin)
        default:
            break
        }
    }
    
    private func beginMultipleSelection(for viewModel: MessageViewModel, intent: MultipleSelectionIntent) {
        guard let indexPath = indexPath(where: { $0.messageId == viewModel.message.messageId }) else {
            return
        }
        tableView.allowsMultipleSelection = true
        for cell in tableView.visibleCells {
            guard let cell = cell as? MessageCell else {
                continue
            }
            cell.setMultipleSelecting(true, animated: true)
        }
        multipleSelectionView.intent = intent
        multipleSelectionView.frame = CGRect(x: 0, y: view.bounds.height, width: view.bounds.width, height: multipleSelectionView.preferredHeight)
        multipleSelectionView.autoresizingMask = [.flexibleWidth]
        view.addSubview(multipleSelectionView)
        UIView.animateKeyframes(withDuration: 0.4, delay: 0, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                let y = self.view.bounds.height - self.multipleSelectionView.preferredHeight
                self.multipleSelectionView.frame.origin.y = y
            }
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                let height = self.multipleSelectionView.preferredHeight
                self.updateTableViewBottomInsetWithBottomBarHeight(height, animated: false)
            }
        }, completion: nil)
        DispatchQueue.main.async {
            self.multipleSelectionView.numberOfSelection = 1
            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            self.selectedViewModels[viewModel.message.messageId] = viewModel
        }
    }
    
    @objc private func endMultipleSelection() {
        selectedViewModels.removeAll()
        for cell in tableView.visibleCells.compactMap({ $0 as? MessageCell }) {
            cell.setMultipleSelecting(false, animated: true)
        }
        tableView.indexPathsForSelectedRows?.forEach({ (indexPath) in
            tableView.deselectRow(at: indexPath, animated: true)
        })
        tableView.allowsMultipleSelection = false
        UIView.animateKeyframes(withDuration: 0.4, delay: 0, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                self.updateTableViewBottomInsetWithBottomBarHeight(0, animated: false)
            }
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                self.multipleSelectionView.frame.origin.y = self.view.bounds.height
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
        }, completion: { _ in
            self.multipleSelectionView.removeFromSuperview()
        })
    }
    
    private func updateTableViewBottomInsetWithBottomBarHeight(_ height: CGFloat, animated: Bool) {
        func layout() {
            tableView.contentInset.bottom = height + MessageViewModel.bottomSeparatorHeight
            if view.window != nil {
                view.layoutIfNeeded()
            }
        }
        tableView.verticalScrollIndicatorInsets.bottom = height - view.safeAreaInsets.bottom
        if animated {
            UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve, animations: layout)
        } else {
            UIView.performWithoutAnimation(layout)
        }
    }
    
    @objc private func pinMessageDidSave(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[PinMessageDAO.UserInfoKey.conversationId] as? String, conversationId == self.conversationId else {
            return
        }
        guard let referencedMessageId = notification.userInfo?[PinMessageDAO.UserInfoKey.referencedMessageId] as? String else {
            return
        }
        pinnedMessageIds.insert(referencedMessageId)
    }
    
    @objc private func pinMessageDidDelete(_ notification: Notification) {
        guard let conversationId = notification.userInfo?[PinMessageDAO.UserInfoKey.conversationId] as? String, conversationId == self.conversationId else {
            return
        }
        guard let referencedMessageIds = notification.userInfo?[PinMessageDAO.UserInfoKey.referencedMessageIds] as? [String] else {
            return
        }
        pinnedMessageIds.subtract(referencedMessageIds)
    }
    
}
