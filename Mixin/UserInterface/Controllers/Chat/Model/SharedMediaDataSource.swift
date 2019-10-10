import Foundation

protocol SharedMediaItem {
    var messageId: String { get }
    var createdAt: String { get }
}

extension Message: SharedMediaItem { }

extension GalleryItem: SharedMediaItem {  }

protocol SharedMediaDataSourceDelegate: class {
    associatedtype ItemType: SharedMediaItem
    func sharedMediaDataSource(_ dataSource: SharedMediaDataSource<ItemType>, itemsForConversationId conversationId: String, location: ItemType?, count: Int) -> [ItemType]
    func sharedMediaDataSource(_ dataSource: SharedMediaDataSource<ItemType>, itemForMessageId messageId: String) -> ItemType?
    func sharedMediaDataSourceDidReload(_ dataSource: SharedMediaDataSource<ItemType>)
    func sharedMediaDataSource(_ dataSource: SharedMediaDataSource<ItemType>, didUpdateItemAt indexPath: IndexPath)
    func sharedMediaDataSource(_ dataSource: SharedMediaDataSource<ItemType>, didRemoveItemAt indexPath: IndexPath)
}

class SharedMediaDataSource<ItemType: SharedMediaItem> {
    
    var conversationId: String! {
        didSet {
            dates = []
            items = [:]
            loadedMessageIds = Set()
            isLoadingEarlier = false
            didLoadEarliest = false
        }
    }
    
    var numberOfSections: Int {
        return dates.count
    }
    
    private let queue = DispatchQueue(label: "one.mixin.ios.shared-media-data-source")
    private let numberOfItemsPerFetch = 30
    
    private(set) var dates = [String]()
    private(set) var items = [String: [ItemType]]()
    
    private var loadedMessageIds = Set<String>()
    private var isLoadingEarlier = false
    private var didLoadEarliest = false
    
    private var getItems: ((_ conversationId: String, _ location: ItemType?, _ count: Int) -> [ItemType]) = { (_, _, _) in [] }
    private var getItem: ((_ messageId: String) -> ItemType?) = { _ in nil }
    private var onReload: (() -> ()) = { }
    private var onUpdate: ((IndexPath) -> ()) = { _ in }
    private var onRemove: ((IndexPath) -> ()) = { _ in }
    
    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(conversationDidChange(_:)),
                                               name: .ConversationDidChange,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func setDelegate<DelegateType: SharedMediaDataSourceDelegate>(_ delegate: DelegateType) where DelegateType.ItemType == ItemType {
        getItems = { [weak delegate, unowned self] (conversationId, location, count) in
            delegate?.sharedMediaDataSource(self, itemsForConversationId: conversationId, location: location, count: count) ?? []
        }
        getItem = { [weak delegate, unowned self] (messageId) in
            delegate?.sharedMediaDataSource(self, itemForMessageId: messageId)
        }
        onReload = { [weak delegate, unowned self] in
            delegate?.sharedMediaDataSourceDidReload(self)
        }
        onUpdate = { [weak delegate, unowned self] (indexPath) in
            delegate?.sharedMediaDataSource(self, didUpdateItemAt: indexPath)
        }
        onRemove = { [weak delegate, unowned self] (indexPath) in
            delegate?.sharedMediaDataSource(self, didRemoveItemAt: indexPath)
        }
    }
    
    func reload() {
        let count = numberOfItemsPerFetch
        let conversationId = self.conversationId!
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            let items = weakSelf.getItems(conversationId, nil, count)
            let (dates, map) = weakSelf.categorizedItems(items: items)
            let loadedMessageIds = Set(items.map({ $0.messageId }))
            DispatchQueue.main.async {
                weakSelf.dates = dates
                weakSelf.items = map
                weakSelf.loadedMessageIds = loadedMessageIds
                weakSelf.onReload()
            }
        }
    }
    
    func title(of section: Int) -> String {
        return dates[section]
    }
    
    func numberOfItems(in section: Int) -> Int {
        items[dates[section]]?.count ?? 0
    }
    
    func item(for indexPath: IndexPath) -> ItemType? {
        let date = dates[indexPath.section]
        return items[date]?[indexPath.row]
    }
    
    func loadMoreEarlierItemsIfNeeded(location: IndexPath) {
        guard !didLoadEarliest, !isLoadingEarlier else {
            return
        }
        guard location.section == dates.count - 1, let lastDate = dates.last, let lastItems = items[lastDate], location.row >= lastItems.count - 10, let lastItem = lastItems.last else {
            return
        }
        isLoadingEarlier = true
        let conversationId = self.conversationId!
        let count = numberOfItemsPerFetch
        var loadedMessageIds = self.loadedMessageIds
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            let items = weakSelf.getItems(conversationId, lastItem, -count)
            guard !items.isEmpty else {
                return
            }
            var (dates, map) = weakSelf.categorizedItems(items: items)
            let messageIds = items.map({ $0.messageId })
            loadedMessageIds.formUnion(messageIds)
            DispatchQueue.main.sync {
                if let lastCurrentDate = weakSelf.dates.last, lastCurrentDate == dates.first {
                    dates.removeFirst()
                    if let items = map[lastDate] {
                        weakSelf.items[lastDate]?.append(contentsOf: items)
                    }
                }
                weakSelf.dates.append(contentsOf: dates)
                for date in dates {
                    weakSelf.items[date] = map[date]
                }
                weakSelf.loadedMessageIds = loadedMessageIds
                weakSelf.onReload()
                weakSelf.isLoadingEarlier = false
                weakSelf.didLoadEarliest = items.count < count
            }
        }
    }
    
    @objc func conversationDidChange(_ notification: Notification) {
        guard let change = notification.object as? ConversationChange, change.conversationId == conversationId else {
            return
        }
        switch change.action {
        case .updateMessage(let messageId):
            updateMessage(with: messageId)
        case .recallMessage(let messageId):
            removeItem(with: messageId)
        default:
            break
        }
    }
    
    private func categorizedItems(items: [ItemType]) -> (dates: [String], map: [String: [ItemType]]) {
        var dates = [String]()
        var map = [String: [ItemType]]()
        for item in items {
            let date = item.createdAt.toUTCDate()
            let title = DateFormatter.dateSimple.string(from: date)
            if map[title] != nil {
                map[title]!.append(item)
            } else {
                dates.append(title)
                map[title] = [item]
            }
        }
        return (dates, map)
    }
    
    private func updateMessage(with messageId: String) {
        guard loadedMessageIds.contains(messageId) else {
            return
        }
        queue.async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            guard let item = weakSelf.getItem(messageId) else {
                return
            }
            let date = item.createdAt.toUTCDate()
            let title = DateFormatter.dateSimple.string(from: date)
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                guard let section = weakSelf.dates.firstIndex(of: title), var items = weakSelf.items[title], let row = items.firstIndex(where: { $0.messageId == item.messageId }) else {
                    return
                }
                items[row] = item
                weakSelf.items[title] = items
                let indexPath = IndexPath(row: row, section: section)
                weakSelf.onUpdate(indexPath)
            }
        }
    }
    
    private func removeItem(with messageId: String) {
        loadedMessageIds.remove(messageId)
        for (date, var items) in self.items {
            guard let row = items.firstIndex(where: { $0.messageId == messageId }) else {
                continue
            }
            guard let section = self.dates.firstIndex(of: date) else {
                return
            }
            if items.count == 1 {
                self.dates.remove(at: section)
                self.items[date] = nil
            } else {
                items.remove(at: row)
                self.items[date] = items
            }
            let indexPath = IndexPath(row: row, section: section)
            onRemove(indexPath)
        }
    }
    
}
