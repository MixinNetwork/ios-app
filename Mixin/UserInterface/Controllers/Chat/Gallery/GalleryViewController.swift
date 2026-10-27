import UIKit
import AVKit
import MixinServices

protocol GalleryViewControllerDelegate: AnyObject {
    func galleryViewController(_ viewController: GalleryViewController, cellFor item: GalleryItem) -> GalleryTransitionSource?
    func galleryViewController(_ viewController: GalleryViewController, willShow item: GalleryItem)
    func galleryViewController(_ viewController: GalleryViewController, didShow item: GalleryItem)
    func galleryViewController(_ viewController: GalleryViewController, willDismiss item: GalleryItem)
    func galleryViewController(_ viewController: GalleryViewController, didDismiss item: GalleryItem, relativeOffset: CGFloat?)
    func galleryViewController(_ viewController: GalleryViewController, didCancelDismissalFor item: GalleryItem)
}

final class GalleryViewController: UIViewController, GalleryAnimatable {
    
    private enum PresentationState {
        case hidden
        case presenting
        case visible
        case dismissing
        case tornDown
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    weak var delegate: GalleryViewControllerDelegate?
    
    var pipController: GalleryVideoItemViewController? {
        didSet {
            if pipController == nil {
                pipSourceDelegate = nil
                // Keep the player alive until AVKit finishes handing over to another video.
                if itemToShowAfterPiPStops == nil {
                    pipModelController = nil
                }
            }
        }
    }
    
    var isPresented: Bool {
        switch presentationState {
        case .hidden, .tornDown:
            false
        case .presenting, .visible, .dismissing:
            true
        }
    }
    
    var conversationId: String? {
        get {
            return modelController.conversationId
        }
        set {
            modelController.conversationId = newValue
        }
    }
    
    private let interPageSpacing: CGFloat = 20
    private let pageViewController: UIPageViewController
    private let backgroundView = UIView()
    
    private weak var sceneDelegate: SceneDelegate?
    private weak var galleryWindow: GalleryWindow?
    private weak var pipSourceDelegate: GalleryViewControllerDelegate?
    
    private var modelController = GalleryItemModelController()
    private var pipModelController: GalleryItemModelController?
    private var presentationState: PresentationState = .hidden
    private var pendingDismissalOffsetY: CGFloat?
    private var dismissalCompletions: [() -> Void] = []
    private var transitionView: GalleryTransitionView?
    private var longPressRecognizer: UILongPressGestureRecognizer!
    private var itemToShowAfterPiPStops: (GalleryItem, GalleryTransitionSource)?
    
    private(set) var panRecognizer: UIPanGestureRecognizer!
    
    var currentItemViewController: GalleryItemViewController? {
        return pageViewController.viewControllers?.first as? GalleryItemViewController
    }
    
