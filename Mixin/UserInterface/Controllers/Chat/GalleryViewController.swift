import UIKit
import SwiftMessages

protocol GalleryViewControllerDelegate: class {
    func galleryViewController(_ viewController: GalleryViewController, placeholderForItemOfMessageId id: String) -> UIImage?
    func galleryViewController(_ viewController: GalleryViewController, sourceRectForItemOfMessageId id: String) -> CGRect?
    func galleryViewController(_ viewController: GalleryViewController, transition: GalleryViewController.Transition, stateDidChangeTo state: GalleryViewController.TransitionState, forItemOfMessageId id: String?)
    func galleryViewController(_ viewController: GalleryViewController, snapshotForItemOfMessageId id: String) -> UIView?
    func animateAlongsideGalleryViewController(_ viewController: GalleryViewController, transition: GalleryViewController.Transition)
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
    private let transitionDummyView = ImageClippingView()
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
    private var snapshotView: UIView?
    
    private lazy var separatorWidth = scrollViewTrailingConstraint.constant
    
    private var safeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            var insets = view.safeAreaInsets
            if abs(insets.top - 20) < 0.1 {
                insets.top = max(0, insets.top - 20)
            }
            return insets
        } else {
            return .zero
        }
    }
    
    private var currentPage: GalleryItemViewController {
        assert(pages.count > 0)
        let i = pageIndex(ofContentOffsetX: scrollView.contentOffset.x)
        return pages[i]
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
            prepareTransitionDummyViewForDismissing()
            view.addSubview(transitionDummyView)
            scrollView.isHidden = true
            if let messageId = item?.messageId {
                snapshotView = delegate?.galleryViewController(self, snapshotForItemOfMessageId: messageId)
                delegate?.galleryViewController(self, transition: .dismiss, stateDidChangeTo: .began, forItemOfMessageId: messageId)
            }
        case .changed:
            transitionDummyView.frame.origin.y += recognizer.translation(in: view).y
            backgroundDimmingView.alpha = 1 - progress
            recognizer.setTranslation(.zero, in: view)
        case .cancelled, .ended:
            panToDismissDistance = 0
            if progress > 0.6 || recognizer.velocity(in: view).y > 800 {
                dismiss()
            } else {
                let safeAreaInsets = self.safeAreaInsets
                let y = max(0, (view.frame.height - safeAreaInsets.vertical - transitionDummyView.frame.height) / 2 + safeAreaInsets.top)
                UIView.animate(withDuration: animationDuration, animations: {
                    self.backgroundDimmingView.alpha = 1
                    self.transitionDummyView.frame.origin.y = y
                }, completion: { (_) in
                    self.scrollView.isHidden = false
                    self.transitionDummyView.transform = .identity
                    self.transitionDummyView.removeFromSuperview()
                    if let messageId = self.item?.messageId {
                        self.delegate?.galleryViewController(self, transition: .dismiss, stateDidChangeTo: .cancelled, forItemOfMessageId: messageId)
                    }
                    self.snapshotView = nil
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
                    SwiftMessages.showToast(message: Localized.NOT_MIXIN_QR_CODE, backgroundColor: .hintRed)
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
        var imageFinalFrame = CGRect.zero
        var sourceViewSnapshotView: UIView?
        self.delegate?.galleryViewController(self, transition: .show, stateDidChangeTo: .began, forItemOfMessageId: item.messageId)
        if let sourceRect = delegate?.galleryViewController(self, sourceRectForItemOfMessageId: item.messageId) {
            transitionDummyView.frame = sourceRect.insetBy(dx: ImageClippingView.clippingMargin.dx,
                                                            dy: ImageClippingView.clippingMargin.dy)
            transitionDummyView.imageView.image = delegate?.galleryViewController(self, placeholderForItemOfMessageId: item.messageId)
            transitionDummyView.imageView.frame = CGRect(x: -ImageClippingView.clippingMargin.dx,
                                                         y: -ImageClippingView.clippingMargin.dy,
                                                         width: sourceRect.width,
                                                         height: sourceRect.height)
            view.addSubview(transitionDummyView)
            if let snapshot = delegate?.galleryViewController(self, snapshotForItemOfMessageId: item.messageId) {
                snapshot.frame = sourceRect
                view.addSubview(snapshot)
                sourceViewSnapshotView = snapshot
            }
        }
        let safeAreaInsets = self.safeAreaInsets
        let containerSize = CGSize(width: view.frame.width - safeAreaInsets.horizontal,
                                   height: view.frame.height - safeAreaInsets.vertical)
        let containerRatio = containerSize.width / containerSize.height
        let itemRatio = item.size.width / item.size.height
        let size: CGSize, origin: CGPoint
        if itemRatio > containerRatio {
            size = CGSize(width: containerSize.width, height: ceil(containerSize.width / itemRatio))
            origin = CGPoint(x: 0, y: (containerSize.height - size.height) / 2)
        } else {
            size = CGSize(width: ceil(containerSize.height * itemRatio), height: containerSize.height)
            origin = CGPoint(x: (containerSize.width - size.width) / 2, y: 0)
        }
        imageFinalFrame = CGRect(origin: origin, size: size)
        let safeAreaOrigin = CGPoint(x: safeAreaInsets.left, y: safeAreaInsets.top)
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut, animations: {
            if let itemSize = self.item?.size, let snapshot = sourceViewSnapshotView {
                if self.currentItemIsVerticallyOversized {
                    let width = containerSize.height * (itemSize.width / itemSize.height)
                    let height = width * (snapshot.frame.height / snapshot.frame.width)
                    let x = (containerSize.width - width) / 2 + self.safeAreaInsets.left
                    let y = (containerSize.height - height) / 2 + self.safeAreaInsets.top
                    snapshot.frame = CGRect(x: x, y: y, width: width, height: height)
                } else {
                    snapshot.frame = CGRect(origin: safeAreaOrigin, size: containerSize)
                }
                snapshot.alpha = 0
            }
            self.backgroundDimmingView.alpha = 1
            self.transitionDummyView.frame = CGRect(origin: safeAreaOrigin, size: containerSize)
            self.transitionDummyView.imageView.frame = imageFinalFrame
            self.delegate?.animateAlongsideGalleryViewController(self, transition: .show)
        }, completion: { (_) in
            sourceViewSnapshotView?.removeFromSuperview()
            self.transitionDummyView.removeFromSuperview()
            self.scrollView.isHidden = false
            self.delegate?.galleryViewController(self, transition: .show, stateDidChangeTo: .ended, forItemOfMessageId: item.messageId)
        })
    }
    
    func dismiss() {
        scrollView.isHidden = true
        let messageId = item?.messageId
        if let messageId = messageId {
            self.delegate?.galleryViewController(self, transition: .dismiss, stateDidChangeTo: .began, forItemOfMessageId: messageId)
        }
        if transitionDummyView.superview == nil {
            prepareTransitionDummyViewForDismissing()
        } else {
            transitionDummyView.removeFromSuperview()
        }
        view.addSubview(transitionDummyView)
        var sourceViewSnapshotView: UIView?
        if let messageId = messageId, let snapshot = snapshotView ?? delegate?.galleryViewController(self, snapshotForItemOfMessageId: messageId) {
            let imageViewSize = transitionDummyView.frame.size
            let size = CGSize(width: imageViewSize.width, height: imageViewSize.width * snapshot.frame.height / snapshot.frame.width)
            let origin = CGPoint(x: (imageViewSize.width - size.width) / 2, y: (imageViewSize.height - size.height) / 2)
                + transitionDummyView.imageView.frame.origin
                + transitionDummyView.frame.origin
            snapshot.frame = CGRect(origin: origin, size: size)
            view.insertSubview(snapshot, belowSubview: transitionDummyView)
            sourceViewSnapshotView = snapshot
        }
        let frame = transitionDummyView.frame
        transitionDummyView.transform = .identity
        transitionDummyView.frame = frame
        transitionDummyView.imageView.frame = transitionDummyView.bounds
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
            self.backgroundDimmingView.alpha = 0
            if let item = self.item, let sourceRect = self.delegate?.galleryViewController(self, sourceRectForItemOfMessageId: item.messageId) {
                sourceViewSnapshotView?.frame = sourceRect
                self.transitionDummyView.frame = sourceRect
                if self.currentItemIsVerticallyOversized {
                    let itemRatio = item.size.width / item.size.height
                    let size = CGSize(width: sourceRect.width, height: sourceRect.width / itemRatio)
                    let origin = CGPoint(x: 0, y: (sourceRect.height - size.height) / 2)
                    self.transitionDummyView.imageView.frame = CGRect(origin: origin, size: size)
                } else {
                    self.transitionDummyView.imageView.frame = self.transitionDummyView.bounds
                }
            }
            self.transitionDummyView.alpha = 0
            self.delegate?.animateAlongsideGalleryViewController(self, transition: .dismiss)
        }, completion: { (_) in
            sourceViewSnapshotView?.removeFromSuperview()
            self.transitionDummyView.removeFromSuperview()
            self.scrollView.isHidden = false
            self.transitionDummyView.alpha = 1
            self.delegate?.galleryViewController(self, transition: .dismiss, stateDidChangeTo: .ended, forItemOfMessageId: messageId)
            self.snapshotView = nil
        })
    }
    
    class func instance(conversationId: String) -> GalleryViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "photo_preview") as! GalleryViewController
        vc.conversationId = conversationId
        return vc
    }
    
}

