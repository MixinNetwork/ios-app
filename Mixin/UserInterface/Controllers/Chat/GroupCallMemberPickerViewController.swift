import UIKit
import MixinServices

class GroupCallMemberPickerViewController: ResizablePopupViewController {
    
    typealias OnConfirmation = ([UserItem]) -> Void
    
    enum Appearance {
        case startNewCall
        case appendToExistedCall
    }
    
    var onConfirmation: OnConfirmation?
    
    var fixedSelections: [UserItem] {
        get {
            contentViewController.fixedSelections
        }
        set {
            contentViewController.fixedSelections = newValue
        }
    }
    
    var appearance: Appearance {
        get {
            contentViewController.appearance
        }
        set {
            contentViewController.appearance = newValue
        }
    }
    
    private let contentViewController: GroupCallMemberPickerContentViewController
    
    private lazy var resizeRecognizerDelegate = ResizeCoordinator(tableView: contentViewController.tableView, collectionView: contentViewController.collectionView)
    
    override var resizableScrollView: UIScrollView? {
        contentViewController.tableView
    }
    
    init(conversation: ConversationItem) {
        self.contentViewController = GroupCallMemberPickerContentViewController(conversation: conversation)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = PopupPresentationManager.shared
        loadViewIfNeeded()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        contentViewController.loadViewIfNeeded()
        super.viewDidLoad()
        view.clipsToBounds = true
        addChild(contentViewController)
        view.addSubview(contentViewController.view)
        contentViewController.view.snp.makeEdgesEqualToSuperview()
        contentViewController.didMove(toParent: self)
        contentViewController.view.addGestureRecognizer(resizeRecognizer)
        resizeRecognizer.delegate = resizeRecognizerDelegate
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    override func preferredContentHeight(forSize size: Size) -> CGFloat {
        let window = AppDelegate.current.mainWindow
        switch size {
        case .expanded, .unavailable:
            return window.bounds.height - window.safeAreaInsets.top
        case .compressed:
            return floor(window.bounds.height / 3 * 2)
        }
    }
    
    @objc func keyboardWillShow(_ notification: Notification) {
        guard size == .compressed else {
            return
        }
        size = .expanded
        let animator = makeSizeAnimator(destination: size)
        animator.addCompletion { (position) in
            self.size = .expanded
            self.updatePreferredContentSizeHeight(size: .expanded)
            self.setNeedsSizeAppearanceUpdated(size: .expanded)
            self.sizeAnimator = nil
            self.resizeRecognizer.isEnabled = true
        }
        sizeAnimator = animator
        resizeRecognizer.isEnabled = false
        animator.startAnimation()
    }
    
}

extension GroupCallMemberPickerViewController {
    
    class ResizeCoordinator: PopupResizeGestureCoordinator {
        
        private unowned let collectionView: UICollectionView
        
        init(tableView: UITableView, collectionView: UICollectionView) {
            self.collectionView = collectionView
            super.init(scrollView: tableView)
        }
        
        override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer != collectionView.panGestureRecognizer
        }
        
    }
    
}
