import UIKit
import SwiftMessages

protocol PhotoPreviewViewControllerDelegate: class {
    func placeholder(forMessageId id: String) -> UIImage?
    func sourceFrame(forMessageId id: String) -> CGRect?
    func sourceView(forMessageId id: String) -> UIView?
    func snapshotView(forMessageId id: String) -> UIView?
    func animateAlongsideAppearance()
    func animateAlongsideDisappearance()
    func viewControllerDidDismissed(_ viewController: PhotoPreviewViewController)
}

class PhotoPreviewViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var scrollViewContentView: UIView!
    @IBOutlet weak var backgroundDimmingView: UIView!
    
    @IBOutlet var tapRecognizer: UITapGestureRecognizer!
    @IBOutlet var doubleTapRecognizer: UITapGestureRecognizer!
    @IBOutlet var panRecognizer: UIPanGestureRecognizer!
    @IBOutlet var longPressRecognizer: UILongPressGestureRecognizer!
    
    weak var delegate: PhotoPreviewViewControllerDelegate?
    var photo: Photo?
    
    private let transitionDummyView = PhotoClippingView()
    private let animationDuration: TimeInterval = 0.25
    private let photosCountPerFetch = 20
    private let queue = DispatchQueue(label: "one.mixin.ios.photo.preview")
    
    private var conversationId: String!
    private var pages = [PhotoPreviewPageViewController.instance(),
                         PhotoPreviewPageViewController.instance(),
                         PhotoPreviewPageViewController.instance()]
    private var lastContentOffsetX: CGFloat = 0
    private var panToDismissDistance: CGFloat = 0
    private var photos = [Photo]()
    private var didLoadEarliestPhoto = false
    private var isLoadingBefore = false
    private var isLoadingAfter = false
    
    private var pageSize: CGSize {
        return UIScreen.main.bounds.size
    }
    
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
    
    private var currentPage: PhotoPreviewPageViewController? {
        for i in 0...2 {
            if (scrollView.contentOffset.x - CGFloat(i) * pageSize.width) < 0.1 {
                return pages[i]
            }
        }
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        guard let page = currentPage else {
            return
        }
        page.zoom(location: recognizer.location(in: page.scrollView))
    }
    
    @IBAction func panAction(_ recognizer: UIPanGestureRecognizer) {
        panToDismissDistance += recognizer.translation(in: view).y
        let progress = min(1, max(0, panToDismissDistance / (view.bounds.height / 3)))
        switch recognizer.state {
        case .began:
            prepareTransitionDummyViewForDismissing()
            view.addSubview(transitionDummyView)
            scrollView.isHidden = true
            if let messageId = photo?.messageId {
                delegate?.sourceView(forMessageId: messageId)?.isHidden = true
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
                    self.transitionDummyView.removeFromSuperview()
                    if let messageId = self.photo?.messageId {
                        self.delegate?.sourceView(forMessageId: messageId)?.isHidden = false
                    }
                })
            }
        case .possible, .failed:
            break
        }
    }
    
    @IBAction func longPressAction(_ recognizer: UILongPressGestureRecognizer) {
        guard let page = currentPage, recognizer.state == .began else {
            return
        }
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.CHAT_PHOTO_SAVE, style: .default, handler: { (_) in
            page.saveToLibrary()
        }))
        if let url = page.urlFromQRCode {
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
    
    func show(photo: Photo) {
        self.photo = photo
        reload()
        backgroundDimmingView.alpha = 0
        scrollView.isHidden = true
        var imageFinalFrame = CGRect.zero
        var sourceViewSnapshotView: UIView?
        let sourceView = delegate?.sourceView(forMessageId: photo.messageId)
        sourceView?.isHidden = true
        if let sourceFrame = delegate?.sourceFrame(forMessageId: photo.messageId) {
            transitionDummyView.frame = sourceFrame.insetBy(dx: PhotoClippingView.clippingMargin.dx,
                                                            dy: PhotoClippingView.clippingMargin.dy)
            transitionDummyView.imageView.image = delegate?.placeholder(forMessageId: photo.messageId)
            transitionDummyView.imageView.frame = CGRect(x: -PhotoClippingView.clippingMargin.dx,
                                                         y: -PhotoClippingView.clippingMargin.dy,
                                                         width: sourceFrame.width,
                                                         height: sourceFrame.height)
            view.addSubview(transitionDummyView)
            if let snapshot = delegate?.snapshotView(forMessageId: photo.messageId) {
                snapshot.frame = sourceFrame
                view.addSubview(snapshot)
                sourceViewSnapshotView = snapshot
            }
        }
        let safeAreaInsets = self.safeAreaInsets
        let containerSize = CGSize(width: view.frame.width - safeAreaInsets.horizontal,
                                   height: view.frame.height - safeAreaInsets.vertical)
        let containerRatio = containerSize.width / containerSize.height
        let photoRatio = photo.size.width / photo.size.height
        let size: CGSize, origin: CGPoint
        if photoRatio > containerRatio {
            size = CGSize(width: containerSize.width, height: ceil(containerSize.width / photoRatio))
            origin = CGPoint(x: 0, y: (containerSize.height - size.height) / 2)
        } else {
            size = CGSize(width: ceil(containerSize.height * photoRatio), height: containerSize.height)
            origin = CGPoint(x: (containerSize.width - size.width) / 2, y: 0)
        }
        imageFinalFrame = CGRect(origin: origin, size: size)
        let safeAreaOrigin = CGPoint(x: safeAreaInsets.left, y: safeAreaInsets.top)
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut, animations: {
            if let photoSize = self.photo?.size, let snapshot = sourceViewSnapshotView {
                if self.currentPhotoIsVerticallyOversized {
                    let width = containerSize.height * (photoSize.width / photoSize.height)
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
            self.delegate?.animateAlongsideAppearance()
        }, completion: { (_) in
            sourceViewSnapshotView?.removeFromSuperview()
            self.transitionDummyView.removeFromSuperview()
            self.scrollView.isHidden = false
            sourceView?.isHidden = false
        })
    }
    
    func dismiss() {
        scrollView.isHidden = true
        var sourceView: UIView?
        if let photo = photo {
            sourceView = delegate?.sourceView(forMessageId: photo.messageId)
            sourceView?.isHidden = true
        }
        if transitionDummyView.superview == nil {
            prepareTransitionDummyViewForDismissing()
        } else {
            transitionDummyView.removeFromSuperview()
        }
        view.addSubview(transitionDummyView)
        var sourceViewSnapshotView: UIView?
        if let photo = photo, let snapshot = delegate?.snapshotView(forMessageId: photo.messageId) {
            let imageViewSize = transitionDummyView.imageView.frame.size
            let size = CGSize(width: imageViewSize.width, height: imageViewSize.width * snapshot.frame.height / snapshot.frame.width)
            let origin = CGPoint(x: (imageViewSize.width - size.width) / 2, y: (imageViewSize.height - size.height) / 2)
                + transitionDummyView.imageView.frame.origin
                + transitionDummyView.frame.origin
            snapshot.frame = CGRect(origin: origin, size: size)
            view.insertSubview(snapshot, belowSubview: transitionDummyView)
            sourceViewSnapshotView = snapshot
        }
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut, animations: {
            self.backgroundDimmingView.alpha = 0
            if let photo = self.photo, let sourceFrame = self.delegate?.sourceFrame(forMessageId: photo.messageId) {
                sourceViewSnapshotView?.frame = sourceFrame
                self.transitionDummyView.frame = sourceFrame
                if self.currentPhotoIsVerticallyOversized {
                    let photoRatio = photo.size.width / photo.size.height
                    let size = CGSize(width: sourceFrame.width, height: sourceFrame.width / photoRatio)
                    let origin = CGPoint(x: 0, y: (sourceFrame.height - size.height) / 2)
                    self.transitionDummyView.imageView.frame = CGRect(origin: origin, size: size)
                } else {
                    self.transitionDummyView.imageView.frame = self.transitionDummyView.bounds
                }
            }
            self.transitionDummyView.alpha = 0
            self.delegate?.animateAlongsideDisappearance()
        }, completion: { (_) in
            sourceViewSnapshotView?.removeFromSuperview()
            self.transitionDummyView.removeFromSuperview()
            self.scrollView.isHidden = false
            self.transitionDummyView.alpha = 1
            sourceView?.isHidden = false
            self.delegate?.viewControllerDidDismissed(self)
        })
    }
    
    class func instance(conversationId: String) -> PhotoPreviewViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "photo_preview") as! PhotoPreviewViewController
        vc.conversationId = conversationId
        return vc
    }
    
}

