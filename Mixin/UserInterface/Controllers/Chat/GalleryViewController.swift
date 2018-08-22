import UIKit
import SwiftMessages
import AVKit

protocol GalleryViewControllerDelegate: class {
    func galleryViewController(_ viewController: GalleryViewController, placeholderForItemOfMessageId id: String) -> UIImage?
    func galleryViewController(_ viewController: GalleryViewController, sourceRectForItemOfMessageId id: String) -> CGRect?
    func galleryViewController(_ viewController: GalleryViewController, snapshotForItemOfMessageId id: String) -> UIView?
    func galleryViewController(_ viewController: GalleryViewController, willShowForItemOfMessageId id: String?)
    func galleryViewController(_ viewController: GalleryViewController, didShowForItemOfMessageId id: String?)
    func galleryViewController(_ viewController: GalleryViewController, willDismissForItemOfMessageId id: String?)
    func galleryViewController(_ viewController: GalleryViewController, didDismissForItemOfMessageId id: String?)
    func galleryViewController(_ viewController: GalleryViewController, willBeginInteractivelyDismissingForItemOfMessageId id: String?)
    func galleryViewController(_ viewController: GalleryViewController, didCancelInteractivelyDismissingForItemOfMessageId id: String?)
}

class GalleryViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var backgroundDimmingView: UIView!
    @IBOutlet weak var scrollViewTrailingConstraint: NSLayoutConstraint!
    
    @IBOutlet var tapRecognizer: UITapGestureRecognizer!
    @IBOutlet var doubleTapRecognizer: UITapGestureRecognizer!
    @IBOutlet var panRecognizer: UIPanGestureRecognizer!
    @IBOutlet var longPressRecognizer: UILongPressGestureRecognizer!
    
    weak var delegate: GalleryViewControllerDelegate?
    var item: GalleryItem?
    
    private let scrollViewContentView = UIView()
    private let animationDuration: TimeInterval = 0.25
    private let itemsCountPerFetch = 20
    private let queue = DispatchQueue(label: "one.mixin.ios.gallery")
    private let pageSize = UIScreen.main.bounds.size
    
    private var conversationId: String!
    private var pages = [GalleryItemViewController.instance(),
                         GalleryItemViewController.instance(),
                         GalleryItemViewController.instance()]
    private var lastContentOffsetX: CGFloat = 0
    private var panToDismissDistance: CGFloat = 0
    private var items = [GalleryItem]()
    private var didLoadEarliestItem = false
    private var isLoadingBefore = false
    private var isLoadingAfter = false
    private var transitionView: UIView!
    private var snapshotView: UIView?
    
    private let imageClippingTransitionView = ImageClippingView()
    private lazy var separatorWidth = scrollViewTrailingConstraint.constant
    
    private var safeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return view.safeAreaInsets
        } else {
            return .zero
        }
    }
    
    private var currentPage: GalleryItemViewController {
        assert(pages.count > 0)
        let i = pageIndex(ofContentOffsetX: scrollView.contentOffset.x)
        return pages[i]
    }
    
    private var shouldLayoutCurrentItemAsArticle: Bool {
        return item?.shouldLayoutAsArticle ?? false
    }
    
    var shouldPerformMagicMoveTransitionForCurrentItem: Bool {
        return !shouldLayoutCurrentItemAsArticle
            || self.currentPage.scrollView.contentOffset.y <= 1
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scrollViewContentView.backgroundColor = .clear
        scrollView.addSubview(scrollViewContentView)
        for page in pages {
            addChildViewController(page)
            page.view.autoresizingMask = []
            scrollViewContentView.addSubview(page.view)
            page.didMove(toParentViewController: self)
        }
        layoutPages()
        scrollView.delegate = self
        panRecognizer.delegate = self
        longPressRecognizer.delegate = self
        tapRecognizer.require(toFail: doubleTapRecognizer)
        panRecognizer.require(toFail: longPressRecognizer)
        NotificationCenter.default.addObserver(self, selector: #selector(conversationDidChange(_:)), name: .ConversationDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func tapAction(_ recognizer: UITapGestureRecognizer) {
        dismiss()
    }
    
    @IBAction func doubleTapAction(_ recognizer: UIGestureRecognizer) {
        currentPage.zoom(location: recognizer.location(in: currentPage.scrollView))
    }
    
    @IBAction func panAction(_ recognizer: UIPanGestureRecognizer) {
        panToDismissDistance += recognizer.translation(in: view).y
        let progress = min(1, max(0, panToDismissDistance / (view.bounds.height / 3)))
        switch recognizer.state {
        case .began:
            delegate?.galleryViewController(self, willBeginInteractivelyDismissingForItemOfMessageId: item?.messageId)
            prepareTransitionViewForDismissing()
            scrollView.isHidden = true
            if let messageId = item?.messageId {
                snapshotView = delegate?.galleryViewController(self, snapshotForItemOfMessageId: messageId)
            }
        case .changed:
            transitionView.frame.origin.y += recognizer.translation(in: view).y
            backgroundDimmingView.alpha = 1 - progress
            recognizer.setTranslation(.zero, in: view)
        case .cancelled, .ended:
            panToDismissDistance = 0
            if progress > 0.6 || recognizer.velocity(in: view).y > 800 {
                dismiss()
            } else {
                let y = max(-currentPage.scrollView.contentOffset.y, (view.frame.height - transitionView.frame.height) / 2)
                UIView.animate(withDuration: animationDuration, animations: {
                    self.backgroundDimmingView.alpha = 1
                    self.transitionView.frame.origin.y = y
                }, completion: { (_) in
                    self.scrollView.isHidden = false
                    self.transitionView.removeFromSuperview()
                    if let videoView = self.transitionView as? GalleryVideoView {
                        self.currentPage.view.insertSubview(videoView, belowSubview: self.currentPage.videoControlPanelView)
                    }
                    self.snapshotView = nil
                    self.delegate?.galleryViewController(self, didCancelInteractivelyDismissingForItemOfMessageId: self.item?.messageId)
                })
            }
        case .possible, .failed:
            break
        }
    }
    
    @IBAction func longPressAction(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.CHAT_PHOTO_SAVE, style: .default, handler: { [weak self] (_) in
            self?.currentPage.saveToLibrary()
        }))
        if let url = currentPage.urlFromQRCode {
            alc.addAction(UIAlertAction(title: Localized.SCAN_QR_CODE, style: .default, handler: { (_) in
                if !UrlWindow.checkUrl(url: url, clearNavigationStack: false) {
                    RecognizeWindow.instance().presentWindow(text: url.absoluteString)
                }
            }))
        }
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(alc, animated: true, completion: nil)
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
        default:
            break
        }
    }
    
    func show(item: GalleryItem) {
        self.item = item
        reload()
        backgroundDimmingView.alpha = 0
        scrollView.isHidden = true
        var sourceViewSnapshotView: UIView?
        if let sourceRect = delegate?.galleryViewController(self, sourceRectForItemOfMessageId: item.messageId) {
            imageClippingTransitionView.frame = sourceRect.insetBy(dx: ImageClippingView.clippingMargin.dx,
                                                                   dy: ImageClippingView.clippingMargin.dy)
            let placeholder = delegate?.galleryViewController(self, placeholderForItemOfMessageId: item.messageId)
            imageClippingTransitionView.imageView.image = placeholder
            if let ratio = placeholder?.size {
                imageClippingTransitionView.imageView.frame.size = CGSize(width: sourceRect.width, height: sourceRect.width * ratio.height / ratio.width)
            } else {
                imageClippingTransitionView.imageView.frame.size = sourceRect.size
            }
            imageClippingTransitionView.imageView.frame.origin.x = -ImageClippingView.clippingMargin.dx
            if item.shouldLayoutAsArticle {
                imageClippingTransitionView.imageView.frame.origin.y = -ImageClippingView.clippingMargin.dy
            } else {
                imageClippingTransitionView.imageView.frame.origin.y = -max(0, (imageClippingTransitionView.imageView.frame.height - imageClippingTransitionView.frame.height) / 2)
            }
            view.addSubview(imageClippingTransitionView)
            if let snapshot = delegate?.galleryViewController(self, snapshotForItemOfMessageId: item.messageId) {
                snapshot.frame = sourceRect
                view.addSubview(snapshot)
                sourceViewSnapshotView = snapshot
            }
        }
        let containerSize = UIScreen.main.bounds.size
        let imageFinalFrame: CGRect
        if item.shouldLayoutAsArticle {
            imageFinalFrame = CGRect(x: 0, y: 0, width: containerSize.width, height: containerSize.width * item.size.height / item.size.width)
        } else {
            imageFinalFrame = item.size.rect(fittingSize: containerSize)
        }
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut, animations: {
            self.delegate?.galleryViewController(self, willShowForItemOfMessageId: item.messageId)
            if let itemSize = self.item?.size, let snapshot = sourceViewSnapshotView {
                if item.shouldLayoutAsArticle {
                    let snapshotHeight = imageFinalFrame.width * snapshot.frame.height / snapshot.frame.width
                    snapshot.frame = CGRect(x: 0, y: 0, width: imageFinalFrame.width, height: snapshotHeight)
                } else if self.currentItemIsVerticallyOversized {
                    let width = containerSize.height * (itemSize.width / itemSize.height)
                    let height = width * (snapshot.frame.height / snapshot.frame.width)
                    let x = (containerSize.width - width) / 2
                    let y = (containerSize.height - height) / 2
                    snapshot.frame = CGRect(x: x, y: y, width: width, height: height)
                } else {
                    snapshot.frame = CGRect(origin: .zero, size: containerSize)
                }
                snapshot.alpha = 0
            }
            self.backgroundDimmingView.alpha = 1
            self.imageClippingTransitionView.frame = CGRect(origin: .zero, size: containerSize)
            self.imageClippingTransitionView.imageView.frame = imageFinalFrame
        }, completion: { (_) in
            sourceViewSnapshotView?.removeFromSuperview()
            self.imageClippingTransitionView.removeFromSuperview()
            self.scrollView.isHidden = false
            self.delegate?.galleryViewController(self, didShowForItemOfMessageId: item.messageId)
        })
    }
    
    func dismiss() {
        currentPage.stopVideoPlayingAndRemoveObservers()
        scrollView.isHidden = true
        let messageId = item?.messageId
        let shouldLayoutAsArticle = self.shouldLayoutCurrentItemAsArticle
        let shouldPerformMagicMoveTransition = self.shouldPerformMagicMoveTransitionForCurrentItem
        if transitionView == nil {
            prepareTransitionViewForDismissing()
        }
        var sourceViewSnapshotView: UIView?
        if shouldPerformMagicMoveTransitionForCurrentItem, let messageId = messageId, let snapshot = snapshotView ?? delegate?.galleryViewController(self, snapshotForItemOfMessageId: messageId) {
            let imageViewSize = transitionView.frame.size
            let size = CGSize(width: imageViewSize.width, height: imageViewSize.width * snapshot.frame.height / snapshot.frame.width)
            var origin = ((transitionView as? ImageClippingView)?.imageView.frame.origin ?? .zero)
                + transitionView.frame.origin
            if !shouldLayoutAsArticle {
                origin = origin + CGPoint(x: (imageViewSize.width - size.width) / 2,
                                          y: (imageViewSize.height - size.height) / 2)
            }
            snapshot.frame = CGRect(origin: origin, size: size)
            view.insertSubview(snapshot, belowSubview: transitionView)
            sourceViewSnapshotView = snapshot
        }
        let frame = transitionView.frame
        transitionView.transform = .identity
        transitionView.frame = frame
        (transitionView as? ImageClippingView)?.imageView.frame = transitionView.bounds
        UIView.animate(withDuration: animationDuration, delay: 0, options: [.curveEaseInOut, .layoutSubviews], animations: {
            self.delegate?.galleryViewController(self, willDismissForItemOfMessageId: messageId)
            self.backgroundDimmingView.alpha = 0
            if shouldPerformMagicMoveTransition, let item = self.item, let sourceRect = self.delegate?.galleryViewController(self, sourceRectForItemOfMessageId: item.messageId) {
                sourceViewSnapshotView?.frame = sourceRect
                self.transitionView.frame = sourceRect
                if item.category == .image {
                    if shouldLayoutAsArticle {
                        let size = CGSize(width: self.transitionView.bounds.width,
                                          height: self.transitionView.bounds.width * item.size.height / item.size.width)
                        self.imageClippingTransitionView.imageView.frame = CGRect(origin: .zero, size: size)
                    } else if self.currentItemIsVerticallyOversized {
                        let itemRatio = item.size.width / item.size.height
                        let size = CGSize(width: sourceRect.width, height: sourceRect.width / itemRatio)
                        let origin = CGPoint(x: 0, y: (sourceRect.height - size.height) / 2)
                        self.imageClippingTransitionView.imageView.frame = CGRect(origin: origin, size: size)
                    } else {
                        self.imageClippingTransitionView.imageView.frame = self.transitionView.bounds
                    }
                }
            }
            self.transitionView.alpha = 0
        }, completion: { (_) in
            sourceViewSnapshotView?.removeFromSuperview()
            self.transitionView.removeFromSuperview()
            if let videoView = self.transitionView as? GalleryVideoView {
                self.currentPage.view.insertSubview(videoView, belowSubview: self.currentPage.videoControlPanelView)
            }
            self.scrollView.isHidden = false
            self.transitionView.alpha = 1
            self.transitionView = nil
            self.delegate?.galleryViewController(self, didDismissForItemOfMessageId: messageId)
            self.snapshotView = nil
            for page in self.pages {
                page.item = nil
            }
        })
    }
    
    class func instance(conversationId: String) -> GalleryViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "photo_preview") as! GalleryViewController
        vc.conversationId = conversationId
        return vc
    }
    
}

