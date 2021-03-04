import Foundation
import AVFoundation
import MediaPlayer
import MixinServices

protocol PlaylistManagerDelegate: AnyObject {
    func playlistManager(_ manager: PlaylistManager, willPlay item: PlaylistItem)
    func playlistManagerDidPause(_ manager: PlaylistManager)
    func playlistManagerDidEnd(_ manager: PlaylistManager)
    func playlistManager(_ manager: PlaylistManager, didLoadEarlierItems items: [PlaylistItem])
    func playlistManager(_ manager: PlaylistManager, didLoadLaterItems items: [PlaylistItem])
    func playlistManager(_ manager: PlaylistManager, didRemoveItemAt index: Int)
    func playlistManagerDidRemoveAll(_ manager: PlaylistManager)
}

class PlaylistManager: NSObject {
    
    static let shared = PlaylistManager()
    
    let player = AVPlayer()
    
    weak var delegate: PlaylistManagerDelegate?
    
    var repeatMode: RepeatMode = .repeatList {
        didSet {
            if repeatMode == .shuffle {
                rebuildAvailableIndicesForShuffleMode()
            }
        }
    }
    
    var playbackRate: PlaybackRate = .normal {
        didSet {
            if status == .playing {
                player.rate = playbackRate.avPlayerRate
            }
        }
    }
    
    var status: Status {
        assert(Thread.isMainThread)
        if playingItem == nil {
            return .stopped
        } else {
            if player.timeControlStatus == .paused {
                return .paused
            } else {
                return .playing
            }
        }
    }
    
    var playingItem: PlaylistItem? {
        if let index = playingItemIndex {
            return items[index]
        } else {
            return nil
        }
    }
    
    var hasPreviousItem: Bool {
        previousItemIndex != nil
    }
    
    var hasNextItem: Bool {
        nextItemIndex != nil
    }
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.PlaylistManager")
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    
    private(set) var items: [PlaylistItem] = []
    
    // becomes nil on stop
    private var playingItemIndex: Int?
    
    private var cells: [String: NSHashTable<UITableViewCell>] = [:]
    private var source: ItemSource = .remote
    private var loadedItemIds: Set<String> = []
    private var loadingEarlierItemsPosition: String?
    private var loadingLaterItemsPosition: String?
    private var didLoadEarliest = false
    private var didLoadLatest = false
    private var availableIndicesInShuffleMode: Set<Int> = []
    
    private var previousItemIndex: Int? {
        guard let index = playingItemIndex else {
            return nil
        }
        switch repeatMode {
        case .repeatSingle:
            if index > 0 {
                return index - 1
            } else {
                return nil
            }
        case .repeatList:
            if index > 0 {
                return index - 1
            } else {
                return items.count - 1
            }
        case .shuffle:
            return availableIndicesInShuffleMode.randomElement()
        }
    }
    
    private var nextItemIndex: Int? {
        guard let index = playingItemIndex else {
            return nil
        }
        switch repeatMode {
        case .repeatSingle:
            if index < items.count - 1 {
                return index + 1
            } else {
                return nil
            }
        case .repeatList:
            if index < items.count - 1 {
                return index + 1
            } else {
                return 0
            }
        case .shuffle:
            return availableIndicesInShuffleMode.randomElement()
        }
    }
    
    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(playerDidPlayToEndTime(_:)),
                           name: .AVPlayerItemDidPlayToEndTime,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(messageDAODidInsertMessage(_:)),
                           name: MessageDAO.didInsertMessageNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(messageDAOWillDeleteMessage(_:)),
                           name: MessageDAO.willDeleteMessageNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(conversationDAOWillClearConversation(_:)),
                           name: ConversationDAO.willClearConversationNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(messageServiceWillRecallMessage(_:)),
                           name: SendMessageService.willRecallMessageNotification,
                           object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func playOrPauseCurrentItem() {
        guard let index = playingItemIndex else {
            return
        }
        playOrPause(index: index, in: items, source: source)
    }
    
    func playOrPause(index: Int, in items: [PlaylistItem], source: ItemSource) {
        let item = items[index]
        if status == .playing, playingItem?.id == item.id, loadedItemIds.isSuperset(of: items.map(\.id)) {
            pause()
        } else {
            play(index: index, in: items, source: source)
        }
    }
    
