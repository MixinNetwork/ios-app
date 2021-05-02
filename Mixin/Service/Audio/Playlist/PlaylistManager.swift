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
            commandCenter.previousTrackCommand.isEnabled = hasPreviousItem
            commandCenter.nextTrackCommand.isEnabled = hasNextItem
        }
    }
    
    var playbackRate: PlaybackRate = .normal {
        didSet {
            if status == .playing {
                player.rate = playbackRate.avPlayerRate
                updateNowPlayingInfo(elapsedPlaybackTime: true, rate: true)
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
    private let notificationCenter = NotificationCenter.default
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    
    private(set) var items: [PlaylistItem] = []
    private(set) var source: ItemSource = .remote
    
    // becomes nil on stop
    private var playingItemIndex: Int?
    
    private var cells: [String: NSHashTable<UITableViewCell>] = [:]
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
            var previousIndex = index
            repeat {
                previousIndex -= 1
            } while previousIndex >= 0
                && items[previousIndex].asset == nil
            if previousIndex >= 0 && items[previousIndex].asset != nil {
                return previousIndex
            } else {
                return nil
            }
        case .repeatList:
            var previousIndex = index
            repeat {
                previousIndex -= 1
                if previousIndex == -1 {
                    previousIndex = items.count - 1
                }
            } while previousIndex != index
                && items[previousIndex].asset == nil
            if previousIndex != index && items[previousIndex].asset != nil {
                return previousIndex
            } else {
                return nil
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
            var nextIndex = index
            repeat {
                nextIndex += 1
            } while nextIndex < items.count
                && items[nextIndex].asset == nil
            if nextIndex < items.count && items[nextIndex].asset != nil {
                return nextIndex
            } else {
                return nil
            }
        case .repeatList:
            var nextIndex = index
            repeat {
                nextIndex += 1
                if nextIndex == items.count {
                    nextIndex = 0
                }
            } while nextIndex != index
                && items[nextIndex].asset == nil
            if nextIndex != index && items[nextIndex].asset != nil {
                return nextIndex
            } else {
                return nil
            }
        case .shuffle:
            return availableIndicesInShuffleMode.randomElement()
        }
    }
    
    override init() {
        super.init()
        player.automaticallyWaitsToMinimizeStalling = false
        player.actionAtItemEnd = .pause
        notificationCenter.addObserver(self,
                                       selector: #selector(messageDAODidInsertMessage(_:)),
                                       name: MessageDAO.didInsertMessageNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(messageDAOWillDeleteMessage(_:)),
                                       name: MessageDAO.willDeleteMessageNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(conversationDAOWillClearConversation(_:)),
                                       name: ConversationDAO.willClearConversationNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(messageServiceWillRecallMessage(_:)),
                                       name: SendMessageService.willRecallMessageNotification,
                                       object: nil)
    }
    
    deinit {
        notificationCenter.removeObserver(self)
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
        
        if let previousItem = playingItem {
            if item.id == previousItem.id, loadedItemIds.isSuperset(of: items.map(\.id)) {
                setAudioCellStyle(.playing, forCellsRegisteredWith: item.id)
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
                setAudioCellStyle(.stopped, forCellsRegisteredWith: previousItem.id)
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
                if let item = self.player.currentItem {
                    self.unregisterForPlayerItemNotifications(from: item)
                }
                self.registerForPlayerItemNotifications(from: playerItem)
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
        if let item = player.currentItem {
            unregisterForPlayerItemNotifications(from: item)
        }
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
                self.updateNowPlayingInfo(elapsedPlaybackTime: true, rate: false)
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

// MARK: - PlayerItem Callback
extension PlaylistManager {
    
    private func registerForPlayerItemNotifications(from item: AVPlayerItem) {
        notificationCenter.addObserver(self,
                                       selector: #selector(playerItemDidPlayToEndTime(_:)),
                                       name: .AVPlayerItemDidPlayToEndTime,
                                       object: item)
        notificationCenter.addObserver(self,
                                       selector: #selector(playerItemFailedToPlayToEndTime(_:)),
                                       name: .AVPlayerItemFailedToPlayToEndTime,
                                       object: item)
    }
    
    private func unregisterForPlayerItemNotifications(from item: AVPlayerItem) {
        notificationCenter.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
        notificationCenter.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: item)
    }
    
    @objc private func playerItemDidPlayToEndTime(_ notification: Notification) {
        Queue.main.autoSync {
            switch repeatMode {
            case .repeatSingle:
                player.seek(to: .zero)
                player.play()
            case .repeatList:
                if hasNextItem {
                    playNextItem()
                } else {
                    player.seek(to: .zero) { _ in
                        self.playOrPauseCurrentItem()
                    }
                }
            case .shuffle:
                if hasNextItem {
                    playNextItem()
                } else {
                    rebuildAvailableIndicesForShuffleMode()
                    playNextItem()
                }
            }
        }
    }
    
    @objc private func playerItemFailedToPlayToEndTime(_ notification: Notification) {
        Queue.main.autoSync {
            if hasNextItem {
                playNextItem()
            } else {
                pause()
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
    
    private func resetPlayingInfoAndRemoteCommandTarget(item: PlaylistItem) {
        infoCenter.nowPlayingInfo = {
            let duration = TimeInterval(CMTimeGetSeconds(item.metadata.duration))
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
        
        commandCenter.playCommand.addTarget(self, action: #selector(playCommand(_:)))
        commandCenter.playCommand.isEnabled = true
        
        commandCenter.pauseCommand.addTarget(self, action: #selector(pauseCommand(_:)))
        commandCenter.pauseCommand.isEnabled = true
        
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(nextTrackCommand(_:)))
        commandCenter.nextTrackCommand.isEnabled = hasNextItem
        
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(previousTrackCommand(_:)))
        commandCenter.previousTrackCommand.isEnabled = hasPreviousItem
        
        commandCenter.changePlaybackPositionCommand.addTarget(self, action: #selector(changePlaybackPositionCommand(_:)))
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        
        commandCenter.changePlaybackRateCommand.addTarget(self, action: #selector(changePlaybackRateCommand(_:)))
        commandCenter.changePlaybackRateCommand.isEnabled = true
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
    
    private func updateNowPlayingInfo(elapsedPlaybackTime: Bool, rate: Bool) {
        guard var info = infoCenter.nowPlayingInfo else {
            return
        }
        if elapsedPlaybackTime {
            let elapsed = Double(CMTimeGetSeconds(player.currentTime()))
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: elapsed)
        }
        if rate {
            let rate = Double(playbackRate.avPlayerRate)
            info[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: rate)
        }
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
        resetPlayingInfoAndRemoteCommandTarget(item: item)
    }
    
    private func playerDidPause() {
        delegate?.playlistManagerDidPause(self)
        if #available(iOS 13.0, *) {
            infoCenter.playbackState = .paused
        }
        if let mini = UIApplication.homeContainerViewController?.minimizedPlaylistViewController {
            mini.waveView.stopAnimating()
        }
        updateNowPlayingInfo(elapsedPlaybackTime: true, rate: false)
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
                    for (index, item) in newItems.enumerated() {
                        if item.asset != nil {
                            self.availableIndicesInShuffleMode.insert(index)
                        }
                    }
                }
                if let index = self.playingItemIndex {
                    self.playingItemIndex = index + newItems.count
                }
                self.items.insert(contentsOf: newItems, at: 0)
                self.loadedItemIds.formUnion(newItemIds)
                self.loadingEarlierItemsPosition = nil
                self.didLoadEarliest = true
                self.delegate?.playlistManager(self, didLoadEarlierItems: newItems)
                self.commandCenter.previousTrackCommand.isEnabled = self.hasPreviousItem
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
                    for (index, item) in newItems.enumerated() {
                        if item.asset != nil {
                            self.availableIndicesInShuffleMode.insert(self.items.count + index)
                        }
                    }
                }
                self.items.append(contentsOf: newItems)
                self.loadedItemIds.formUnion(newItemIds)
                self.loadingLaterItemsPosition = nil
                self.didLoadLatest = true
                self.delegate?.playlistManager(self, didLoadLaterItems: newItems)
                self.downloadNextAttachmentIfNeeded()
                self.commandCenter.previousTrackCommand.isEnabled = self.hasNextItem
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
        if let item = playingItem {
            setAudioCellStyle(.stopped, forCellsRegisteredWith: item.id)
        }
        let playerItem = AVPlayerItem(asset: asset)
        playingItemIndex = index
        if let item = player.currentItem {
            unregisterForPlayerItemNotifications(from: item)
        }
        registerForPlayerItemNotifications(from: playerItem)
        player.replaceCurrentItem(with: playerItem)
        playerWillPlay(item: item)
        player.rate = playbackRate.avPlayerRate
        if repeatMode == .shuffle {
            if rebuildAvailableIndicesForShuffleMode || availableIndicesInShuffleMode.isEmpty {
                self.rebuildAvailableIndicesForShuffleMode()
            } else {
                availableIndicesInShuffleMode.remove(index)
            }
        }
    }
    
    private func rebuildAvailableIndicesForShuffleMode() {
        availableIndicesInShuffleMode = []
        for (index, item) in items.enumerated() {
            if item.asset != nil {
                availableIndicesInShuffleMode.insert(index)
            }
        }
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
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        if let playingIndex = playingItemIndex {
            if playingIndex == index {
                stop()
            } else if playingIndex > index {
                playingItemIndex = playingIndex - 1
            }
        }
        var newIndices: Set<Int> = []
        for oldIndex in availableIndicesInShuffleMode {
            if oldIndex < index {
                newIndices.insert(oldIndex)
            } else if oldIndex > index {
                newIndices.insert(oldIndex - 1)
            }
        }
        availableIndicesInShuffleMode = newIndices
        items.remove(at: index)
        delegate?.playlistManager(self, didRemoveItemAt: index)
        commandCenter.previousTrackCommand.isEnabled = hasPreviousItem
        commandCenter.nextTrackCommand.isEnabled = hasNextItem
    }
    
}