// MARK: - UIScrollViewDelegate
extension GalleryViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let x = scrollView.contentOffset.x
        let conversationId = self.conversationId!
        let itemsCountPerFetch = self.itemsCountPerFetch
        if x > pageSize.width * 1.5 + separatorWidth && x > lastContentOffsetX, let item = pages[2].item {
            if let itemAfter = items.element(after: item) {
                let page = pages.remove(at: 0)
                page.item = itemAfter
                pages.append(page)
                layoutPages()
                scrollView.bounds.origin.x -= pageSize.width + separatorWidth
            } else if !isLoadingAfter, let lastItem = items.last {
                isLoadingAfter = true
                queue.async { [weak self] in
                    guard self != nil else {
                        return
                    }
                    let itemsAfter = MessageDAO.shared.getGalleryItems(conversationId: conversationId, location: lastItem, count: itemsCountPerFetch)
                    DispatchQueue.main.sync {
                        if itemsAfter.count > 0 {
                            self?.items += itemsAfter
                        }
                        self?.isLoadingAfter = false
                    }
                }
            }
        } else if x < pageSize.width * 0.5 && x < lastContentOffsetX, let item = pages[0].item {
            if let itemBefore = items.element(before: item) {
                let page = pages.remove(at: 2)
                page.item = itemBefore
                pages.insert(page, at: 0)
                layoutPages()
                scrollView.bounds.origin.x += pageSize.width + separatorWidth
            } else if !isLoadingBefore && !didLoadEarliestItem, let firstItem = items.first {
                isLoadingBefore = true
                queue.async { [weak self] in
                    guard self != nil else {
                        return
                    }
                    let itemsBefore = MessageDAO.shared.getGalleryItems(conversationId: conversationId, location: firstItem, count: -itemsCountPerFetch)
                    DispatchQueue.main.sync {
                        if itemsBefore.count > 0 {
                            self?.items.insert(contentsOf: itemsBefore, at: 0)
                        }
                        self?.didLoadEarliestItem = itemsBefore.count < itemsCountPerFetch
                        self?.isLoadingBefore = false
                    }
                }
            }
        }
        for page in pages {
            page.isFocused = page == currentPage
        }
        lastContentOffsetX = x
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            item = currentPage.item
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        item = currentPage.item
    }
    
}