    func play(index: Int, in items: [PlaylistItem], source: ItemSource) {
        let item = items[index]
        guard let asset = item.asset else {
            return
        }
        
        // Returns true on success, false on failed
        func activateAudioSession() -> Bool {
            do {
                try AudioSession.shared.activate(client: self) { (session) in
                    try session.setCategory(.playback, mode: .default, options: [])
                }
                return true
            } catch {
                return false
            }
        }
        
        if let playingId = playingItem?.id {
            if playingId == item.id, loadedItemIds.isSuperset(of: items.map(\.id)) {
                setAudioCellStyle(.playing, forCellsRegisteredWith: playingId)
                queue.async {
                    guard activateAudioSession() else {
                        DispatchQueue.main.sync {
                            self.setAudioCellStyle(.paused, forCellsRegisteredWith: item.id)
                            self.playerDidPause()
                        }
                        return
                    }
                    DispatchQueue.main.sync {
                        guard item.id == self.playingItem?.id else {
                            return
                        }
                        self.playerWillPlay(item: item)
                        self.player.rate = self.playbackRate.avPlayerRate
                    }
                }
                return
            } else {
                setAudioCellStyle(.stopped, forCellsRegisteredWith: playingId)
            }
        }
        
        setAudioCellStyle(.playing, forCellsRegisteredWith: item.id)
        self.source = source
        self.playingItemIndex = index
        self.items = items
        self.loadedItemIds = Set(items.map(\.id))
        self.loadingEarlierItemsPosition = nil
        self.loadingLaterItemsPosition = nil
        
        let itemsAreFromRemotePlaylist: Bool
        switch source {
        case .conversation:
            itemsAreFromRemotePlaylist = false
        case .remote:
            itemsAreFromRemotePlaylist = true
        }
        self.didLoadEarliest = itemsAreFromRemotePlaylist
        self.didLoadLatest = itemsAreFromRemotePlaylist
        
        if repeatMode == .shuffle {
            rebuildAvailableIndicesForShuffleMode()
        }
        
        queue.async {
            guard activateAudioSession() else {
                DispatchQueue.main.sync {
                    self.setAudioCellStyle(.paused, forCellsRegisteredWith: item.id)
                    self.playerDidPause()
                }
                return
            }
            let playerItem = AVPlayerItem(asset: asset)
            DispatchQueue.main.sync {
                self.player.replaceCurrentItem(with: playerItem)
                self.playerWillPlay(item: item)
                self.player.rate = self.playbackRate.avPlayerRate
                self.loadEarlierItemsIfNeeded()
                self.loadLaterItemsIfNeeded()
                self.downloadNextAttachmentIfNeeded()
            }
        }
    }
    
    func pause() {
        guard let item = playingItem else {
            return
        }
        setAudioCellStyle(.paused, forCellsRegisteredWith: item.id)
        player.pause()
        playerDidPause()
    }
    
    func stop() {
        if let item = playingItem {
            setAudioCellStyle(.stopped, forCellsRegisteredWith: item.id)
        }
        playingItemIndex = nil
        player.replaceCurrentItem(with: nil)
        playerDidEnd()
    }
    
    func removeAllItems() {
        items = []
        loadedItemIds = []
        availableIndicesInShuffleMode = []
        loadingEarlierItemsPosition = nil
        loadingLaterItemsPosition = nil
        delegate?.playlistManagerDidRemoveAll(self)
    }
    
    func playPreviousItem() {
        guard let index = previousItemIndex else {
            return
        }
        playLoadedItem(at: index, rebuildAvailableIndicesForShuffleMode: false)
    }
    
    func playNextItem() {
        guard let index = nextItemIndex else {
            return
        }
        playLoadedItem(at: index, rebuildAvailableIndicesForShuffleMode: false)
    }
    
    func playOrPauseLoadedItem(at index: Int) {
        if index == playingItemIndex {
            if player.timeControlStatus == .playing {
                pause()
            } else if player.currentItem != nil {
                playerWillPlay(item: items[index])
                player.rate = playbackRate.avPlayerRate
            } else {
                playLoadedItem(at: index, rebuildAvailableIndicesForShuffleMode: false)
            }
        } else {
            playLoadedItem(at: index, rebuildAvailableIndicesForShuffleMode: true)
        }
    }
    
