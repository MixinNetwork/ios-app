import UIKit

class GroupCallMemberPickerViewController: ResizablePopupViewController {
    
    private let contentViewController: GroupCallMemberPickerContentViewController
    
    private lazy var resizeRecognizerDelegate = ResizeCoordinator(tableView: contentViewController.tableView, collectionView: contentViewController.collectionView)
    
    override var resizableScrollView: UIScrollView? {
        contentViewController.tableView
    }
    
    init(conversationId: String) {
        self.contentViewController = GroupCallMemberPickerContentViewController(conversationId: conversationId)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = PopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = true
        addChild(contentViewController)
        view.addSubview(contentViewController.view)
        contentViewController.view.snp.makeEdgesEqualToSuperview()
        contentViewController.didMove(toParent: self)
        contentViewController.view.addGestureRecognizer(resizeRecognizer)
        resizeRecognizer.delegate = resizeRecognizerDelegate
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