    init() {
        let spacing = NSNumber(value: interPageSpacing.native)
        pageViewController = UIPageViewController(transitionStyle: .scroll,
                                                  navigationOrientation: .horizontal,
                                                  options: [.interPageSpacing: spacing])
        super.init(nibName: nil, bundle: nil)
        modelController.galleryViewController = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let scrollView = pageViewController.view.subviews
            .lazy
            .compactMap { $0 as? UIScrollView }
            .first
        if let window = view.window,
           let scene = window.windowScene,
           let scrollView
        {
            scrollView.isScrollEnabled = scene.interfaceOrientation.isPortrait
        }
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
        
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        panRecognizer.delegate = self
        view.addGestureRecognizer(panRecognizer)
        
        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        view.addGestureRecognizer(longPressRecognizer)
        NotificationCenter.default.addObserver(self, selector: #selector(willRecallMessage(_:)), name: SendMessageService.willRecallMessageNotification, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        currentItemViewController?.isFocused = false
    }
    
    @objc func willRecallMessage(_ notification: Notification) {
        guard let messageId = notification.userInfo?[SendMessageService.UserInfoKey.messageId] as? String else {
            return
        }
        guard currentItemViewController?.item?.messageId == messageId else {
            return
        }
        dismiss(transitionViewInitialOffsetY: 0)
    }
    
    func show(item: GalleryItem, from source: GalleryTransitionSource) {
        show(items: [item], index: 0, from: source)
    }
    
    func show(items: [GalleryItem], index: Int, from source: GalleryTransitionSource) {
        guard presentationState == .hidden else {
            return
        }
        itemToShowAfterPiPStops = nil
        modelController.direction = source.direction
        let item = items[index]
        if let controller = pipController {
            if controller.item == item {
                pipSourceDelegate = delegate
                controller.stopPipIfActive()
                return
            } else if item.category == .video || item.category == .live {
                if controller.isPictureInPictureActive {
                    itemToShowAfterPiPStops = (item, source)
                    controller.stopPiPAndHandoverDelegate(to: self)
                    return
                }
            }
        }
        guard let sceneDelegate = UIApplication.shared.firstWindowScene?.delegate as? SceneDelegate,
              let mainWindow = sceneDelegate.mainWindow,
              let galleryWindow = prepareWindow(in: sceneDelegate)
        else {
            return
        }
        mainWindow.endEditing(true)
        presentationState = .presenting
        backgroundView.alpha = 1
        pageViewController.view.alpha = 0
        galleryWindow.beginTransition(in: mainWindow, backgroundAlpha: 0) { [self] transitionController in
            guard presentationState != .tornDown else {
                return
            }
            delegate?.galleryViewController(self, willShow: item)
            
            if transitionView == nil || type(of: transitionView) != source.transitionViewType {
                transitionView = source.transitionViewType.init()
            }
            transitionController.view.addSubview(transitionView!)
            transitionView!.transform = .identity
            transitionView!.load(source: source)
            transitionView!.alpha = 1
            transitionView!.transition(to: transitionController.view)
            
            let viewController = modelController.dequeueReusableViewController(with: items, index: index)
            viewController.isFocused = true
            if let viewController = viewController as? GalleryImageItemViewController, case let .relativeOffset(offset) = source.imageWrapperView.position {
                viewController.scrollView.contentOffset.y = -offset * viewController.scrollView.contentSize.height
            }
            pageViewController.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
            
            animate(animations: {
                transitionController.backgroundView.alpha = 1
            }, completion: {
                guard self.presentationState != .tornDown else {
                    return
                }
                if self.pendingDismissalOffsetY == nil,
                   let videoController = viewController as? GalleryVideoItemViewController
                {
                    // Hide playback controls before the gallery window's first visible frame.
                    videoController.hidePlayControlAfterPlaybackBegins = true
                    videoController.playAction(self)
                }
                self.pageViewController.view.alpha = 1
                sceneDelegate.showGalleryWindow()
                self.transitionView?.removeFromSuperview()
                galleryWindow.endTransition {
                    guard self.presentationState != .tornDown else {
                        return
                    }
                    self.presentationState = .visible
                    self.delegate?.galleryViewController(self, didShow: item)
                    if let offsetY = self.pendingDismissalOffsetY {
                        self.pendingDismissalOffsetY = nil
                        self.dismiss(transitionViewInitialOffsetY: offsetY, completion: nil)
                    }
                }
            })
            setNeedsUpdateOfSupportedInterfaceOrientationsIfNeeded()
        }
    }
    
    func show(itemViewController viewController: GalleryItemViewController) {
        guard presentationState == .hidden || presentationState == .visible,
              let item = viewController.item,
              let sceneDelegate = UIApplication.shared.firstWindowScene?.delegate as? SceneDelegate,
              let mainWindow = sceneDelegate.mainWindow,
              let galleryWindow = prepareWindow(in: sceneDelegate)
        else {
            return
        }
        mainWindow.endEditing(true)
        let wasShowing = presentationState == .visible
        presentationState = .presenting
        let modelControllerToRestore: GalleryItemModelController?
        if viewController === pipController {
            delegate = pipSourceDelegate
            modelControllerToRestore = pipModelController
        } else {
            modelControllerToRestore = nil
        }
        let viewControllerToHide = wasShowing ? currentItemViewController : nil
        let show = { [self] (transitionController: GalleryTransitionViewController?) in
            guard presentationState != .tornDown else {
                return
            }
            animate(animations: {
                viewControllerToHide?.view.alpha = 0
                self.backgroundView.alpha = 1
                transitionController?.backgroundView.alpha = 1
            }, completion: {
                guard self.presentationState != .tornDown else {
                    return
                }
                if viewController.parent != nil, viewController.parent !== self.pageViewController {
                    viewController.willMove(toParent: nil)
                    viewController.view.removeFromSuperview()
                    viewController.removeFromParent()
                }
                if let modelControllerToRestore {
                    self.modelController = modelControllerToRestore
                    self.pageViewController.dataSource = modelControllerToRestore
                }
                self.pageViewController.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
                self.pageViewController.view.alpha = 1
                sceneDelegate.showGalleryWindow()
                galleryWindow.endTransition {
                    guard self.presentationState != .tornDown else {
                        return
                    }
                    self.presentationState = .visible
                    if !wasShowing {
                        self.delegate?.galleryViewController(self, didShow: item)
                    }
                    viewController.isFocused = true
                    viewControllerToHide?.view.alpha = 1
                    if let offsetY = self.pendingDismissalOffsetY {
                        self.pendingDismissalOffsetY = nil
                        self.dismiss(transitionViewInitialOffsetY: offsetY, completion: nil)
                    }
                }
            })
            setNeedsUpdateOfSupportedInterfaceOrientationsIfNeeded()
        }
        if wasShowing {
            show(nil)
        } else {
            backgroundView.alpha = 1
            pageViewController.view.alpha = 0
            galleryWindow.beginTransition(in: mainWindow, backgroundAlpha: 0) { [self] transitionController in
                delegate?.galleryViewController(self, willShow: item)
                show(transitionController)
            }
        }
    }
    
    func dismiss(transitionViewInitialOffsetY: CGFloat) {
        dismiss(transitionViewInitialOffsetY: transitionViewInitialOffsetY, completion: nil)
    }
    
    func dismiss(transitionViewInitialOffsetY: CGFloat, completion: (() -> Void)?) {
        switch presentationState {
        case .hidden:
            completion?()
            return
        case .tornDown:
            return
        case .presenting, .dismissing:
            if let completion {
                dismissalCompletions.append(completion)
            }
            if presentationState == .presenting, pendingDismissalOffsetY == nil {
                pendingDismissalOffsetY = transitionViewInitialOffsetY
            }
            return
        case .visible:
            break
        }
        guard let itemViewController = currentItemViewController,
              let item = itemViewController.item,
              let sceneDelegate,
              let mainWindow = sceneDelegate.mainWindow,
              let galleryWindow
        else {
            return
        }
        if let completion {
            dismissalCompletions.append(completion)
        }
        presentationState = .dismissing
        delegate?.galleryViewController(self, willDismiss: item)
        galleryWindow.beginTransition(in: mainWindow, backgroundAlpha: 0) { [self] transitionController in
            guard presentationState != .tornDown else {
                return
            }
            pageViewController.view.alpha = 0
            pageViewController.view.transform = .identity
            
            let source = delegate?.galleryViewController(self, cellFor: item)
            if transitionView == nil {
                transitionView = source?.transitionViewType.init() ?? GalleryTransitionView()
            }
            if let transitionView = transitionView {
                transitionController.view.addSubview(transitionView)
                transitionView.load(viewController: itemViewController)
                transitionView.center.y += transitionViewInitialOffsetY
                transitionView.alpha = 1
            }
            
            // Transfer dimming without stacking the two windows' backdrops.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            transitionController.backgroundView.alpha = backgroundView.alpha
            sceneDelegate.hideGalleryWindow()
            CATransaction.commit()
            
            let relativeOffset: CGFloat?
            if item.shouldLayoutAsArticle, let offset = (itemViewController as? GalleryImageItemViewController)?.relativeOffset {
                relativeOffset = offset
            } else {
                relativeOffset = nil
            }
            if let source {
                transitionView?.transition(to: source)
            } else {
                animate(animations: {
                    self.transitionView?.frame.origin.y = self.view.bounds.height
                })
            }
            currentItemViewController?.isFocused = false
            animate(animations: {
                transitionController.backgroundView.alpha = 0
            }, completion: {
                guard self.presentationState != .tornDown else {
                    return
                }
                // Restore the source before removing the snapshot that covers it.
                self.delegate?.galleryViewController(self, didDismiss: item, relativeOffset: relativeOffset)
                mainWindow.layoutIfNeeded()
                CATransaction.flush()
                self.transitionView?.removeFromSuperview()
                galleryWindow.endTransition {
                    guard self.presentationState != .tornDown else {
                        return
                    }
                    self.pageViewController.view.alpha = 1
                    self.finishDismissal()
                }
            })
        }
    }
    
    func dismiss(pipController: GalleryVideoItemViewController) {
        guard presentationState == .visible,
              let item = pipController.item,
              let sceneDelegate,
              let mainWindow = sceneDelegate.mainWindow,
              let container = mainWindow.rootViewController as? HomeContainerViewController,
              let galleryWindow
        else {
            return
        }
        presentationState = .dismissing
        self.pipController = pipController
        pipSourceDelegate = delegate
        pipModelController = modelController
        galleryWindow.beginTransition(in: mainWindow, backgroundAlpha: 0) { [self] transitionController in
            guard presentationState != .tornDown else {
                return
            }
            pageViewController.setViewControllers([UIViewController()], direction: .forward, animated: false, completion: nil)
            // Keep the PiP item's browsing context intact while another gallery is opened.
            let nextModelController = GalleryItemModelController()
            nextModelController.galleryViewController = self
            nextModelController.conversationId = modelController.conversationId
            nextModelController.direction = modelController.direction
            modelController = nextModelController
            pageViewController.dataSource = nextModelController
            
            transitionController.addChild(pipController)
            transitionController.view.addSubview(pipController.view)
            pipController.didMove(toParent: transitionController)
            // Transfer dimming without stacking the two windows' backdrops.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            transitionController.backgroundView.alpha = backgroundView.alpha
            sceneDelegate.hideGalleryWindow()
            CATransaction.commit()
            
            animate(animations: {
                transitionController.backgroundView.alpha = 0
            }, completion: {
                guard self.presentationState != .tornDown else {
                    return
                }
                if pipController.parent === transitionController {
                    pipController.willMove(toParent: nil)
                    pipController.view.removeFromSuperview()
                    pipController.removeFromParent()
                    container.addChild(pipController)
                    container.view.addSubview(pipController.view)
                    pipController.didMove(toParent: container)
                }
                self.delegate?.galleryViewController(self, didDismiss: item, relativeOffset: nil)
                mainWindow.layoutIfNeeded()
                CATransaction.flush()
                galleryWindow.endTransition {
                    guard self.presentationState != .tornDown else {
                        return
                    }
                    self.finishDismissal()
                }
            })
        }
    }
    
    func forward() {
        guard let item = currentItemViewController?.item else {
            return
        }
        let message: MessageItem?
        if let transcriptId = item.transcriptId {
            message = TranscriptMessageDAO.shared.messageItem(transcriptId: transcriptId, messageId: item.messageId)
        } else {
            message = MessageDAO.shared.getFullMessage(messageId: item.messageId)
        }
        guard let message = message else {
            return
        }
        if message.category.hasSuffix("_LIVE"), let live = message.live, !(live.isShareable ?? true) {
            alert(R.string.localizable.live_shareable_false())
            return
        }
        let content: MessageReceiverViewController.MessageContent
        if let transcriptId = item.transcriptId {
            content = .transcriptMessage(transcriptId: transcriptId, item: message)
        } else {
            content = .messages([message])
        }
        let receiver = MessageReceiverViewController.instance(content: content)
        dismiss(transitionViewInitialOffsetY: 0) {
            UIApplication.shared.homeNavigationController?.pushViewController(receiver, animated: true)
        }
    }
    
    func showInChat() {
        guard let messageId = currentItemViewController?.item?.messageId else {
            return
        }
        guard let conversationController = UIApplication.shared.homeNavigationController?.viewControllers.first(where: { $0 is ConversationViewController }) as? ConversationViewController else {
            return
        }
        let sharedMedia = UIApplication.shared.homeNavigationController?.viewControllers
            .compactMap({ $0 as? SharedMediaViewController })
            .first
        if let sharedMedia {
            sharedMedia.navigationController?.popViewController(animated: false)
        } else if let pinMessagesPreview = conversationController.children.first(where: { $0 is PinMessagesPreviewViewController }) as? PinMessagesPreviewViewController {
            pinMessagesPreview.dismissAsChild(animated: false, completion: nil)
        }
        delegate = conversationController
        dismiss(transitionViewInitialOffsetY: 0) {
            conversationController.scrollToMessage(messageId: messageId)
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
        guard recognizer.state == .began, let itemViewController = currentItemViewController, !itemViewController.supportedActions.isEmpty else {
            return
        }
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if itemViewController.supportedActions.contains(.share) {
            alert.addAction(UIAlertAction(title: R.string.localizable.share(), style: .default, handler: { (_) in
                itemViewController.share()
            }))
        }
        if itemViewController.supportedActions.contains(.forward) {
            alert.addAction(UIAlertAction(title: R.string.localizable.forward(), style: .default, handler: { (_) in
                self.forward()
            }))
        }
        if itemViewController.supportedActions.contains(.saveToLibrary) {
            alert.addAction(UIAlertAction(title: R.string.localizable.save_to_camera_roll(), style: .default, handler: { (_) in
                itemViewController.saveToLibrary()
            }))
        }
        if let url = (itemViewController as? GalleryImageItemViewController)?.detectedUrl {
            alert.addAction(UIAlertAction(title: R.string.localizable.scan_qr_code(), style: .default, handler: { (_) in
                self.dismiss(transitionViewInitialOffsetY: 0) {
                    UrlWindow.checkQrCodeDetection(string: url.absoluteString, clearNavigationStack: false)
                }
            }))
        }
        if itemViewController.supportedActions.contains(.showInChat) {
            alert.addAction(UIAlertAction(title: R.string.localizable.show_in_chat(), style: .default, handler: { (_) in
                self.showInChat()
            }))
        }
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func tearDown() {
        presentationState = .tornDown
        pendingDismissalOffsetY = nil
        dismissalCompletions.removeAll()
        itemToShowAfterPiPStops = nil
        currentItemViewController?.isFocused = false
        pipController?.isFocused = false
        pipController?.stopPiPAndHandoverDelegate(to: self)
        pipController = nil
        transitionView?.layer.removeAllAnimations()
        transitionView?.removeFromSuperview()
        galleryWindow?.endTransition(completion: nil)
        delegate = nil
    }
    
    private func finishDismissal() {
        presentationState = .hidden
        let completions = dismissalCompletions
        dismissalCompletions.removeAll()
        for completion in completions {
            guard presentationState != .tornDown else {
                return
            }
            completion()
        }
    }
    
    private func prepareWindow(in sceneDelegate: SceneDelegate) -> GalleryWindow? {
        guard let galleryWindow = sceneDelegate.galleryWindow,
              galleryWindow.galleryViewController === self
        else {
            return nil
        }
        self.sceneDelegate = sceneDelegate
        self.galleryWindow = galleryWindow
        loadViewIfNeeded()
        view.frame = galleryWindow.bounds
        view.layoutIfNeeded()
        return galleryWindow
    }
    
    private func setNeedsUpdateOfSupportedInterfaceOrientationsIfNeeded() {
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
        }
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
        setNeedsUpdateOfSupportedInterfaceOrientationsIfNeeded()
    }
    
}

extension GalleryViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return presentationState == .visible
            && panRecognizer.velocity(in: view).y > 0
            && abs(panRecognizer.velocity(in: view).y) > abs(panRecognizer.velocity(in: view).x)
            && (currentItemViewController?.canPerformInteractiveDismissal ?? true)
    }
    
}

extension GalleryViewController {
    
    func modelController(_ controller: GalleryItemModelController, didLoadItemsBefore location: GalleryItem) {
        guard controller === modelController,
              let current = currentItemViewController, location == current.item
        else {
            return
        }
        pageViewController.setViewControllers([current], direction: .forward, animated: false, completion: nil)
    }
    
    func modelController(_ controller: GalleryItemModelController, didLoadItemsAfter location: GalleryItem) {
        guard controller === modelController,
              let current = currentItemViewController, location == current.item
        else {
            return
        }
        pageViewController.setViewControllers([current], direction: .forward, animated: false, completion: nil)
    }
    
}

extension GalleryViewController: AVPictureInPictureControllerDelegate {
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipModelController = nil
        guard let item = itemToShowAfterPiPStops else {
            return
        }
        show(item: item.0, from: item.1)
    }
    
}
