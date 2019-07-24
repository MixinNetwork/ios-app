import UIKit
import Photos

protocol GalleryViewControllerDelegate: class {
    func galleryViewController(_ viewController: GalleryViewController, cellForItemOf messageId: String) -> PhotoRepresentableMessageCell?
    func galleryViewController(_ viewController: GalleryViewController, didShowItemOf messageId: String)
    func galleryViewController(_ viewController: GalleryViewController, willDismissItemOf messageId: String)
    func galleryViewController(_ viewController: GalleryViewController, didCancelDismissOf messageId: String)
}

final class GalleryViewController: UIViewController, GalleryAnimatable {
    
    static let willShowNotification = Notification.Name("one.mixin.ios.gallery.will.show")
    static let didDismissNotification = Notification.Name("one.mixin.ios.gallery.will.dismiss")
    static let messageIdUserInfoKey = "message_id"
    static let relativeOffsetUserInfoKey = "relative_offset"
    
    weak var delegate: GalleryViewControllerDelegate?
    
    var conversationId: String {
        get {
            return modelController.conversationId
        }
        set {
            modelController.conversationId = newValue
        }
    }
    
    private let interPageSpacing: CGFloat = 20
    private let pageViewController: UIPageViewController
    private let modelController = GalleryItemModelController()
    private let backgroundView = UIView()
    private let transitionView = GalleryTransitionView()
    
    private var longPressRecognizer: UILongPressGestureRecognizer!
    private var panRecognizer: UIPanGestureRecognizer!
    
    private var currentItemViewController: GalleryItemViewController? {
        return pageViewController.viewControllers?.first as? GalleryItemViewController
    }
    
    init() {
        let spacing = NSNumber(value: interPageSpacing.native)
        pageViewController = UIPageViewController(transitionStyle: .scroll,
                                                  navigationOrientation: .horizontal,
                                                  options: [.interPageSpacing: spacing])
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        backgroundView.backgroundColor = .black
        view.addSubview(backgroundView)
        backgroundView.snp.makeEdgesEqualToSuperview()
        
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.view.snp.makeEdgesEqualToSuperview()
        pageViewController.didMove(toParent: self)
        pageViewController.dataSource = modelController
        pageViewController.delegate = self
        pageViewController.view.subviews.forEach { (view) in
            (view as? UIScrollView)?.delaysContentTouches = false
        }
        
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        view.addGestureRecognizer(panRecognizer)
        
        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        view.addGestureRecognizer(longPressRecognizer)
    }
    
    func show(item: GalleryItem, from cell: PhotoRepresentableMessageCell) {
        if let controller = GalleryVideoItemViewController.currentPipController {
            if controller.item == item {
                controller.pipAction()
                return
            } else {
                controller.closeAction()
            }
        }
        backgroundView.alpha = 0
        pageViewController.view.alpha = 0
        NotificationCenter.default.post(name: GalleryViewController.willShowNotification,
                                        object: self,
                                        userInfo: [GalleryViewController.messageIdUserInfoKey: item.messageId])
        transitionView.load(cell: cell)
        transitionView.alpha = 1
        view.addSubview(transitionView)
        transitionView.transition(to: view)
        
        let viewController = modelController.dequeueReusableViewController(with: item)
        viewController.isFocused = true
        if let viewController = viewController as? GalleryImageItemViewController, case let .relativeOffset(offset) = cell.contentImageView.position {
            viewController.scrollView.contentOffset.y = -offset * viewController.scrollView.contentSize.height
        }
        pageViewController.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
        
        animate(animations: {
            self.backgroundView.alpha = 1
        }, completion: {
            self.transitionView.alpha = 0
            self.pageViewController.view.alpha = 1
            self.transitionView.removeFromSuperview()
            self.delegate?.galleryViewController(self, didShowItemOf: item.messageId)
            (viewController as? GalleryVideoItemViewController)?.playAction(self)
        })
    }
    
    func show(itemViewController viewController: GalleryItemViewController) {
        guard let item = viewController.item else {
            return
        }
        NotificationCenter.default.post(name: GalleryViewController.willShowNotification,
                                        object: self,
                                        userInfo: [GalleryViewController.messageIdUserInfoKey: item.messageId])
        backgroundView.alpha = 0
        pageViewController.view.alpha = 0
        animate(animations: {
            self.backgroundView.alpha = 1
        }, completion: {
            self.pageViewController.view.alpha = 1
            self.delegate?.galleryViewController(self, didShowItemOf: item.messageId)
        })
        viewController.isFocused = true
        pageViewController.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
    }
    