extension PhotoPreviewViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let x = scrollView.contentOffset.x
        let conversationId = self.conversationId!
        let photosCountPerFetch = self.photosCountPerFetch
        if x > pageSize.width * 1.5 && x > lastContentOffsetX, let photo = pages[2].photo {
            if let photoAfter = photos.element(after: photo) {
                let page = pages.remove(at: 0)
                page.photo = photoAfter
                pages.append(page)
                layoutPages()
                scrollView.bounds.origin.x -= pageSize.width
            } else if !isLoadingAfter, let lastPhoto = photos.last {
                isLoadingAfter = true
                queue.async { [weak self] in
                    guard self != nil else {
                        return
                    }
                    let photosAfter = MessageDAO.shared.getPhotos(conversationId: conversationId, location: lastPhoto, count: photosCountPerFetch)
                    DispatchQueue.main.sync {
                        if photosAfter.count > 0 {
                            self?.photos += photosAfter
                        }
                        self?.isLoadingAfter = false
                    }
                }
            }
        } else if x < pageSize.width * 0.5 && x < lastContentOffsetX, let photo = pages[0].photo {
            if let photoBefore = photos.element(before: photo) {
                let page = pages.remove(at: 2)
                page.photo = photoBefore
                pages.insert(page, at: 0)
                layoutPages()
                scrollView.bounds.origin.x += pageSize.width
            } else if !isLoadingBefore && !didLoadEarliestPhoto, let firstPhoto = photos.first {
                isLoadingBefore = true
                queue.async { [weak self] in
                    guard self != nil else {
                        return
                    }
                    let photosBefore = MessageDAO.shared.getPhotos(conversationId: conversationId, location: firstPhoto, count: -photosCountPerFetch)
                    DispatchQueue.main.sync {
                        if photosBefore.count > 0 {
                            self?.photos.insert(contentsOf: photosBefore, at: 0)
                        }
                        self?.didLoadEarliestPhoto = photosBefore.count < photosCountPerFetch
                        self?.isLoadingBefore = false
                    }
                }
            }
        }
        lastContentOffsetX = x
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updatePhoto()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updatePhoto()
    }
    
}