// MARK: - UIGestureRecognizerDelegate
extension GalleryViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panRecognizer else {
            return true
        }
        return panRecognizer.velocity(in: view).y > 0
            && abs(panRecognizer.velocity(in: view).y) > abs(panRecognizer.velocity(in: view).x)
            && currentPage.canPerformInteractiveDismissing
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        let otherGestureRecognizerIsOneOfScrollViewRecognizers = scrollView.gestureRecognizers?.contains(otherGestureRecognizer) ?? false
        if gestureRecognizer == panRecognizer, currentPage.canPerformInteractiveDismissing, !otherGestureRecognizerIsOneOfScrollViewRecognizers {
            return true
        } else {
            return false
        }
    }
    
}

// MARK: - Private works
extension GalleryViewController {
    
    private var currentItemIsVerticallyOversized: Bool {
        guard let item = item else {
            return false
        }
        return item.size.width / item.size.height < PhotoMessageViewModel.contentWidth / PhotoMessageViewModel.maxHeight
    }
    
    private func layoutPages() {
        for (index, page) in pages.enumerated() {
            let origin = CGPoint(x: CGFloat(index) * (pageSize.width + separatorWidth), y: 0)
            page.view.frame = CGRect(origin: origin, size: pageSize)
        }
    }
    
    private func pageIndex(ofContentOffsetX x: CGFloat) -> Int {
        guard pages.count > 1 else {
            return 0
        }
        for i in 0...(pages.count - 1) {
            if x < (CGFloat(i) * pageSize.width + (CGFloat(i) + 0.5) * separatorWidth) {
                return i
            }
        }
        return max(0, pages.count - 1)
    }
    
