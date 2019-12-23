import Foundation
import MixinServices

class SharedMediaAudioTableViewController: SharedMediaTableViewController {
    
    typealias ItemType = SharedMediaAudio
    
    override var conversationId: String! {
        didSet {
            dataSource.conversationId = conversationId
        }
    }
    
    private let dataSource = SharedMediaDataSource<ItemType, SharedMediaGroupedByDateCategorizer<ItemType>>()
    private let audioManager = SharedMediaAudioManager()
    
    private var playingIndexPath: IndexPath?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        audioManager.delegate = self
        tableView.register(R.nib.sharedMediaAudioCell)
        tableView.dataSource = self
        tableView.delegate = self
        dataSource.setDelegate(self)
        dataSource.reload()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(audioManagerWillPlayNext(_:)),
                                               name: AudioManager.willPlayNextNotification,
                                               object: audioManager)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(audioManagerWillPlayPrevious(_:)),
                                               name: AudioManager.willPlayPreviousNotification,
                                               object: audioManager)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        audioManager.stop()
    }
    
    @objc func audioManagerWillPlayNext(_ notification: Notification) {
        playingIndexPath?.row += 1
        DispatchQueue.main.async { [weak self] in
            self?.markPlayingViewModelAndCellAsRead()
        }
    }
    
    @objc func audioManagerWillPlayPrevious(_ notification: Notification) {
        playingIndexPath?.row -= 1
        DispatchQueue.main.async { [weak self] in
            self?.markPlayingViewModelAndCellAsRead()
        }
    }
    
    private func markPlayingViewModelAndCellAsRead() {
        guard let indexPath = playingIndexPath else {
            return
        }
        dataSource.item(at: indexPath)?.mediaStatus = .READ
        if let cell = tableView.cellForRow(at: indexPath) as? SharedMediaAudioCell {
            cell.updateUnreadStyle()
        }
    }
    
}

extension SharedMediaAudioTableViewController: SharedMediaDataSourceDelegate {
    
    func sharedMediaDataSource(_ dataSource: AnyObject, itemsForConversationId conversationId: String, location: ItemType?, count: Int) -> [ItemType] {
        let messages = MessageDAO.shared.getAudioMessages(conversationId: conversationId, earlierThan: location?.message, count: count)
        return messages.map(SharedMediaAudio.init)
    }
    
    func sharedMediaDataSource(_ dataSource: AnyObject, itemForMessageId messageId: String) -> ItemType? {
        if let msg = MessageDAO.shared.getFullMessage(messageId: messageId) {
            return SharedMediaAudio(message: msg)
        } else {
            return nil
        }
    }
    
    func sharedMediaDataSourceDidReload(_ dataSource: AnyObject) {
        tableView.reloadData()
        tableView.checkEmpty(dataCount: self.dataSource.numberOfSections,
                             text: R.string.localizable.chat_shared_audio_empty(),
                             photo: R.image.ic_shared_audio()!)
    }
    
    func sharedMediaDataSource(_ dataSource: AnyObject, didUpdateItemAt indexPath: IndexPath) {
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    func sharedMediaDataSource(_ dataSource: AnyObject, didRemoveItemAt indexPath: IndexPath) {
        if self.dataSource.numberOfItems(in: indexPath.section) == 1 {
            tableView.deleteSections(IndexSet(integer: indexPath.section), with: .automatic)
        } else {
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
}

extension SharedMediaAudioTableViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.numberOfSections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.numberOfItems(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.shared_media_audio, for: indexPath)!
        if let item = dataSource.item(at: indexPath) {
            cell.render(audio: item)
        }
        cell.audioManager = audioManager
        return cell
    }
    
}

extension SharedMediaAudioTableViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        dataSource.loadMoreEarlierItemsIfNeeded(location: indexPath)
        guard let cell = cell as? AudioCell, let item = dataSource.item(at: indexPath) else {
            return
        }
        audioManager.register(cell: cell, forMessageId: item.messageId)
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? AudioCell, let item = dataSource.item(at: indexPath) else {
            return
        }
        audioManager.unregister(cell: cell, forMessageId: item.messageId)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId) as! SharedMediaTableHeaderView
        view.label.text = dataSource.title(of: section)
        return view
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.item(at: indexPath) else {
            return
        }
        if AudioManager.shared.player?.status == .playing {
            AudioManager.shared.player?.pause()
        }
        if audioManager.playingMessage?.messageId == item.messageId, audioManager.player?.status == .playing {
            playingIndexPath = nil
            audioManager.pause()
        } else {
            playingIndexPath = indexPath
            audioManager.play(message: item.message)
            item.mediaStatus = .READ
            (tableView.cellForRow(at: indexPath) as? SharedMediaAudioCell)?.updateUnreadStyle()
        }
    }
    
}

extension SharedMediaAudioTableViewController: SharedMediaAudioManagerDelegate {
    
    func sharedMediaAudioManager(_ manager: SharedMediaAudioManager, playableMessageNextTo message: MessageItem) -> MessageItem? {
        guard var indexPath = playingIndexPath else {
            return nil
        }
        indexPath.row += 1
        return dataSource.item(at: indexPath)?.message
    }
    
    func sharedMediaAudioManager(_ manager: SharedMediaAudioManager, playableMessagePreviousTo message: MessageItem) -> MessageItem? {
        guard var indexPath = playingIndexPath else {
            return nil
        }
        indexPath.row -= 1
        return dataSource.item(at: indexPath)?.message
    }
    
}