extension PhotoPreviewViewController: UIGestureRecognizerDelegate {
    
    var pageDidReachTopEdge: Bool {
        guard let page = currentPage else {
            return false
        }
        return page.scrollView.contentOffset.y <= 0.1
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panRecognizer else {
            return true
        }
        return panRecognizer.velocity(in: view).y > 0 && pageDidReachTopEdge
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

extension PhotoPreviewViewController {
    
    private var currentPhotoIsVerticallyOversized: Bool {
        guard let photo = photo else {
            return false
        }
        return photo.size.width / photo.size.height < PhotoMessageViewModel.contentWidth / PhotoMessageViewModel.maxHeight
    }
    
    private func layoutPages() {
        for (index, page) in pages.enumerated() {
            page.view.frame = CGRect(x: CGFloat(index) * pageSize.width, y: 0, width: pageSize.width, height: pageSize.height)
        }
    }
    
    private func updatePhoto() {
        if let photo = currentPage?.photo {
            self.photo = photo
        }
    }
    
    private func reload() {
        guard let photo = photo else {
            return
        }
        isLoadingBefore = true
        isLoadingAfter = true
        pages[0].photo = photo
        scrollViewContentView.frame = CGRect(origin: .zero, size: pageSize)
        scrollView.contentSize = pageSize
        lastContentOffsetX = 0
        scrollView.contentOffset.x = 0
        let conversationId = self.conversationId!
        let photosCountPerFetch = self.photosCountPerFetch
        queue.async { [weak self] in
            guard self != nil else {
                return
            }
            let photosBefore = MessageDAO.shared.getPhotos(conversationId: conversationId, location: photo, count: -photosCountPerFetch / 2)
            let photosAfter = MessageDAO.shared.getPhotos(conversationId: conversationId, location: photo, count: photosCountPerFetch / 2)
            DispatchQueue.main.sync {
                self?.photos = photosBefore + [photo] + photosAfter
                self?.reloadPages()
                self?.isLoadingBefore = false
                self?.isLoadingAfter = false
            }
        }
    }
    
    private func reloadPages() {
        guard let photo = photo else {
            return
        }
        var pagePhotos = [photo]
        var initialIndex = 0
        if let before = photos.element(before: photo) {
            pagePhotos.insert(before, at: 0)
            initialIndex = 1
            if let after = photos.element(after: photo) {
                pagePhotos.append(after)
            } else if let beforeBefore = photos.element(before: before) {
                pagePhotos.insert(beforeBefore, at: 0)
                initialIndex = 2
            }
        } else if let after = photos.element(after: photo) {
            pagePhotos.append(after)
            if let afterAfter = photos.element(after: after) {
                pagePhotos.append(afterAfter)
            }
        }
        scrollViewContentView.frame = CGRect(x: 0, y: 0, width: CGFloat(pagePhotos.count) * pageSize.width, height: pageSize.height)
        scrollView.contentSize = scrollViewContentView.frame.size
        lastContentOffsetX = CGFloat(initialIndex) * pageSize.width
        scrollView.contentOffset.x = lastContentOffsetX
        for (index, photo) in pagePhotos.enumerated() {
            pages[index].photo = photo
        }
    }
    
    private func prepareTransitionDummyViewForDismissing() {
        transitionDummyView.imageView.image = currentPage?.imageView.image
        if let page = currentPage {
            let origin = page.imageView.convert(CGPoint.zero, to: view)
            transitionDummyView.frame = CGRect(origin: origin, size: page.imageView.frame.size)
            transitionDummyView.imageView.frame = CGRect(origin: .zero, size: page.imageView.frame.size)
        } else {
            transitionDummyView.frame = view.frame
            transitionDummyView.imageView.frame = transitionDummyView.bounds
        }
    }
    
    private func updateMessage(messageId: String) {
        guard photos.contains(where: { $0.messageId == messageId }) else {
            return
        }
        queue.async { [weak self] in
            guard self != nil else {
                return
            }
            guard let message = MessageDAO.shared.getMessage(messageId: messageId), let photo = Photo(message: message) else {
                return
            }
            DispatchQueue.main.sync {
                if let index = self?.photos.index(where: { $0.messageId == message.messageId }) {
                    self?.photos[index] = photo
                }
                if let index = self?.pages.index(where: { $0.photo?.messageId == message.messageId }) {
                    self?.pages[index].photo = photo
                }
            }
        }
    }
    
    private func updateDownloadProgress(messageId: String, progress: Double) {
        guard let page = pages.first(where: { $0.photo?.messageId == messageId }) else {
            return
        }
        page.operationButton.style = .busy(progress)
    }
    
    private func updateMediaStatus(messageId: String, mediaStatus: MediaStatus) {
        guard let index = photos.index(where: { $0.messageId == messageId }) else {
            return
        }
        photos[index].mediaStatus = mediaStatus
        if let page = pages.first(where: { $0.photo?.messageId == messageId }) {
            page.photo = photos[index]
        }
    }
    
}

extension PhotoPreviewViewController {
    
    class PhotoClippingView: UIView {
        
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
