import UIKit
import MixinServices

protocol GalleryItemModelControllerDelegate: class {
    func modelController(_ controller: GalleryItemModelController, didLoadItemsBefore location: GalleryItem)
    func modelController(_ controller: GalleryItemModelController, didLoadItemsAfter location: GalleryItem)
}

final class GalleryItemModelController: NSObject {

    enum Direction {
        case forward
        case backward
    }
    
    weak var delegate: GalleryItemModelControllerDelegate?
    
    var direction = Direction.forward
    var conversationId = "" {
        didSet {
            didLoadEarliestItem = false
            didLoadLatestItem = false
        }
    }
    
    private let fetchItemsCount = 20
    private let queue = DispatchQueue(label: "one.mixin.ios.gallery")
    private let pageSize = UIScreen.main.bounds.size
    
    private var items = [GalleryItem]()
    private var reusableImageViewControllers = Set<GalleryImageItemViewController>()
    private var reusableVideoViewControllers = Set<GalleryVideoItemViewController>()
    private var didLoadEarliestItem = false
    private var didLoadLatestItem = false
    private var isLoadingBefore = false
    private var isLoadingAfter = false
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: .ConversationDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func dequeueReusableViewController(with item: GalleryItem) -> GalleryItemViewController {
        items = [item]
        fetchMoreItemsAfter()
        fetchMoreItemsBefore()
        return dequeueReusableViewController(of: 0)!
    }
    
    func dequeueReusableViewController(of index: Int) -> GalleryItemViewController? {
        guard index >= 0 && index < items.count else {
            return nil
        }
        let item = items[index]
        let viewController: GalleryItemViewController
        
        switch item.category {
        case .image:
            if let vc = reusableImageViewControllers.first(where: { $0.isReusable }) {
                viewController = vc
            } else {
                let vc = GalleryImageItemViewController()
                reusableImageViewControllers.insert(vc)
                viewController = vc
            }
        case .video, .live:
            if let vc = reusableVideoViewControllers.first(where: { $0.isReusable }) {
                viewController = vc
            } else {
                let vc = GalleryVideoItemViewController()
                reusableVideoViewControllers.insert(vc)
                viewController = vc
            }
        }
        
        viewController.prepareForReuse()
        viewController.item = item
        
        return viewController
    }
    
    @objc func conversationDidChange(_ notification: Notification) {
        guard let change = notification.object as? ConversationChange, change.conversationId == conversationId else {
            return
        }
        switch change.action {
        case .updateMessage(let messageId):
            updateMessage(messageId: messageId)
        case .updateDownloadProgress(let messageId, let progress):
            updateDownloadProgress(messageId: messageId, progress: progress)
        case .updateMediaStatus(let messageId, let mediaStatus):
            updateMediaStatus(messageId: messageId, mediaStatus: mediaStatus)
        case .recallMessage(let messageId):
            removeItem(messageId: messageId)
        default:
            break
        }
    }
    
    private func fetchMoreItemsBefore() {
        guard !didLoadEarliestItem && !isLoadingBefore else {
            return
        }
        guard let location = items.first else {
            return
        }
        isLoadingBefore = true
        let conversationId = self.conversationId
        let fetchItemsCount = self.fetchItemsCount
        queue.async { [weak self] in
            let items = MessageDAO.shared.getGalleryItems(conversationId: conversationId, location: location, count: -fetchItemsCount)
            DispatchQueue.main.async {
                guard let weakSelf = self, weakSelf.conversationId == conversationId else {
                    return
                }
                weakSelf.items.insert(contentsOf: items, at: 0)
                weakSelf.didLoadEarliestItem = items.count < fetchItemsCount
                weakSelf.isLoadingBefore = false
                weakSelf.delegate?.modelController(weakSelf, didLoadItemsBefore: location)
            }
        }
    }
    
    private func fetchMoreItemsAfter() {
        guard !didLoadLatestItem && !isLoadingAfter else {
            return
        }
        guard let location = items.last else {
            return
        }
        isLoadingAfter = true
        let conversationId = self.conversationId
        let fetchItemsCount = self.fetchItemsCount
        queue.async { [weak self] in
            let items = MessageDAO.shared.getGalleryItems(conversationId: conversationId, location: location, count: fetchItemsCount)
            DispatchQueue.main.async {
                guard let weakSelf = self, weakSelf.conversationId == conversationId else {
                    return
                }
                weakSelf.items.append(contentsOf: items)
                weakSelf.didLoadLatestItem = items.count < fetchItemsCount
                weakSelf.isLoadingAfter = false
                weakSelf.delegate?.modelController(weakSelf, didLoadItemsAfter: location)
            }
        }
    }
    
    private func reusableViewController(of messageId: String) -> GalleryItemViewController? {
        return reusableImageViewControllers.first(where: { $0.item?.messageId == messageId })
            ?? reusableVideoViewControllers.first(where: { $0.item?.messageId == messageId })
    }
    
    private func updateMessage(messageId: String) {
        guard items.contains(where: { $0.messageId == messageId }) else {
            return
        }
        queue.async { [weak self] in
            guard let message = MessageDAO.shared.getMessage(messageId: messageId), let item = GalleryItem(message: message) else {
                return
            }
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                guard let index = weakSelf.items.firstIndex(where: { $0.messageId == message.messageId }) else {
                    return
                }
                let previousItem = weakSelf.items[index]
                weakSelf.items[index] = item
                if let vc = weakSelf.reusableViewController(of: messageId) {
                    vc.item = item
                    if previousItem.mediaStatus != .DONE && item.mediaStatus == .DONE, let controlView = (vc as? GalleryVideoItemViewController)?.controlView {
                        controlView.set(playControlsHidden: false, otherControlsHidden: true, animated: true)
                    }
                }
            }
        }
    }
    
    private func updateDownloadProgress(messageId: String, progress: Double) {
        guard let vc = reusableViewController(of: messageId) else {
            return
        }
        vc.operationButton.style = .busy(progress: progress)
    }
    
    private func updateMediaStatus(messageId: String, mediaStatus: MediaStatus) {
        guard let index = items.firstIndex(where: { $0.messageId == messageId }) else {
            return
        }
        items[index].mediaStatus = mediaStatus
        if let vc = reusableViewController(of: messageId) {
            vc.item = items[index]
        }
    }
    
    private func removeItem(messageId: String) {
        guard let index = items.firstIndex(where: { $0.messageId == messageId }) else {
            return
        }
        items.remove(at: index)
    }
    
    private func dequeueReusableViewController(before viewController: UIViewController) -> UIViewController? {
        guard let item = (viewController as? GalleryItemViewController)?.item, let index = items.firstIndex(of: item) else {
            return nil
        }
        if index <= 1 {
            fetchMoreItemsBefore()
        }
        return dequeueReusableViewController(of: index - 1)
    }
    
    private func dequeueReusableViewController(after viewController: UIViewController) -> UIViewController? {
        guard let item = (viewController as? GalleryItemViewController)?.item, let index = items.lastIndex(of: item) else {
            return nil
        }
        if index >= items.count - 2 {
            fetchMoreItemsAfter()
        }
        return dequeueReusableViewController(of: index + 1)
    }
    
}

extension GalleryItemModelController: UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        switch direction {
        case .forward:
            return dequeueReusableViewController(before: viewController)
        case .backward:
            return dequeueReusableViewController(after: viewController)
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        switch direction {
        case .forward:
            return dequeueReusableViewController(after: viewController)
        case .backward:
            return dequeueReusableViewController(before: viewController)
        }
    }
    
}