    private func reload() {
        guard let item = item else {
            return
        }
        isLoadingBefore = true
        isLoadingAfter = true
        pages[0].isFocused = true
        pages[0].item = item
        scrollViewContentView.frame = CGRect(origin: .zero, size: pageSize)
        lastContentOffsetX = 0
        scrollView.contentOffset.x = 0
        scrollView.contentSize = pageSize
        let conversationId = self.conversationId!
        let itemsCountPerFetch = self.itemsCountPerFetch
        queue.async { [weak self] in
            guard self != nil else {
                return
            }
            let itemsBefore = MessageDAO.shared.getGalleryItems(conversationId: conversationId, location: item, count: -itemsCountPerFetch / 2)
            let itemsAfter = MessageDAO.shared.getGalleryItems(conversationId: conversationId, location: item, count: itemsCountPerFetch / 2)
            DispatchQueue.main.sync {
                self?.items = itemsBefore + [item] + itemsAfter
                self?.reloadPages()
                self?.isLoadingBefore = false
                self?.isLoadingAfter = false
            }
        }
    }
    
    private func reloadPages() {
        guard let item = item else {
            return
        }
        var pageItems = [item]
        var initialIndex = 0
        if let before = items.element(before: item) {
            pageItems.insert(before, at: 0)
            initialIndex = 1
            if let after = items.element(after: item) {
                pageItems.append(after)
            } else if let beforeBefore = items.element(before: before) {
                pageItems.insert(beforeBefore, at: 0)
                initialIndex = 2
            }
        } else if let after = items.element(after: item) {
            pageItems.append(after)
            if let afterAfter = items.element(after: after) {
                pageItems.append(afterAfter)
            }
        }
        if let loadedIndex = pageItems.index(of: item) {
            // Reuse loaded page
            pages.swapAt(0, loadedIndex)
            layoutPages()
        }
        let scrollViewContentWidth = CGFloat(pageItems.count) * (pageSize.width + separatorWidth)
        scrollViewContentView.frame = CGRect(x: 0, y: 0, width: scrollViewContentWidth, height: pageSize.height)
        scrollView.contentSize = scrollViewContentView.frame.size
        lastContentOffsetX = CGFloat(initialIndex) * (pageSize.width + separatorWidth)
        scrollView.contentOffset.x = lastContentOffsetX

        for (index, item) in pageItems.enumerated() {
            pages[index].isFocused = index == initialIndex
            pages[index].item = item
        }
    }
    
