import Foundation
import AVFoundation
import MixinServices

protocol PlaylistManagerDelegate: AnyObject {
    func playlistManager(_ manager: PlaylistManager, willPlay item: PlaylistItem)
    func playlistManagerDidPause(_ manager: PlaylistManager)
    func playlistManager(_ manager: PlaylistManager, didLoadEarlierItems items: [PlaylistItem])
    func playlistManager(_ manager: PlaylistManager, didLoadLaterItems items: [PlaylistItem])
    func playlistManagerDidClearAllItems(_ manager: PlaylistManager)
}

class PlaylistManager {
    
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
    private let loadMoreThreshold = 2
    
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
    
    init() {
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(playerDidPlayToEndTime(_:)),
                           name: .AVPlayerItemDidPlayToEndTime,
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
        
        func activateAudioSession() {
            do {
                try AudioSession.shared.activate(client: self) { (session) in
                    try session.setCategory(.playback, mode: .default, options: [])
                }
            } catch {
                performSynchronouslyOnMainThread {
                    self.setAudioCellStyle(.stopped, forCellsRegisteredWith: item.id)
                }
            }
        }
        
        if let playingId = playingItem?.id {
            if playingId == item.id, loadedItemIds.isSuperset(of: items.map(\.id)) {
                setAudioCellStyle(.playing, forCellsRegisteredWith: playingId)
                UIApplication.homeContainerViewController?.minimizedPlaylistViewController.show()
                queue.async {
                    activateAudioSession()
                    DispatchQueue.main.sync {
                        guard item.id == self.playingItem?.id else {
                            return
                        }
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
            activateAudioSession()
            let playerItem = AVPlayerItem(asset: asset)
            DispatchQueue.main.sync {
                self.player.replaceCurrentItem(with: playerItem)
                self.delegate?.playlistManager(self, willPlay: item)
                self.player.rate = self.playbackRate.avPlayerRate
                UIApplication.homeContainerViewController?.minimizedPlaylistViewController.show()
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
        delegate?.playlistManagerDidPause(self)
    }
    
    func stopAndClear() {
        if let item = playingItem {
            setAudioCellStyle(.stopped, forCellsRegisteredWith: item.id)
        }
        playingItemIndex = nil
        player.replaceCurrentItem(with: nil)
        items = []
        loadedItemIds = []
        loadingEarlierItemsPosition = nil
        loadingLaterItemsPosition = nil
        delegate?.playlistManagerDidClearAllItems(self)
        UIApplication.homeContainerViewController?.minimizedPlaylistViewController.hide()
        try? AudioSession.shared.deactivate(client: self, notifyOthersOnDeactivation: false)
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
                let item = items[index]
                setAudioCellStyle(.playing, forCellsRegisteredWith: item.id)
                delegate?.playlistManager(self, willPlay: item)
                player.rate = playbackRate.avPlayerRate
            } else {
                playLoadedItem(at: index, rebuildAvailableIndicesForShuffleMode: false)
            }
        } else {
            playLoadedItem(at: index, rebuildAvailableIndicesForShuffleMode: true)
        }
    }
    
    func seek(to percentage: Double, completion: @escaping () -> Void) {
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
        player.seek(to: cmTime) { (_) in
            completion()
        }
    }
    
}

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
    
    enum PlaybackRate: UInt {
        
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
        
    }
    
    enum ItemSource {
        case conversation(String)
        case remote
    }
    
}

extension PlaylistManager: AudioSessionClient {
    
    var priority: AudioSessionClientPriority {
        .playback
    }
    
    func audioSessionDidBeganInterruption(_ audioSession: AudioSession) {
        pause()
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
        delegate?.playlistManager(self, willPlay: item)
        setAudioCellStyle(.playing, forCellsRegisteredWith: item.id)
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
    
}