    func seek(to percentage: Double, completion: @escaping (Bool) -> Void) {
        guard percentage >= 0 && percentage <= 1 else {
            assertionFailure("Accepts percentage between 0...1")
            return
        }
        guard let playerItem = player.currentItem else {
            return
        }
        let duration = CMTimeGetSeconds(playerItem.duration)
        guard duration.isFinite else {
            return
        }
        let cmTime = CMTime(seconds: duration * percentage,
                            preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime) { (finished) in
            if finished {
                self.updateNowPlayingInfoElapsedPlaybackTime()
            }
            completion(finished)
        }
    }
    
}

// MARK: - Cell Registration
extension PlaylistManager {
    
    func register(cell: AudioCell, for id: String) {
        if let table = cells[id] {
            table.add(cell)
        } else {
            let table = NSHashTable<UITableViewCell>(options: .weakMemory)
            table.add(cell)
            cells[id] = table
        }
        if id == playingItem?.id {
            if player.timeControlStatus == .playing {
                cell.style = .playing
            } else {
                cell.style = .paused
            }
        } else {
            cell.style = .stopped
        }
    }
    
    func unregister(cell: AudioCell, for id: String) {
        guard let table = cells[id] else {
            return
        }
        table.remove(cell)
    }
    
    private func setAudioCellStyle(_ style: AudioCellStyle, forCellsRegisteredWith id: String) {
        guard let table = cells[id] else {
            return
        }
        let enumerator = table.objectEnumerator()
        while let cell = enumerator.nextObject() as? AudioCell {
            cell.style = style
        }
    }
    
}

// MARK: - Player Callback
extension PlaylistManager {
    
    @objc private func playerDidPlayToEndTime(_ notification: Notification) {
        performSynchronouslyOnMainThread {
            switch repeatMode {
            case .repeatSingle:
                player.seek(to: .zero)
                player.play()
            case .repeatList, .shuffle:
                if let index = nextItemIndex, items[index].asset != nil {
                    playNextItem()
                } else {
                    player.seek(to: .zero) { _ in
                        self.pause()
                    }
                }
            }
        }
    }
    
}

// MARK: - Remote Command Callback
extension PlaylistManager {
    
    @objc private func playCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        if let index = playingItemIndex {
            play(index: index, in: items, source: source)
            return .success
        } else {
            return .noActionableNowPlayingItem
        }
    }
    
    @objc private func pauseCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        pause()
        return .success
    }
    
    @objc private func nextTrackCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        if hasNextItem {
            playNextItem()
            return .success
        } else {
            return .noSuchContent
        }
    }
    
    @objc private func previousTrackCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        if hasPreviousItem {
            playPreviousItem()
            return .success
        } else {
            return .noSuchContent
        }
    }
    
    @objc private func changePlaybackPositionCommand(_ event: MPChangePlaybackPositionCommandEvent) -> MPRemoteCommandHandlerStatus {
        let cmTime = CMTime(seconds: event.positionTime,
                            preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime)
        return .success
    }
    
    @objc private func changePlaybackRateCommand(_ event: MPChangePlaybackRateCommandEvent) -> MPRemoteCommandHandlerStatus {
        guard let rate = PlaybackRate(avPlayerRate: event.playbackRate) else {
            return .noSuchContent
        }
        playbackRate = rate
        return .success
    }
    
}

// MARK: - Now Playing Infos
extension PlaylistManager {
    
