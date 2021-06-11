import UIKit
import MixinServices

protocol GalleryItemModelControllerDelegate: AnyObject {
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
    var conversationId: String? {
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
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: MixinServices.conversationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateDownloadProgress(_:)), name: AttachmentLoadingJob.progressNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMessageMediaStatus(_:)), name: MessageDAO.messageMediaStatusDidUpdateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateTranscriptMessageMediaStatus(_:)), name: TranscriptMessageDAO.mediaStatusDidUpdateNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func dequeueReusableViewController(with items: [GalleryItem], index: Int) -> GalleryItemViewController {
        self.items = items
        fetchMoreItemsAfter()
        fetchMoreItemsBefore()
        return dequeueReusableViewController(of: index)!
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
        case .recallMessage(let messageId):
            removeItem(messageId: messageId)
        default:
            break
        }
    }
    
    @objc private func updateDownloadProgress(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let messageId = userInfo[AttachmentLoadingJob.UserInfoKey.messageId] as? String,
            let progress = userInfo[AttachmentLoadingJob.UserInfoKey.progress] as? Double,
            let vc = reusableViewController(of: messageId)
        else {
            return
        }
        vc.operationButton.style = .busy(progress: progress)
    }
    
    @objc private func updateTranscriptMessageMediaStatus(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let transcriptId = userInfo[TranscriptMessageDAO.UserInfoKey.transcriptId] as? String,
            let messageId = userInfo[TranscriptMessageDAO.UserInfoKey.messageId] as? String,
            let mediaStatus = userInfo[TranscriptMessageDAO.UserInfoKey.mediaStatus] as? MediaStatus,
            let index = items.firstIndex(where: { $0.transcriptId == transcriptId && $0.messageId == messageId })
        else {
            return
        }
        items[index].mediaStatus = mediaStatus
        if let vc = reusableViewController(of: messageId) {
            vc.item = items[index]
        }
        if mediaStatus == .DONE {
            queue.async { [weak self] in
                guard
                    let message = TranscriptMessageDAO.shared.messageItem(transcriptId: transcriptId, messageId: messageId),
                    let item = GalleryItem(transcriptId: transcriptId, message: message)
                else {
                    return
                }
                DispatchQueue.main.sync {
                    guard let self = self else {
                        return
                    }
                    guard let index = self.items.firstIndex(where: { $0.messageId == message.messageId }) else {
                        return
                    }
                    let previousItem = self.items[index]
                    self.items[index] = item
                    if let vc = self.reusableViewController(of: messageId) {
                        vc.item = item
                        if previousItem.mediaStatus != .DONE && item.mediaStatus == .DONE, let controlView = (vc as? GalleryVideoItemViewController)?.controlView {
                            controlView.set(playControlsHidden: false, otherControlsHidden: true, animated: true)
                        }
                    }
                }
            }
        }
    }
    
    @objc private func updateMessageMediaStatus(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let messageId = userInfo[MessageDAO.UserInfoKey.messageId] as? String,
            let mediaStatus = userInfo[MessageDAO.UserInfoKey.mediaStatus] as? MediaStatus,
            let index = items.firstIndex(where: { $0.messageId == messageId })
        else {
            return
        }
        items[index].mediaStatus = mediaStatus
        if let vc = reusableViewController(of: messageId) {
            vc.item = items[index]
        }
    }
    
    private func fetchMoreItemsBefore() {
        guard let conversationId = conversationId else {
            return
        }
        guard !didLoadEarliestItem && !isLoadingBefore else {
            return
        }
        guard let location = items.first else {
            return
        }
        isLoadingBefore = true
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
        guard let conversationId = conversationId else {
            return
        }
        guard !didLoadLatestItem && !isLoadingAfter else {
            return
        }
        guard let location = items.last else {
            return
        }
        isLoadingAfter = true
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
