import Foundation
import MixinServices

protocol SharedMediaItem {
    var messageId: String { get }
    var createdAt: String { get }
}

extension MessageItem: SharedMediaItem { }
extension GalleryItem: SharedMediaItem { }

protocol SharedMediaDataSourceDelegate: class {
    associatedtype ItemType: SharedMediaItem
    func sharedMediaDataSource(_ dataSource: AnyObject, itemsForConversationId conversationId: String, location: ItemType?, count: Int) -> [ItemType]
    func sharedMediaDataSource(_ dataSource: AnyObject, itemForMessageId messageId: String) -> ItemType?
    func sharedMediaDataSourceDidReload(_ dataSource: AnyObject)
    func sharedMediaDataSource(_ dataSource: AnyObject, didUpdateItemAt indexPath: IndexPath)
    func sharedMediaDataSource(_ dataSource: AnyObject, didRemoveItemAt indexPath: IndexPath)
}

class SharedMediaDataSource<ItemType: SharedMediaItem, CategorizerType: SharedMediaCategorizer<ItemType>> {
    
    var conversationId: String! {
        didSet {
            guard conversationId != oldValue else {
                return
            }
            dates = []
            items = [:]
            loadedMessageIds = Set()
            isLoading = false
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
    private var isLoading = false
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
        isLoading = true
        queue.async { [weak self] in
            guard let weakSelf = self, weakSelf.conversationId == conversationId else {
                return
            }
            let categorizer = CategorizerType.init()
            var didLoadEarliest = false
            var location: ItemType? = nil
            while !didLoadEarliest, categorizer.wantsMoreInput {
                let items = weakSelf.getItems(conversationId, location, count)
                didLoadEarliest = items.count < count
                categorizer.input(items: items, didLoadEarliest: didLoadEarliest)
                location = items.last
            }
            let loadedMessageIds = categorizer.categorizedMessageIds
            DispatchQueue.main.async {
                guard let weakSelf = self, weakSelf.conversationId == conversationId else {
                    return
                }
                weakSelf.dates = categorizer.dates
                weakSelf.items = categorizer.itemGroups
                weakSelf.loadedMessageIds = loadedMessageIds
                weakSelf.onReload()
                weakSelf.isLoading = false
                weakSelf.didLoadEarliest = didLoadEarliest
            }
        }
    }
    
    func title(of section: Int) -> String {
        return dates[section]
    }
    
    func numberOfItems(in section: Int) -> Int {
        return items[dates[section]]?.count ?? 0
    }
    
    func item(at indexPath: IndexPath) -> ItemType? {
        guard indexPath.section < dates.count else {
            return nil
        }
        let date = dates[indexPath.section]
        guard let items = self.items[date], indexPath.row >= 0, indexPath.row < items.count else {
            return nil
        }
        return items[indexPath.row]
    }
    
    func loadMoreEarlierItemsIfNeeded(location: IndexPath) {
        guard !didLoadEarliest, !isLoading else {
            return
        }
        guard location.section == dates.count - 1, let lastDate = dates.last, let lastItems = items[lastDate], location.row >= lastItems.count - 10 else {
            return
        }
        guard var location = CategorizerType.itemGroupIsAscending ? lastItems.first : lastItems.last else {
            return
        }
        isLoading = true
        let conversationId = self.conversationId!
        let count = numberOfItemsPerFetch
        queue.async { [weak self] in
            guard let weakSelf = self, weakSelf.conversationId == conversationId else {
                return
            }
            let categorizer = CategorizerType.init()
            var didLoadEarliest = false
            while categorizer.wantsMoreInput {
                let items = weakSelf.getItems(conversationId, location, count)
                didLoadEarliest = items.count < count
                categorizer.input(items: items, didLoadEarliest: didLoadEarliest)
                if !didLoadEarliest, let last = items.last {
                    location = last
                } else {
                    break
                }
            }
            let messageIds = categorizer.categorizedMessageIds
            var dates = categorizer.dates
            let itemGroups = categorizer.itemGroups
            DispatchQueue.main.sync {
                guard let weakSelf = self, weakSelf.conversationId == conversationId else {
                    return
                }
                if let lastCurrentDate = weakSelf.dates.last, lastCurrentDate == dates.first {
                    dates.removeFirst()
                    if let items = itemGroups[lastDate] {
                        weakSelf.items[lastDate]?.append(contentsOf: items)
                    }
                }
                weakSelf.dates.append(contentsOf: dates)
                for date in dates {
                    weakSelf.items[date] = itemGroups[date]
                }
                weakSelf.loadedMessageIds.formUnion(messageIds)
                weakSelf.onReload()
                weakSelf.didLoadEarliest = didLoadEarliest
                weakSelf.isLoading = false
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
        guard loadedMessageIds.contains(messageId) else {
            return
        }
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
