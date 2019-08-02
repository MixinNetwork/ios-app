import UIKit
import Photos

protocol GalleryViewControllerDelegate: class {
    func galleryViewController(_ viewController: GalleryViewController, cellFor item: GalleryItem) -> PhotoRepresentableMessageCell?
    func galleryViewController(_ viewController: GalleryViewController, willShow item: GalleryItem)
    func galleryViewController(_ viewController: GalleryViewController, didShow item: GalleryItem)
    func galleryViewController(_ viewController: GalleryViewController, willDismiss item: GalleryItem)
    func galleryViewController(_ viewController: GalleryViewController, didDismiss item: GalleryItem, relativeOffset: CGFloat?)
    func galleryViewController(_ viewController: GalleryViewController, didCancelDismissalFor item: GalleryItem)
}

final class GalleryViewController: UIViewController, GalleryAnimatable {
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
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
    
    override func loadView() {
        view = GalleryView()
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
        if let scrollView = pageViewController.view.subviews.first(where: { $0 is UIScrollView }) {
            (view as? GalleryView)?.scrollView = scrollView as? UIScrollView
        }
        
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        panRecognizer.delegate = self
        view.addGestureRecognizer(panRecognizer)
        
        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        view.addGestureRecognizer(longPressRecognizer)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if GalleryVideoItemViewController.currentPipController == nil {
            currentItemViewController?.isFocused = false
        }
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
        UIApplication.shared.keyWindow?.endEditing(true)
        backgroundView.alpha = 0
        pageViewController.view.alpha = 0
        delegate?.galleryViewController(self, willShow: item)
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
            self.delegate?.galleryViewController(self, didShow: item)
            (viewController as? GalleryVideoItemViewController)?.playAction(self)
        })
    }
    
    func show(itemViewController viewController: GalleryItemViewController) {
        guard let item = viewController.item else {
            return
        }
        UIApplication.shared.keyWindow?.endEditing(true)
        delegate?.galleryViewController(self, willShow: item)
        backgroundView.alpha = 0
        pageViewController.view.alpha = 0
        animate(animations: {
            self.backgroundView.alpha = 1
        }, completion: {
            self.pageViewController.view.alpha = 1
            self.delegate?.galleryViewController(self, didShow: item)
        })
        viewController.isFocused = true
        pageViewController.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
    }
    
    func dismiss(transitionViewInitialOffsetY: CGFloat) {
        guard let itemViewController = currentItemViewController, let item = itemViewController.item else {
            return
        }
        delegate?.galleryViewController(self, willDismiss: item)
        pageViewController.view.alpha = 0
        pageViewController.view.transform = .identity
        view.addSubview(transitionView)
        transitionView.load(viewController: itemViewController)
        transitionView.center.y += transitionViewInitialOffsetY
        transitionView.alpha = 1
        let relativeOffset: CGFloat?
        if item.shouldLayoutAsArticle, let offset = (itemViewController as? GalleryImageItemViewController)?.relativeOffset {
            relativeOffset = offset
        } else {
            relativeOffset = nil
        }
        if let cell = delegate?.galleryViewController(self, cellFor: item) {
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
            self.delegate?.galleryViewController(self, didDismiss: item, relativeOffset: relativeOffset)
            self.pageViewController.view.alpha = 1
        })
    }
    
    func dismissForPip() {
        guard let item = currentItemViewController?.item else {
            return
        }
        animate(animations: {
            self.backgroundView.alpha = 0
        }, completion: {
            self.delegate?.galleryViewController(self, didDismiss: item, relativeOffset: nil)
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
        let item = currentItemViewController?.item
        switch recognizer.state {
        case .began:
            if let item = item {
                delegate?.galleryViewController(self, willDismiss: item)
            }
            currentItemViewController?.willBeginInteractiveDismissal()
            recognizer.setTranslation(.zero, in: view)
        case .changed:
            let y = max(0, translation.y)
            pageViewController.view.transform = CGAffineTransform(translationX: 0, y: y)
            backgroundView.alpha = max(0.4, 1 - progress)
        case .cancelled, .ended:
            if progress > 0.6 || recognizer.velocity(in: view).y > 800 {
                dismiss(transitionViewInitialOffsetY: translation.y)
            } else {
                currentItemViewController?.didCancelInteractiveDismissal()
                animate(animations: {
                    self.backgroundView.alpha = 1
                    self.pageViewController.view.transform = .identity
                }, completion: {
                    if let item = item {
                        self.delegate?.galleryViewController(self, didCancelDismissalFor: item)
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
        let focus = pageViewController.viewControllers?.first as? GalleryItemViewController
        previousViewControllers.filter({
            $0 != focus
        }).forEach({
            ($0 as? GalleryItemViewController)?.isFocused = false
        })
        if let focus = focus {
            focus.isFocused = true
        }
    }
    
}

extension GalleryViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return panRecognizer.velocity(in: view).y > 0
            && abs(panRecognizer.velocity(in: view).y) > abs(panRecognizer.velocity(in: view).x)
    }
    
}
