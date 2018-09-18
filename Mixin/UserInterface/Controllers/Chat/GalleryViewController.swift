import UIKit
import SwiftMessages
import AVKit

protocol GalleryViewControllerDelegate: class {
    func galleryViewController(_ viewController: GalleryViewController, showContextForItemOfMessageId id: String) -> GalleryViewController.ShowContext?
    func galleryViewController(_ viewController: GalleryViewController, dismissContextForItemOfMessageId id: String) -> GalleryViewController.DismissContext?
    func galleryViewController(_ viewController: GalleryViewController, willShowForItemOfMessageId id: String?)
    func galleryViewController(_ viewController: GalleryViewController, didShowForItemOfMessageId id: String?)
    func galleryViewController(_ viewController: GalleryViewController, willDismissForItemOfMessageId id: String?)
    func galleryViewController(_ viewController: GalleryViewController, willDismissArticleForItemOfMessageId id: String?, atRelativeOffset offset: CGFloat)
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
    
    private let imageClippingTransitionView = ImageTransitionView()
    private let bubbleMaskLayer = BubbleLayer()
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layoutIfNeeded()
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
                    self.transitionView = nil
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
    
    func show(item: GalleryItem, offset: CGFloat) {
        self.item = item
        reload()
        backgroundDimmingView.alpha = 0
        scrollView.isHidden = true
        let context = delegate?.galleryViewController(self, showContextForItemOfMessageId: item.messageId)
        if let sourceFrame = context?.sourceFrame {
            imageClippingTransitionView.frame = sourceFrame
            imageClippingTransitionView.imageView.image = context?.placeholder
            if let ratio = context?.placeholder?.size {
                imageClippingTransitionView.imageView.frame.size = CGSize(width: sourceFrame.width,
                                                                          height: sourceFrame.width * ratio.height / ratio.width)
            } else {
                imageClippingTransitionView.imageView.frame.size = sourceFrame.size
            }
            if item.shouldLayoutAsArticle {
                let origin = CGPoint(x: 0, y: offset * imageClippingTransitionView.imageView.frame.height)
                imageClippingTransitionView.imageView.frame.origin = origin
            } else {
                imageClippingTransitionView.imageView.center = CGPoint(x: sourceFrame.width / 2,
                                                                       y: sourceFrame.height / 2)
            }
            view.addSubview(imageClippingTransitionView)
        }
        bubbleMaskLayer.frame = imageClippingTransitionView.bounds
        if let style = context?.viewModel.style {
            let bubble = BubbleLayer.Bubble(style: style)
            bubbleMaskLayer.setBubble(bubble, frame: imageClippingTransitionView.bounds, animationDuration: 0)
        }
        imageClippingTransitionView.layer.mask = bubbleMaskLayer
        let containerSize = UIScreen.main.bounds.size
        let imageFinalFrame: CGRect
        if item.shouldLayoutAsArticle {
            let size = CGSize(width: containerSize.width, height: containerSize.width * item.size.height / item.size.width)
            let origin = CGPoint(x: 0, y: offset * size.height)
            imageFinalFrame = CGRect(origin: origin, size: size)
        } else {
            imageFinalFrame = item.size.rect(fittingSize: containerSize)
        }
        let transitionViewFinalFrame = CGRect(origin: .zero, size: containerSize)
        let bottomRightImageViewFinalFrame: CGRect?
        if let snapshot = context?.statusSnapshot {
            imageClippingTransitionView.bottomRightImageView.image = snapshot
            imageClippingTransitionView.bottomRightImageView.frame = CGRect(origin: .zero, size: snapshot.size)
            imageClippingTransitionView.bottomRightImageView.alpha = 1
            let scale = imageFinalFrame.width / imageClippingTransitionView.frame.width
            let size = CGSize(width: snapshot.size.width * scale, height: snapshot.size.height * scale)
            let origin = CGPoint(x: 0, y: max(0, containerSize.height - imageFinalFrame.size.height) / 2)
            bottomRightImageViewFinalFrame = CGRect(origin: origin, size: size)
        } else {
            bottomRightImageViewFinalFrame = nil
        }
        let bubbleFinalFrame = transitionViewFinalFrame.height > imageFinalFrame.height ? imageFinalFrame : transitionViewFinalFrame
        bubbleMaskLayer.setBubble(.none, frame: bubbleFinalFrame, animationDuration: animationDuration)
        UIView.animate(withDuration: animationDuration, delay: 0, options: [.curveEaseInOut, .layoutSubviews], animations: {
            self.delegate?.galleryViewController(self, willShowForItemOfMessageId: item.messageId)
            self.backgroundDimmingView.alpha = 1
            self.imageClippingTransitionView.frame = transitionViewFinalFrame
            self.imageClippingTransitionView.imageView.frame = imageFinalFrame
            self.imageClippingTransitionView.bottomRightImageView.alpha = 0
            if let frame = bottomRightImageViewFinalFrame {
                self.imageClippingTransitionView.bottomRightImageView.frame = frame
            }
        }, completion: { (_) in
            self.currentPage.scrollView.contentOffset.y = -offset * self.currentPage.scrollView.contentSize.height
            self.imageClippingTransitionView.removeFromSuperview()
            self.imageClippingTransitionView.layer.mask = nil
            self.scrollView.isHidden = false
            self.delegate?.galleryViewController(self, didShowForItemOfMessageId: item.messageId)
        })
    }
    