extension GalleryViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let x = scrollView.contentOffset.x
        let conversationId = self.conversationId!
        let itemsCountPerFetch = self.itemsCountPerFetch
        if x > pageSize.width * 1.5 + separatorWidth && x > lastContentOffsetX, let item = pages[2].item {
            // Scrolling rightwards
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
                    let itemsAfter = MessageDAO.shared.getPhotos(conversationId: conversationId, location: lastItem, count: itemsCountPerFetch)
                    DispatchQueue.main.sync {
                        if itemsAfter.count > 0 {
                            self?.items += itemsAfter
                        }
                        self?.isLoadingAfter = false
                    }
                }
            }
        } else if x < pageSize.width * 0.5 && x < lastContentOffsetX, let item = pages[0].item {
            // Scrolling leftwards
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
                    let itemsBefore = MessageDAO.shared.getPhotos(conversationId: conversationId, location: firstItem, count: -itemsCountPerFetch)
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

extension GalleryViewController: UIGestureRecognizerDelegate {
    
    var pageDidReachTopEdge: Bool {
        return currentPage.scrollView.contentOffset.y <= 0.1
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panRecognizer else {
            return true
        }
        return panRecognizer.velocity(in: view).y > 0
            && abs(panRecognizer.velocity(in: view).y) > abs(panRecognizer.velocity(in: view).x)
            && pageDidReachTopEdge
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        let otherGestureRecognizerIsOneOfScrollViewRecognizers = scrollView.gestureRecognizers?.contains(otherGestureRecognizer) ?? false
        if gestureRecognizer == panRecognizer, pageDidReachTopEdge, !otherGestureRecognizerIsOneOfScrollViewRecognizers {
            return true
        } else {
            return false
        }
    }
    
}

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
        pages[0].item = item
        scrollViewContentView.frame = CGRect(origin: .zero, size: pageSize)
        scrollView.contentSize = pageSize
        lastContentOffsetX = 0
        scrollView.contentOffset.x = 0
        let conversationId = self.conversationId!
        let itemsCountPerFetch = self.itemsCountPerFetch
        queue.async { [weak self] in
            guard self != nil else {
                return
            }
            let itemsBefore = MessageDAO.shared.getPhotos(conversationId: conversationId, location: item, count: -itemsCountPerFetch / 2)
            let itemsAfter = MessageDAO.shared.getPhotos(conversationId: conversationId, location: item, count: itemsCountPerFetch / 2)
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
        let scrollViewContentWidth = CGFloat(pageItems.count) * (pageSize.width + separatorWidth)
        scrollViewContentView.frame = CGRect(x: 0, y: 0, width: scrollViewContentWidth, height: pageSize.height)
        scrollView.contentSize = scrollViewContentView.frame.size
        lastContentOffsetX = CGFloat(initialIndex) * (pageSize.width + separatorWidth)
        scrollView.contentOffset.x = lastContentOffsetX
        for (index, item) in pageItems.enumerated() {
            pages[index].item = item
        }
    }
    
    private func prepareTransitionDummyViewForDismissing() {
        transitionDummyView.transform = .identity
        let image = currentPage.imageView.image
        transitionDummyView.imageView.image = image
        if let image = image {
            transitionDummyView.frame.size = image.size
            transitionDummyView.imageView.frame = CGRect(origin: .zero, size: image.size)
            transitionDummyView.transform = CGAffineTransform(scaleX: currentPage.imageView.frame.width / image.size.width,
                                                              y: currentPage.imageView.frame.height / image.size.height)
            transitionDummyView.frame.origin = currentPage.imageView.convert(CGPoint.zero, to: view)
        } else {
            transitionDummyView.frame = view.bounds
            transitionDummyView.imageView.frame = view.bounds
        }
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