    private func prepareTransitionViewForDismissing() {
        if item?.category == .image || item?.url == nil {
            imageClippingTransitionView.transform = .identity
            let image = currentPage.imageView.image
            imageClippingTransitionView.imageView.image = image
            if let image = image {
                imageClippingTransitionView.frame.size = image.size
                imageClippingTransitionView.imageView.frame = CGRect(origin: .zero, size: image.size)
                imageClippingTransitionView.transform = CGAffineTransform(scaleX: currentPage.imageView.frame.width / image.size.width,
                                                                          y: currentPage.imageView.frame.height / image.size.height)
                imageClippingTransitionView.frame.origin = currentPage.imageView.convert(CGPoint.zero, to: view)
            } else {
                imageClippingTransitionView.frame = view.bounds
                imageClippingTransitionView.imageView.frame = view.bounds
            }
            transitionView = imageClippingTransitionView
        } else {
            currentPage.videoView.removeFromSuperview()
            transitionView = currentPage.videoView
        }
        view.addSubview(transitionView)
    }
    
    private func updateMessage(messageId: String) {
        guard items.contains(where: { $0.messageId == messageId }) else {
            return
        }
        queue.async { [weak self] in
            guard self != nil else {
                return
            }
            guard let message = MessageDAO.shared.getMessage(messageId: messageId), let item = GalleryItem(message: message) else {
                return
            }
            DispatchQueue.main.sync {
                if let index = self?.items.index(where: { $0.messageId == message.messageId }) {
                    self?.items[index] = item
                }
                if let index = self?.pages.index(where: { $0.item?.messageId == message.messageId }) {
                    self?.pages[index].item = item
                }
            }
        }
    }
    
    private func updateDownloadProgress(messageId: String, progress: Double) {
        guard let page = pages.first(where: { $0.item?.messageId == messageId }) else {
            return
        }
        page.operationButton.style = .busy(progress: progress)
    }
    
    private func updateMediaStatus(messageId: String, mediaStatus: MediaStatus) {
        guard let index = items.index(where: { $0.messageId == messageId }) else {
            return
        }
        items[index].mediaStatus = mediaStatus
        if let page = pages.first(where: { $0.item?.messageId == messageId }) {
            page.item = items[index]
        }
    }
    
}

// MARK: - Embedded classes
extension GalleryViewController {
    
    enum Transition {
        case show
        case dismiss
    }
    
    enum TransitionState {
        case began
        case ended
        case cancelled
    }
    
    class ImageClippingView: UIView {
        
        static let clippingMargin = CGVector(dx: 10, dy: 10)
        
        let imageView = UIImageView()
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            prepare()
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            prepare()
        }
        
        private func prepare() {
            imageView.contentMode = .scaleAspectFill
            addSubview(imageView)
            clipsToBounds = true
        }
        
    }
    
}