    func dismiss() {
        currentPage.stopVideoPlayingAndRemoveObservers()
        scrollView.isHidden = true
        let messageId = item?.messageId
        let shouldLayoutAsArticle = self.shouldLayoutCurrentItemAsArticle
        if transitionView == nil {
            prepareTransitionViewForDismissing()
        }
        let maxRelativeOffset = (currentPage.scrollView.contentSize.height / currentPage.scrollView.zoomScale - currentPage.scrollView.frame.height) / (currentPage.scrollView.contentSize.height / currentPage.scrollView.zoomScale)
        let relativeOffset = -min(maxRelativeOffset, currentPage.scrollView.contentOffset.y / currentPage.scrollView.contentSize.height)
        if shouldLayoutAsArticle {
            delegate?.galleryViewController(self, willDismissArticleForItemOfMessageId: messageId, atRelativeOffset: relativeOffset)
        }
        if transitionView.transform != .identity {
            let frame = transitionView.frame
            transitionView.transform = .identity
            transitionView.frame = frame
        }
        let bubbleMaskFrame = CGRect(origin: .zero, size: transitionView.frame.size)
        bubbleMaskLayer.frame = bubbleMaskFrame
        bubbleMaskLayer.setBubble(.none, frame: bubbleMaskFrame, animationDuration: 0)
        transitionView.layer.mask = bubbleMaskLayer
        if let imageView = (transitionView as? ImageTransitionView)?.imageView {
            var origin = currentPage.imageView.convert(CGPoint.zero, to: transitionView)
            if currentPage.scrollView.contentOffset.y <= 0 {
                origin.y = 0
            }
            imageView.frame = CGRect(origin: origin, size: currentPage.imageView.frame.size)
        }
        let sourceFrame: CGRect?
        if let messageId = messageId, let context = delegate?.galleryViewController(self, dismissContextForItemOfMessageId: messageId) {
            sourceFrame = context.sourceFrame
            if let sourceFrame = sourceFrame {
                let style = context.viewModel.style
                let bubble = BubbleLayer.Bubble(style: style)
                bubbleMaskLayer.frame = transitionView.bounds
                let frame = CGRect(origin: .zero, size: sourceFrame.size)
                bubbleMaskLayer.setBubble(bubble, frame: frame, animationDuration: animationDuration)
            }
            if let snapshot = context.statusSnapshot {
                imageClippingTransitionView.bottomRightImageView.image = snapshot
                let size = CGSize(width: transitionView.frame.width, height: transitionView.frame.width * snapshot.size.height / snapshot.size.width)
                imageClippingTransitionView.bottomRightImageView.frame = CGRect(origin: .zero, size: size)
            }
        } else {
            sourceFrame = nil
        }
        if imageClippingTransitionView.frame.height - UIScreen.main.bounds.height > -0.1 {
            backgroundDimmingView.alpha = min(0.4, backgroundDimmingView.alpha)
        }
        UIView.animate(withDuration: animationDuration, delay: 0, options: [.curveEaseInOut, .layoutSubviews], animations: {
            self.delegate?.galleryViewController(self, willDismissForItemOfMessageId: messageId)
            self.backgroundDimmingView.alpha = 0
            if let item = self.item, let sourceFrame = sourceFrame {
                self.transitionView.frame = sourceFrame
                if item.category == .image {
                    if shouldLayoutAsArticle {
                        let size = CGSize(width: self.transitionView.bounds.width,
                                          height: self.transitionView.bounds.width * item.size.height / item.size.width)
                        let origin = CGPoint(x: 0, y: relativeOffset * size.height)
                        self.imageClippingTransitionView.imageView.frame = CGRect(origin: origin, size: size)
                    } else if self.currentItemIsVerticallyOversized {
                        let itemRatio = item.size.width / item.size.height
                        let size = CGSize(width: sourceFrame.width, height: sourceFrame.width / itemRatio)
                        let origin = CGPoint(x: 0, y: (sourceFrame.height - size.height) / 2)
                        self.imageClippingTransitionView.imageView.frame = CGRect(origin: origin, size: size)
                    } else {
                        self.imageClippingTransitionView.imageView.frame = self.transitionView.bounds
                    }
                    self.imageClippingTransitionView.bottomRightImageView.frame = CGRect(origin: .zero, size: sourceFrame.size)
                }
                self.imageClippingTransitionView.bottomRightImageView.alpha = 1
            } else {
                self.transitionView.alpha = 0
            }
        }, completion: { (_) in
            self.transitionView.removeFromSuperview()
            if let videoView = self.transitionView as? GalleryVideoView {
                self.currentPage.view.insertSubview(videoView, belowSubview: self.currentPage.videoControlPanelView)
            }
            self.scrollView.isHidden = false
            self.transitionView.alpha = 1
            self.transitionView = nil
            self.delegate?.galleryViewController(self, didDismissForItemOfMessageId: messageId)
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
                let transform = CGAffineTransform(scaleX: currentPage.imageView.frame.width / image.size.width,
                                                  y: currentPage.imageView.frame.height / image.size.height)
                imageClippingTransitionView.transform = transform
                if imageClippingTransitionView.frame.size.height > UIScreen.main.bounds.height {
                    imageClippingTransitionView.frame.size.height = UIScreen.main.bounds.height
                    imageClippingTransitionView.frame.origin = .zero
                } else {
                    imageClippingTransitionView.center = CGPoint(x: view.frame.width / 2,
                                                                 y: view.frame.height / 2)
                }
                view.addSubview(imageClippingTransitionView)
                let origin = currentPage.imageView.convert(CGPoint.zero, to: imageClippingTransitionView)
                imageClippingTransitionView.imageView.frame = CGRect(origin: origin, size: image.size)
            } else {
                imageClippingTransitionView.frame = view.bounds
                imageClippingTransitionView.imageView.frame = view.bounds
                view.addSubview(imageClippingTransitionView)
            }
            transitionView = imageClippingTransitionView
        } else {
            currentPage.videoView.removeFromSuperview()
            transitionView = currentPage.videoView
            view.addSubview(transitionView)
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

// MARK: - Embedded classes
extension GalleryViewController {
    
    struct ShowContext {
        let sourceFrame: CGRect
        let placeholder: UIImage?
        let viewModel: PhotoRepresentableMessageViewModel
        let statusSnapshot: UIImage?
    }
    
    struct DismissContext {
        let sourceFrame: CGRect?
        let viewModel: PhotoRepresentableMessageViewModel
        let statusSnapshot: UIImage?
    }
    
    class ImageTransitionView: UIView {
        
        let imageView = UIImageView()
        let bottomRightImageView = UIImageView()
        
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
            bottomRightImageView.contentMode = .scaleToFill
            addSubview(bottomRightImageView)
            clipsToBounds = true
        }
        
    }
    
}
