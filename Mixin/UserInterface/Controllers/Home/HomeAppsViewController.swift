import UIKit
import MixinServices
import AlignedCollectionViewFlowLayout

final class HomeAppsViewController: ResizablePopupViewController {
    
    @IBOutlet weak var noPinnedHintLabel: UILabel!
    @IBOutlet weak var pinnedCollectionView: UICollectionView!
    @IBOutlet weak var pinnedCollectionLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var candidateCollectionView: UICollectionView!
    @IBOutlet weak var candidateCollectionLayout: UICollectionViewFlowLayout!
    
    @IBOutlet weak var titleBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinnedWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var candidateCollectionViewHeightConstraint: NSLayoutConstraint!
    
    override var resizableScrollView: UIScrollView? {
        candidateCollectionView
    }
    
    private let cellCountPerRow = 4
    
    private lazy var resizeGestureCoordinator = HomeAppResizeGestureCoordinator(scrollView: candidateCollectionView)
    private lazy var candidateEmptyHintLabel: UILabel = {
        let label = UILabel()
        label.text = R.string.localizable.home_apps_candidate_empty()
        label.backgroundColor = .background
        label.textColor = .accessoryText
        label.numberOfLines = 0
        label.textAlignment = .center
        label.setFont(scaledFor: .systemFont(ofSize: 12), adjustForContentSize: true)
        candidateEmptyHintLabelIfLoaded = label
        return label
    }()
    
    private var pinnedAppModelController: PinnedHomeAppsModelController!
    private var candidateAppModelController: CandidateHomeAppsModelController!
    private var candidateEmptyHintLabelIfLoaded: UILabel?
    
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
        pinnedCollectionView.delegate = self
        pinnedCollectionView.dragInteractionEnabled = true
        pinnedCollectionView.dragDelegate = pinnedAppModelController
        pinnedCollectionView.dropDelegate = pinnedAppModelController
        pinnedAppModelController.reloadData(completion: { [weak self] apps in
            self?.noPinnedHintLabel.isHidden = !apps.isEmpty
        })
        
        candidateAppModelController = CandidateHomeAppsModelController(collectionView: candidateCollectionView)
        candidateCollectionView.dataSource = candidateAppModelController
        candidateCollectionView.delegate = self
        candidateCollectionView.dragInteractionEnabled = true
        candidateCollectionView.dragDelegate = candidateAppModelController
        candidateCollectionView.addInteraction(candidateAppModelController.dropInteraction)
        candidateAppModelController.reloadData(completion: { [weak self] users in
            self?.setCandidateEmptyHintHidden(!users.isEmpty)
        })
        
        let window = AppDelegate.current.window
        let maxHeight = window.bounds.height - window.safeAreaInsets.top
        let candidateHeight = maxHeight - titleBarHeightConstraint.constant - pinnedWrapperHeightConstraint.constant
        candidateCollectionViewHeightConstraint.constant = candidateHeight
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateNoPinnedHint), name: AppGroupUserDefaults.User.homeAppIdsDidChangeNotification, object: nil)
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
        
        let inset = candidateSpacing - 20 + (candidateCollectionLayout.itemSize.width - pinnedCollectionLayout.itemSize.width) / 2
        pinnedCollectionLayout.sectionInset.left = inset
        pinnedCollectionLayout.sectionInset.right = inset
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
            return window.bounds.height / 3 * 2
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func updateNoPinnedHint() {
        noPinnedHintLabel.isHidden = !AppGroupUserDefaults.User.homeAppIds.isEmpty
    }
    
    func setCandidateEmptyHintHidden(_ hidden: Bool) {
        if hidden {
            candidateEmptyHintLabelIfLoaded?.removeFromSuperview()
        } else {
            let x = candidateCollectionLayout.sectionInset.left
            let y = candidateCollectionLayout.itemSize.height
            let width = candidateCollectionView.bounds.width
                - candidateCollectionLayout.sectionInset.horizontal
            let height = preferredContentSize.height
                - titleBarHeightConstraint.constant
                - pinnedWrapperHeightConstraint.constant
                - candidateCollectionLayout.itemSize.height
            candidateEmptyHintLabel.frame = CGRect(x: x, y: y, width: width, height: height)
            if candidateEmptyHintLabel.superview == nil {
                candidateCollectionView.addSubview(candidateEmptyHintLabel)
            }
        }
    }
    
}

extension HomeAppsViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let app: HomeApp
        if collectionView == pinnedCollectionView {
            app = pinnedAppModelController.apps[indexPath.row]
        } else if collectionView == candidateCollectionView {
            app = candidateAppModelController.apps[indexPath.row]
        } else {
            return
        }
        switch app {
        case let .embedded(app):
            dismiss(animated: true, completion: app.action)
        case let .external(user):
            let item = UserItem.createUser(from: user)
            let vc = UserProfileViewController(user: item)
            dismissAndPresent(vc)
        }
    }
    
}
