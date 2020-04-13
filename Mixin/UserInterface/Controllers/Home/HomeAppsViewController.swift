import UIKit
import MixinServices
import AlignedCollectionViewFlowLayout

final class HomeAppsViewController: ResizablePopupViewController {
    
    @IBOutlet weak var pinnedCollectionView: UICollectionView!
    @IBOutlet weak var pinnedCollectionLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var candidateCollectionView: UICollectionView!
    @IBOutlet weak var candidateCollectionLayout: UICollectionViewFlowLayout!
    
    @IBOutlet weak var titleBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var selectedWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var candidateCollectionViewHeightConstraint: NSLayoutConstraint!
    
    override var resizableScrollView: UIScrollView? {
        candidateCollectionView
    }
    
    private let cellCountPerRow = 4
    
    private lazy var resizeGestureCoordinator = HomeAppResizeGestureCoordinator(scrollView: candidateCollectionView)
    
    private var pinnedAppModelController: PinnedHomeAppsModelController!
    private var candidateAppModelController: CandidateHomeAppsModelController!
    
    class func instance() -> HomeAppsViewController {
        let vc = R.storyboard.home.apps()!
        vc.modalPresentationStyle = .custom
        vc.transitioningDelegate = PopupPresentationManager.shared
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addGestureRecognizer(resizeRecognizer)
        resizeRecognizer.delegate = resizeGestureCoordinator
        
        pinnedAppModelController = PinnedHomeAppsModelController(collectionView: pinnedCollectionView)
        pinnedCollectionView.dataSource = pinnedAppModelController
        pinnedCollectionView.dragInteractionEnabled = true
        pinnedCollectionView.dragDelegate = pinnedAppModelController
        pinnedCollectionView.dropDelegate = pinnedAppModelController
        pinnedAppModelController.reloadData()
        
        candidateAppModelController = CandidateHomeAppsModelController(collectionView: candidateCollectionView)
        candidateCollectionView.dataSource = candidateAppModelController
        candidateCollectionView.dragInteractionEnabled = true
        candidateCollectionView.dragDelegate = candidateAppModelController
        candidateCollectionView.addInteraction(candidateAppModelController.dropInteraction)
        candidateAppModelController.reloadData()
        
        let window = AppDelegate.current.window
        let maxHeight = window.bounds.height - window.safeAreaInsets.top
        let deselectedHeight = maxHeight - titleBarHeightConstraint.constant - selectedWrapperHeightConstraint.constant
        candidateCollectionViewHeightConstraint.constant = deselectedHeight
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        let candidateSpacing: CGFloat = {
            let cellsWidth = candidateCollectionLayout.itemSize.width * CGFloat(cellCountPerRow)
            let totalSpacing = view.bounds.width - cellsWidth
            return floor(totalSpacing / CGFloat(cellCountPerRow + 1))
        }()
        candidateCollectionLayout.sectionInset.left = candidateSpacing
        candidateCollectionLayout.sectionInset.right = candidateSpacing
        candidateCollectionLayout.minimumInteritemSpacing = candidateSpacing
        
        pinnedCollectionLayout.sectionInset.left = max(8, candidateSpacing - 20)
        pinnedCollectionLayout.sectionInset.right = max(8, candidateSpacing - 20)
        let pinnedSpacing: CGFloat = {
            let cellsWidth = pinnedCollectionLayout.itemSize.width * CGFloat(cellCountPerRow)
            let totalSpacing = view.bounds.width - 40 - pinnedCollectionLayout.sectionInset.horizontal - cellsWidth
            return floor(totalSpacing / CGFloat(cellCountPerRow))
        }()
        pinnedCollectionLayout.minimumInteritemSpacing = pinnedSpacing
    }
    
    override func preferredContentHeight(forSize size: Size) -> CGFloat {
        view.layoutIfNeeded()
        let window = AppDelegate.current.window
        switch size {
        case .expanded, .unavailable:
            return window.bounds.height - window.safeAreaInsets.top
        case .compressed:
            return window.bounds.height / 2
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
}