    func dismiss(transitionViewInitialOffsetY: CGFloat) {
        guard let itemViewController = currentItemViewController, let item = itemViewController.item else {
            return
        }
        delegate?.galleryViewController(self, willDismissItemOf: item.messageId)
        pageViewController.view.alpha = 0
        pageViewController.view.transform = .identity
        view.addSubview(transitionView)
        transitionView.load(viewController: itemViewController)
        transitionView.center.y += transitionViewInitialOffsetY
        transitionView.alpha = 1
        var userInfo: [String: Any] = [GalleryViewController.messageIdUserInfoKey: item.messageId]
        if item.shouldLayoutAsArticle, let offset = (itemViewController as? GalleryImageItemViewController)?.relativeOffset {
            userInfo[GalleryViewController.relativeOffsetUserInfoKey] = offset
        }
        if let cell = delegate?.galleryViewController(self, cellForItemOf: item.messageId) {
            transitionView.transition(to: cell)
        } else {
            animate(animations: {
                self.transitionView.frame.origin.y = self.view.bounds.height
            })
        }
        currentItemViewController?.isFocused = false
        animate(animations: {
            self.backgroundView.alpha = 0
        }, completion: {
            NotificationCenter.default.post(name: GalleryViewController.didDismissNotification,
                                            object: self,
                                            userInfo: userInfo)
            self.pageViewController.view.alpha = 1
        })
    }
    
    func dismissForPip() {
        var userInfo = [String: Any]()
        if let messageId = currentItemViewController?.item?.messageId {
            userInfo[GalleryViewController.messageIdUserInfoKey] = messageId
        }
        animate(animations: {
            self.backgroundView.alpha = 0
        }, completion: {
            NotificationCenter.default.post(name: GalleryViewController.didDismissNotification,
                                            object: self,
                                            userInfo: userInfo)
        })
    }
    
    func handleMessageRecalling(messageId: String) {
        if currentItemViewController?.item?.messageId == messageId {
            dismiss(transitionViewInitialOffsetY: 0)
        }
    }
    
    @objc func panAction(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: view)
        let progress = min(1, max(0, translation.y / (view.bounds.height / 3)))
        switch recognizer.state {
        case .began:
            if let id = currentItemViewController?.item?.messageId {
                delegate?.galleryViewController(self, willDismissItemOf: id)
            }
            if let vc = currentItemViewController as? GalleryVideoItemViewController {
                vc.controlView.set(playControlsHidden: true, otherControlsHidden: true, animated: true)
            }
            recognizer.setTranslation(.zero, in: view)
        case .changed:
            let y = max(0, translation.y)
            pageViewController.view.transform = CGAffineTransform(translationX: 0, y: y)
            backgroundView.alpha = max(0.4, 1 - progress)
        case .cancelled, .ended:
            if progress > 0.6 || recognizer.velocity(in: view).y > 800 {
                dismiss(transitionViewInitialOffsetY: translation.y)
            } else {
                animate(animations: {
                    self.backgroundView.alpha = 1
                    self.pageViewController.view.transform = .identity
                }, completion: {
                    if let id = self.currentItemViewController?.item?.messageId {
                        self.delegate?.galleryViewController(self, didCancelDismissOf: id)
                    }
                })
            }
        default:
            break
        }
    }
    
    @objc func longPressAction(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, let itemViewController = currentItemViewController else {
            return
        }
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: Localized.CHAT_PHOTO_SAVE, style: .default, handler: { (_) in
            PHPhotoLibrary.checkAuthorization { (authorized) in
                if authorized {
                    itemViewController.saveToLibrary()
                }
            }
        }))
        if let url = (itemViewController as? GalleryImageItemViewController)?.detectedUrl {
            alert.addAction(UIAlertAction(title: Localized.SCAN_QR_CODE, style: .default, handler: { (_) in
                if !UrlWindow.checkUrl(url: url, clearNavigationStack: false) {
                    RecognizeWindow.instance().presentWindow(text: url.absoluteString)
                }
            }))
        }
        alert.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}

extension GalleryViewController: UIPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        previousViewControllers.forEach {
            ($0 as? GalleryItemViewController)?.isFocused = false
        }
        if let vc = pageViewController.viewControllers?.first as? GalleryItemViewController {
            vc.isFocused = true
        }
    }
    
}
