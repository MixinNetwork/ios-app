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
        isStatusBarHidden
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .fade
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if presentationState != .tornDown,
           transitionOverlayView == nil,
           currentItemViewController is GalleryVideoItemViewController
        {
            .all
        } else {
            .portrait
        }
    }
    
    weak var source: (UIViewController & GalleryViewControllerDelegate)?
    
    var pipController: GalleryVideoItemViewController? {
        didSet {
            if pipController == nil {
                pipSource = nil
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
    private weak var pipSource: (UIViewController & GalleryViewControllerDelegate)?
    
    private var modelController = GalleryItemModelController()
    private var pipModelController: GalleryItemModelController?
    private var presentationState: PresentationState = .hidden
    private var isStatusBarHidden = false
    private var statusBarHiddenBeforePresentation = false
    private var pendingDismissalOffsetY: CGFloat?
    private var dismissalCompletions: [() -> Void] = []
    private var transitionView: GalleryTransitionView?
    private var transitionOverlayView: GalleryTransitionOverlayView?
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
    
    func show(item: GalleryItem, from transitionSource: GalleryTransitionSource) {
        show(items: [item], index: 0, from: transitionSource)
    }
    
    func show(items: [GalleryItem], index: Int, from transitionSource: GalleryTransitionSource) {
        guard presentationState == .hidden else {
            return
        }
        itemToShowAfterPiPStops = nil
        modelController.direction = transitionSource.direction
        let item = items[index]
        if let controller = pipController {
            if controller.item == item {
                pipSource = source
                controller.stopPipIfActive()
                return
            } else if item.category == .video || item.category == .live {
                if controller.isPictureInPictureActive {
                    itemToShowAfterPiPStops = (item, transitionSource)
                    controller.stopPiPAndHandoverDelegate(to: self)
                    return
                }
            }
        }
        guard let sceneDelegate = UIApplication.shared.firstWindowScene?.delegate as? SceneDelegate,
              let mainWindow = sceneDelegate.mainWindow,
              prepareWindow(in: sceneDelegate)
        else {
            return
        }
        mainWindow.endEditing(true)
        presentationState = .presenting
        backgroundView.alpha = 0
        pageViewController.view.alpha = 0
        let didBeginTransition = beginTransition(
            backgroundAlpha: 0,
        ) { [self] transitionOverlayView in
            guard presentationState != .tornDown else {
                return
            }
            // Attach the transparent window before converting the source's coordinates.
            sceneDelegate.showGalleryWindow()
            source?.galleryViewController(self, willShow: item)
            
            if transitionView == nil || type(of: transitionView) != transitionSource.transitionViewType {
                transitionView = transitionSource.transitionViewType.init()
            }
            transitionOverlayView.addSubview(transitionView!)
            transitionView!.transform = .identity
            transitionView!.load(source: transitionSource)
            transitionView!.alpha = 1
            
            let viewController = modelController.dequeueReusableViewController(with: items, index: index)
            viewController.isFocused = true
            if let viewController = viewController as? GalleryImageItemViewController, case let .relativeOffset(offset) = transitionSource.imageWrapperView.position {
                viewController.scrollView.contentOffset.y = -offset * viewController.scrollView.contentSize.height
            }
            pageViewController.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
            
            transitionView!.transition(to: transitionOverlayView)
            animate(animations: {
                self.setStatusBarHidden(true)
                transitionOverlayView.backgroundView.alpha = 1
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
                self.backgroundView.alpha = 1
                self.pageViewController.view.alpha = 1
                self.transitionView?.removeFromSuperview()
                self.endTransition {
                    guard self.presentationState != .tornDown else {
                        return
                    }
                    self.presentationState = .visible
                    self.setNeedsUpdateOfSupportedInterfaceOrientationsIfNeeded()
                    self.source?.galleryViewController(self, didShow: item)
                    if let offsetY = self.pendingDismissalOffsetY {
                        self.pendingDismissalOffsetY = nil
                        self.dismiss(transitionViewInitialOffsetY: offsetY, completion: nil)
                    }
                }
            })
            setNeedsUpdateOfSupportedInterfaceOrientationsIfNeeded()
        }
        if !didBeginTransition, presentationState != .tornDown {
            finishDismissal()
        }
    }
    
    func show(itemViewController viewController: GalleryItemViewController) {
        guard presentationState == .hidden || presentationState == .visible,
              let item = viewController.item,
              let sceneDelegate = UIApplication.shared.firstWindowScene?.delegate as? SceneDelegate,
              let mainWindow = sceneDelegate.mainWindow,
              prepareWindow(in: sceneDelegate)
        else {
            return
        }
        mainWindow.endEditing(true)
        let wasShowing = presentationState == .visible
        presentationState = .presenting
        let modelControllerToRestore: GalleryItemModelController?
        if viewController === pipController {
            source = pipSource
            modelControllerToRestore = pipModelController
        } else {
            modelControllerToRestore = nil
        }
        let viewControllerToHide = wasShowing ? currentItemViewController : nil
        let show = { [self] (transitionOverlayView: GalleryTransitionOverlayView?) in
            guard presentationState != .tornDown else {
                return
            }
            sceneDelegate.showGalleryWindow()
            animate(animations: {
                self.setStatusBarHidden(true)
                viewControllerToHide?.view.alpha = 0
                if let transitionOverlayView {
                    transitionOverlayView.backgroundView.alpha = 1
                } else {
                    self.backgroundView.alpha = 1
                }
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
                self.backgroundView.alpha = 1
                self.pageViewController.view.alpha = 1
                self.endTransition {
                    guard self.presentationState != .tornDown else {
                        return
                    }
                    self.presentationState = .visible
                    self.setNeedsUpdateOfSupportedInterfaceOrientationsIfNeeded()
                    if !wasShowing {
                        self.source?.galleryViewController(self, didShow: item)
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
            backgroundView.alpha = 0
            pageViewController.view.alpha = 0
            let didBeginTransition = beginTransition(
                backgroundAlpha: 0,
            ) { [self] transitionOverlayView in
                source?.galleryViewController(self, willShow: item)
                show(transitionOverlayView)
            }
            if !didBeginTransition, presentationState != .tornDown {
                finishDismissal()
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
              let mainWindow = sceneDelegate.mainWindow
        else {
            return
        }
        if let completion {
            dismissalCompletions.append(completion)
        }
        presentationState = .dismissing
        source?.galleryViewController(self, willDismiss: item)
        let didBeginTransition = beginTransition(
            backgroundAlpha: 0,
        ) { [self] transitionOverlayView in
            guard presentationState != .tornDown else {
                return
            }
            pageViewController.view.alpha = 0
            pageViewController.view.transform = .identity
            
            let transitionSource = source?.galleryViewController(self, cellFor: item)
                .flatMap { $0.window === mainWindow ? $0 : nil }
            if transitionView == nil {
                transitionView = transitionSource?.transitionViewType.init() ?? GalleryTransitionView()
            }
            if let transitionView = transitionView {
                transitionOverlayView.addSubview(transitionView)
                transitionView.load(viewController: itemViewController)
                transitionView.center.y += transitionViewInitialOffsetY
                transitionView.alpha = 1
            }
            
            // Let the overlay own dimming while the gallery window stays visible.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            transitionOverlayView.backgroundView.alpha = backgroundView.alpha
            backgroundView.alpha = 0
            CATransaction.commit()
            
            let relativeOffset: CGFloat?
            if item.shouldLayoutAsArticle, let offset = (itemViewController as? GalleryImageItemViewController)?.relativeOffset {
                relativeOffset = offset
            } else {
                relativeOffset = nil
            }
            if let transitionSource {
                transitionView?.transition(to: transitionSource)
            } else {
                animate(animations: {
                    self.transitionView?.frame.origin.y = self.view.bounds.height
                })
            }
            currentItemViewController?.isFocused = false
            animate(animations: {
                self.setStatusBarHidden(self.statusBarHiddenBeforePresentation)
                transitionOverlayView.backgroundView.alpha = 0
            }, completion: {
                guard self.presentationState != .tornDown else {
                    return
                }
                // Restore the source before removing the snapshot that covers it.
                self.source?.galleryViewController(self, didDismiss: item, relativeOffset: relativeOffset)
                mainWindow.layoutIfNeeded()
                CATransaction.flush()
                sceneDelegate.hideGalleryWindow()
                self.transitionView?.removeFromSuperview()
                self.endTransition {
                    guard self.presentationState != .tornDown else {
                        return
                    }
                    self.pageViewController.view.alpha = 1
                    self.finishDismissal()
                }
            })
        }
        if !didBeginTransition, presentationState != .tornDown {
            currentItemViewController?.isFocused = false
            source?.galleryViewController(self, didDismiss: item, relativeOffset: nil)
            sceneDelegate.hideGalleryWindow()
            finishDismissal()
        }
    }
    
    func dismiss(pipController: GalleryVideoItemViewController) {
        guard presentationState == .visible,
              let item = pipController.item,
              let sceneDelegate,
              let mainWindow = sceneDelegate.mainWindow,
              let container = mainWindow.rootViewController as? HomeContainerViewController
        else {
            return
        }
        presentationState = .dismissing
        self.pipController = pipController
        pipSource = source
        pipModelController = modelController
        let didBeginTransition = beginTransition(
            backgroundAlpha: 0,
        ) { [self] transitionOverlayView in
            guard presentationState != .tornDown else {
                return
            }
            pageViewController.setViewControllers([UIViewController()], direction: .forward, animated: false, completion: nil)
            pageViewController.view.alpha = 0
            // Keep the PiP item's browsing context intact while another gallery is opened.
            let nextModelController = GalleryItemModelController()
            nextModelController.galleryViewController = self
            nextModelController.conversationId = modelController.conversationId
            nextModelController.direction = modelController.direction
            modelController = nextModelController
            pageViewController.dataSource = nextModelController
            
            addChild(pipController)
            transitionOverlayView.addSubview(pipController.view)
            pipController.didMove(toParent: self)
            // Keep the player in the visible gallery window throughout the PiP animation.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            transitionOverlayView.backgroundView.alpha = backgroundView.alpha
            backgroundView.alpha = 0
            CATransaction.commit()
            
            animate(animations: {
                self.setStatusBarHidden(self.statusBarHiddenBeforePresentation)
                transitionOverlayView.backgroundView.alpha = 0
            }, completion: {
                guard self.presentationState != .tornDown else {
                    return
                }
                if pipController.parent === self,
                   pipController.view.superview === transitionOverlayView
                {
                    pipController.willMove(toParent: nil)
                    pipController.view.removeFromSuperview()
                    pipController.removeFromParent()
                    container.addChild(pipController)
                    container.view.addSubview(pipController.view)
                    pipController.didMove(toParent: container)
                }
                self.source?.galleryViewController(self, didDismiss: item, relativeOffset: nil)
                mainWindow.layoutIfNeeded()
                CATransaction.flush()
                sceneDelegate.hideGalleryWindow()
                self.endTransition {
                    guard self.presentationState != .tornDown else {
                        return
                    }
                    self.finishDismissal()
                }
            })
        }
        if !didBeginTransition, presentationState != .tornDown {
            // PiP is already starting; finish the handoff without a transition overlay.
            pageViewController.setViewControllers([UIViewController()], direction: .forward, animated: false, completion: nil)
            let nextModelController = GalleryItemModelController()
            nextModelController.galleryViewController = self
            nextModelController.conversationId = modelController.conversationId
            nextModelController.direction = modelController.direction
            modelController = nextModelController
            pageViewController.dataSource = nextModelController
            
            container.addChild(pipController)
            container.view.addSubview(pipController.view)
            pipController.didMove(toParent: container)
            source?.galleryViewController(self, didDismiss: item, relativeOffset: nil)
            sceneDelegate.hideGalleryWindow()
            finishDismissal()
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
        dismissForNavigation {
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
        }
        if !(source is StaticMessagesViewController) {
            source = conversationController
        }
        dismissForNavigation {
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
                source?.galleryViewController(self, willDismiss: item)
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
                        self.source?.galleryViewController(self, didCancelDismissalFor: item)
                    }
                })
            }
        default:
            break
        }
    }
    
    @objc func longPressAction(_ recognizer: UILongPressGestureRecognizer) {
        guard presentationState == .visible,
              recognizer.state == .began,
              let itemViewController = currentItemViewController,
              !itemViewController.supportedActions.isEmpty
        else {
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
                self.dismissForNavigation {
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
        endTransition(completion: nil)
        source = nil
    }
    
    func beginTransition(
        backgroundAlpha: CGFloat,
        completion: @escaping (GalleryTransitionOverlayView) -> Void,
    ) -> Bool {
        guard presentationState != .tornDown, transitionOverlayView == nil else {
            return false
        }
        let overlayView = GalleryTransitionOverlayView(
            frame: view.bounds,
            backgroundAlpha: backgroundAlpha,
        )
        transitionOverlayView = overlayView
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlayView)
        completion(overlayView)
        return true
    }
    
    func endTransition(completion: (() -> Void)?) {
        let overlayView = transitionOverlayView
        transitionOverlayView = nil
        overlayView?.backgroundView.layer.removeAllAnimations()
        overlayView?.removeFromSuperview()
        completion?()
    }
    
    private func dismissForNavigation(completion: @escaping () -> Void) {
        let messagesPreview = source as? StaticMessagesViewController
        dismiss(transitionViewInitialOffsetY: 0) {
            if let messagesPreview {
                messagesPreview.dismissForInteraction { _ in
                    completion()
                }
            } else {
                completion()
            }
        }
    }
    
    private func finishDismissal() {
        presentationState = .hidden
        pendingDismissalOffsetY = nil
        pageViewController.view.alpha = 1
        pageViewController.view.transform = .identity
        let completions = dismissalCompletions
        dismissalCompletions.removeAll()
        for completion in completions {
            guard presentationState != .tornDown else {
                return
            }
            completion()
        }
    }
    
    private func prepareWindow(in sceneDelegate: SceneDelegate) -> Bool {
        guard let galleryWindow = sceneDelegate.galleryWindow,
              galleryWindow.galleryViewController === self
        else {
            return false
        }
        self.sceneDelegate = sceneDelegate
        if presentationState == .hidden {
            statusBarHiddenBeforePresentation = galleryWindow.windowScene?.statusBarManager?.isStatusBarHidden ?? false
            setStatusBarHidden(statusBarHiddenBeforePresentation)
        }
        loadViewIfNeeded()
        view.frame = galleryWindow.bounds
        view.layoutIfNeeded()
        return true
    }
    
    private func setStatusBarHidden(_ hidden: Bool) {
        isStatusBarHidden = hidden
        setNeedsStatusBarAppearanceUpdate()
    }
    
    private func setNeedsUpdateOfSupportedInterfaceOrientationsIfNeeded() {
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            UIViewController.attemptRotationToDeviceOrientation()
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