    private func resetPlayingInfoAndRemoteCommandTarget() {
        guard let index = playingItemIndex else {
            removePlayingInfoAndRemoteCommandTarget()
            return
        }
        let item = items[index]
        guard let asset = item.asset else {
            removePlayingInfoAndRemoteCommandTarget()
            return
        }
        
        infoCenter.nowPlayingInfo = {
            let duration = TimeInterval(CMTimeGetSeconds(asset.duration))
            let rate = Double(playbackRate.avPlayerRate)
            let elapsed = Double(CMTimeGetSeconds(player.currentTime()))
            
            var info: [String: Any] = [
                MPMediaItemPropertyPlaybackDuration: NSNumber(value: duration),
                MPNowPlayingInfoPropertyPlaybackRate: NSNumber(value: rate),
                MPNowPlayingInfoPropertyElapsedPlaybackTime: NSNumber(value: elapsed),
            ]
            if let title = item.metadata.title {
                info[MPMediaItemPropertyTitle] = title
            }
            if let artist = item.metadata.subtitle {
                info[MPMediaItemPropertyArtist] = artist
            }
            if let image = item.metadata.image {
                info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            }
            return info
        }()
        
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = PlaybackRate.allCases.map {
            NSNumber(value: $0.avPlayerRate)
        }
        
        func setCommandEnabled(_ command: MPRemoteCommand, with action: Selector) {
            command.isEnabled = true
            command.addTarget(self, action: action)
        }
        setCommandEnabled(commandCenter.playCommand, with: #selector(playCommand(_:)))
        setCommandEnabled(commandCenter.pauseCommand, with: #selector(pauseCommand(_:)))
        setCommandEnabled(commandCenter.nextTrackCommand, with: #selector(nextTrackCommand(_:)))
        setCommandEnabled(commandCenter.previousTrackCommand, with: #selector(previousTrackCommand(_:)))
        setCommandEnabled(commandCenter.changePlaybackPositionCommand, with: #selector(changePlaybackPositionCommand(_:)))
        setCommandEnabled(commandCenter.changePlaybackRateCommand, with: #selector(changePlaybackRateCommand(_:)))
    }
    
    private func removePlayingInfoAndRemoteCommandTarget() {
        infoCenter.nowPlayingInfo = nil
        let commands = [
            commandCenter.playCommand,
            commandCenter.pauseCommand,
            commandCenter.nextTrackCommand,
            commandCenter.previousTrackCommand,
            commandCenter.changePlaybackPositionCommand,
            commandCenter.changePlaybackRateCommand,
        ]
        for command in commands {
            command.isEnabled = false
            command.removeTarget(self)
        }
    }
    
    private func updateNowPlayingInfoElapsedPlaybackTime() {
        guard var info = infoCenter.nowPlayingInfo else {
            return
        }
        let elapsed = Double(CMTimeGetSeconds(player.currentTime()))
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: elapsed)
        infoCenter.nowPlayingInfo = info
    }
    
}

// MARK: - Embedded Struct
extension PlaylistManager {
    
    enum Status {
        case playing
        case paused
        case stopped
    }
    
    enum RepeatMode: UInt {
        
        case repeatList = 0
        case repeatSingle
        case shuffle
        
        var next: RepeatMode {
            if let mode = RepeatMode(rawValue: rawValue + 1) {
                return mode
            } else {
                return .repeatList
            }
        }
        
    }
    
    enum PlaybackRate: UInt, CaseIterable {
        
        case normal = 0
        case faster
        case fastest
        
        var next: PlaybackRate {
            if let mode = PlaybackRate(rawValue: rawValue + 1) {
                return mode
            } else {
                return .normal
            }
        }
        
        var avPlayerRate: Float {
            switch self {
            case .normal:
                return 1
            case .faster:
                return 1.5
            case .fastest:
                return 2
            }
        }
        
        init?(avPlayerRate rate: Float) {
            switch rate {
            case 1:
                self = .normal
            case 1.5:
                self = .faster
            case 2:
                self = .fastest
            default:
                return nil
            }
        }
        
    }
    
    enum ItemSource {
        case conversation(String)
        case remote
    }
    
}

// MARK: - AudioSessionClient
extension PlaylistManager: AudioSessionClient {
    
    var priority: AudioSessionClientPriority {
        .playback
    }
    
    func audioSessionDidBeganInterruption(_ audioSession: AudioSession) {
        pause()
        removePlayingInfoAndRemoteCommandTarget()
    }
    
    func audioSession(_ audioSession: AudioSession, didChangeRouteFrom previousRoute: AVAudioSessionRouteDescription, reason: AVAudioSession.RouteChangeReason) {
        let previousOutput = previousRoute.outputs.first
        let output = audioSession.avAudioSession.currentRoute.outputs.first
        if previousOutput?.portType == .headphones, output?.portType != .headphones {
            DispatchQueue.main.async(execute: pause)
            return
        }
        switch reason {
        case .override, .newDeviceAvailable, .routeConfigurationChange:
            break
        case .categoryChange:
            let newCategory = audioSession.avAudioSession.category
            let canContinue = newCategory == .playback || newCategory == .playAndRecord
            if !canContinue {
                DispatchQueue.main.async(execute: pause)
            }
        case .unknown, .oldDeviceUnavailable, .wakeFromSleep, .noSuitableRouteForCategory:
            DispatchQueue.main.async(execute: pause)
        @unknown default:
            DispatchQueue.main.async(execute: pause)
        }
    }
    
    func audioSessionMediaServicesWereReset(_ audioSession: AudioSession) {
        
    }
    
}

// MARK: - Player Status Cycle
extension PlaylistManager {
    
    private func playerWillPlay(item: PlaylistItem) {
        setAudioCellStyle(.playing, forCellsRegisteredWith: item.id)
        delegate?.playlistManager(self, willPlay: item)
        if let mini = UIApplication.homeContainerViewController?.minimizedPlaylistViewController {
            mini.show()
            mini.waveView.startAnimating()
        }
        if #available(iOS 13.0, *) {
            infoCenter.playbackState = .playing
        }
        resetPlayingInfoAndRemoteCommandTarget()
    }
    
    private func playerDidPause() {
        delegate?.playlistManagerDidPause(self)
        if #available(iOS 13.0, *) {
            infoCenter.playbackState = .paused
        }
        if let mini = UIApplication.homeContainerViewController?.minimizedPlaylistViewController {
            mini.waveView.stopAnimating()
        }
        updateNowPlayingInfoElapsedPlaybackTime()
    }
    
    private func playerDidEnd() {
        delegate?.playlistManagerDidEnd(self)
        if let mini = UIApplication.homeContainerViewController?.minimizedPlaylistViewController {
            mini.waveView.stopAnimating()
            mini.hide()
        }
        try? AudioSession.shared.deactivate(client: self, notifyOthersOnDeactivation: false)
        if #available(iOS 13.0, *) {
            infoCenter.playbackState = .stopped
        }
        removePlayingInfoAndRemoteCommandTarget()
    }
    
}

// MARK: - Message update callback
extension PlaylistManager {
    
    @objc private func messageDAODidInsertMessage(_ notification: Notification) {
        guard let id = notification.userInfo?[MessageDAO.UserInfoKey.conversationId] as? String else {
            return
        }
        guard case let .conversation(conversationId) = source, conversationId == id else {
            return
        }
        guard let message = notification.userInfo?[MessageDAO.UserInfoKey.message] as? MessageItem else {
            return
        }
        guard !loadedItemIds.contains(message.messageId), message.isListPlayable else {
            return
        }
        loadingLaterItemsPosition = nil // This will cancel previously dispatched loading process
        didLoadLatest = false
        loadLaterItemsIfNeeded()
    }
    
    @objc private func messageDAOWillDeleteMessage(_ notification: Notification) {
        guard let messageId = notification.userInfo?[MessageDAO.UserInfoKey.messageId] as? String else {
            return
        }
        guard case .conversation = source else {
            return
        }
        removeItem(with: messageId)
    }
    
    @objc private func conversationDAOWillClearConversation(_ notification: Notification) {
        guard let id = notification.userInfo?[ConversationDAO.conversationIdUserInfoKey] as? String else {
            return
        }
        guard case let .conversation(conversationId) = source, conversationId == id else {
            return
        }
        stop()
        removeAllItems()
    }
    
    @objc private func messageServiceWillRecallMessage(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        guard let id = userInfo[SendMessageService.UserInfoKey.conversationId] as? String else {
            return
        }
        guard case let .conversation(conversationId) = source, conversationId == id else {
            return
        }
        guard let messageId = userInfo[SendMessageService.UserInfoKey.messageId] as? String else {
            return
        }
        guard loadedItemIds.contains(messageId) else {
            return
        }
        removeItem(with: messageId)
    }
    
}

// MARK: - Private works
extension PlaylistManager {
    
    private func loadEarlierItemsIfNeeded() {
        guard !didLoadEarliest, loadingEarlierItemsPosition == nil else {
            return
        }
        guard let position = items.first else {
            return
        }
        guard case let .conversation(conversationId) = source else {
            return
        }
        loadingEarlierItemsPosition = position.id
        DispatchQueue.global().async {
            let newItems = MessageDAO.shared.getPlaylistItems(ofConversationWith: conversationId,
                                                              aboveMessageWith: position.id)
            let newItemIds = newItems.map(\.id)
            DispatchQueue.main.sync {
                guard self.loadingEarlierItemsPosition == position.id else {
                    return
                }
                if self.repeatMode == .shuffle {
                    self.availableIndicesInShuffleMode = Set(self.availableIndicesInShuffleMode.map { $0 + newItems.count })
                    let newIndices = self.items.count..<(self.items.count + newItems.count)
                    self.availableIndicesInShuffleMode.formUnion(newIndices)
                }
                if let index = self.playingItemIndex {
                    self.playingItemIndex = index + newItems.count
                }
                self.items.insert(contentsOf: newItems, at: 0)
                self.loadedItemIds.formUnion(newItemIds)
                self.loadingEarlierItemsPosition = nil
                self.didLoadEarliest = true
                self.delegate?.playlistManager(self, didLoadEarlierItems: newItems)
            }
        }
    }
    
    private func loadLaterItemsIfNeeded() {
        guard !didLoadLatest, loadingLaterItemsPosition == nil else {
            return
        }
        guard let position = items.last else {
            return
        }
        guard case let .conversation(conversationId) = source else {
            return
        }
        loadingLaterItemsPosition = position.id
        DispatchQueue.global().async {
            let newItems = MessageDAO.shared.getPlaylistItems(ofConversationWith: conversationId,
                                                              belowMessageWith: position.id)
            let newItemIds = newItems.map(\.id)
            DispatchQueue.main.sync {
                guard self.loadingLaterItemsPosition == position.id else {
                    return
                }
                if self.repeatMode == .shuffle {
                    let newIndices = self.items.count..<(self.items.count + newItems.count)
                    self.availableIndicesInShuffleMode.formUnion(newIndices)
                }
                self.items.append(contentsOf: newItems)
                self.loadedItemIds.formUnion(newItemIds)
                self.loadingLaterItemsPosition = nil
                self.didLoadLatest = true
                self.delegate?.playlistManager(self, didLoadLaterItems: newItems)
                self.downloadNextAttachmentIfNeeded()
            }
        }
    }
    
    private func playLoadedItem(at index: Int, rebuildAvailableIndicesForShuffleMode: Bool) {
        guard index >= 0 && index < items.count else {
            return
        }
        let item = items[index]
        guard let asset = item.asset else {
            return
        }
        if let index = playingItemIndex {
            setAudioCellStyle(.stopped, forCellsRegisteredWith: items[index].id)
        }
        let playerItem = AVPlayerItem(asset: asset)
        playingItemIndex = index
        player.replaceCurrentItem(with: playerItem)
        playerWillPlay(item: item)
        player.rate = playbackRate.avPlayerRate
        if repeatMode == .shuffle {
            if rebuildAvailableIndicesForShuffleMode {
                self.rebuildAvailableIndicesForShuffleMode()
            } else {
                availableIndicesInShuffleMode.remove(index)
            }
        }
    }
    
    private func rebuildAvailableIndicesForShuffleMode() {
        availableIndicesInShuffleMode = Set(0..<items.count)
        if let index = playingItemIndex {
            availableIndicesInShuffleMode.remove(index)
        }
    }
    
    private func downloadNextAttachmentIfNeeded() {
        let shouldDownload: Bool
        switch AppGroupUserDefaults.User.autoDownloadFiles {
        case .never:
            shouldDownload = false
        case .wifi:
            shouldDownload = ReachabilityManger.shared.isReachableOnEthernetOrWiFi
        case .wifiAndCellular:
            shouldDownload = true
        }
        guard shouldDownload, let index = nextItemIndex else {
            return
        }
        items[index].downloadAttachment()
    }
    
    private func removeItem(with id: String) {
        loadedItemIds.remove(id)
        if playingItem?.id == id {
            stop()
        }
        if let index = items.firstIndex(where: { $0.id == id }) {
            availableIndicesInShuffleMode.remove(index)
            items.remove(at: index)
            delegate?.playlistManager(self, didRemoveItemAt: index)
        }
    }
    
}
