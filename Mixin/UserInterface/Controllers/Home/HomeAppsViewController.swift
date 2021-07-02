import UIKit
import MixinServices

final class HomeAppsViewController: UIViewController {
    
    @IBOutlet weak var noPinnedHintLabel: UILabel!
    @IBOutlet weak var pinnedCollectionView: UICollectionView!
    @IBOutlet weak var pinnedCollectionLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var candidateCollectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    @IBOutlet weak var titleBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinnedCollectionViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinnedCollectionViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinnedWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var candidateCollectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var pageControlTopConstraint: NSLayoutConstraint!
    
    private var candidateCollectionLayout: HomeAppsFlowLayout!
    
    private lazy var candidateEmptyHintLabel: UILabel = {
        let label = UILabel()
        label.text = R.string.localizable.home_apps_candidate_empty()
        label.backgroundColor = .background
        label.textColor = .accessoryText
        label.numberOfLines = 0
        label.textAlignment = .center
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        candidateEmptyHintLabelIfLoaded = label
        return label
    }()
    private lazy var backgroundButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor.black.withAlphaComponent(0)
        button.addTarget(self, action: #selector(backgroundTappingAction), for: .touchUpInside)
        return button
    }()
    
    private var pinnedAppModelController: PinnedHomeAppsModelController!
    private var candidateAppModelController: CandidateHomeAppsModelController!
    private var candidateEmptyHintLabelIfLoaded: UILabel?
    
    private var appsManager: HomeAppsManager!

    class func instance() -> HomeAppsViewController {
        R.storyboard.home.apps()!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        pinnedAppModelController = PinnedHomeAppsModelController(collectionView: pinnedCollectionView)
//        pinnedCollectionView.dataSource = pinnedAppModelController
//        pinnedCollectionView.delegate = self
//        pinnedCollectionView.dragInteractionEnabled = true
//        pinnedCollectionView.dragDelegate = pinnedAppModelController
//        pinnedCollectionView.dropDelegate = pinnedAppModelController
//        pinnedAppModelController.reloadData(completion: { [weak self] apps in
//            self?.noPinnedHintLabel.isHidden = !apps.isEmpty
//        })
//
//        let pageInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
//        let spacing: CGFloat = {
//            let cellsWidth = candidateCollectionCellSize.width * CGFloat(cellCount.perRow)
//            let totalSpacing = AppDelegate.current.mainWindow.bounds.width - pageInset.horizontal - cellsWidth
//            return floor(totalSpacing / CGFloat(cellCount.perRow - 1))
//        }()
//        candidateCollectionLayout = HomeAppsFlowLayout(lineSpacing: 0, interitemSpacing: spacing, numberOfRows: cellCount.perColumn, numberOfColumns: cellCount.perRow, cellSize: candidateCollectionCellSize, pageInset: pageInset)
//        candidateCollectionView.collectionViewLayout = candidateCollectionLayout
//        candidateAppModelController = CandidateHomeAppsModelController(collectionView: candidateCollectionView)
//        candidateCollectionView.dataSource = candidateAppModelController
//        candidateCollectionView.delegate = self
//        candidateCollectionView.dragInteractionEnabled = true
//        candidateCollectionView.dragDelegate = candidateAppModelController
//        candidateCollectionView.addInteraction(candidateAppModelController.dropInteraction)
//        candidateAppModelController.reloadData(completion: { [weak self] (apps) in
//            self?.setCandidateEmptyHintHidden(!apps.isEmpty)
//            self?.updateNumberOfPagesForPageControl(with: apps.count)
//        })
        
        //TODO: ‼️ fix this after updating data
        noPinnedHintLabel.isHidden = true
        setCandidateEmptyHintHidden(true)
        //TODO: ‼️ remove mock data
        let items: [[BotItem]] = [
            [Bot(id: "1", name: "1"), Bot(id: "2", name: "2"), Bot(id: "3", name: "3"), Bot(id: "4", name: "4"), Bot(id: "44", name: "44"),
             BotFolder(id: "111", name: "111", pages: [
                [Bot(id: "1111", name: "1111"), Bot(id: "2222", name: "22222"), Bot(id: "3333", name: "33333"), Bot(id: "4444", name: "44444"),  Bot(id: "5555", name: "55555"),  Bot(id: "6666", name: "66666"),  Bot(id: "7777", name: "77777"),  Bot(id: "8888", name: "88888"),  Bot(id: "9999", name: "99999")]
             ])],
            [Bot(id: "5", name: "5"), Bot(id: "6", name: "6"), Bot(id: "7", name: "7"), Bot(id: "8", name: "8"), Bot(id: "13", name: "13")]
        ]
        let pinnedItems = [Bot(id: "9", name: "9"), Bot(id: "10", name: "10"), Bot(id: "11", name: "11"), Bot(id: "12", name: "12")]
        
        appsManager = HomeAppsManager(isHome: true, viewController: self, candidateCollectionView: candidateCollectionView, items: items, pinnedCollectionView: pinnedCollectionView, pinnedItems: pinnedItems)
        appsManager.delegate = self
        
        pageControl.numberOfPages = appsManager.items.count
        pageControl.currentPage = 0
        
        candidateCollectionViewHeightConstraint.constant = HomeAppsMode.regular.itemSize.height * CGFloat(HomeAppsMode.regular.rowsPerPage)
        updatePreferredContentSizeHeight()

        NotificationCenter.default.addObserver(self, selector: #selector(updateNoPinnedHint), name: AppGroupUserDefaults.User.homeAppIdsDidChangeNotification, object: nil)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        DispatchQueue.main.async {
            self.updatePreferredContentSizeHeight()
        }
    }
    
    @IBAction func pageControlValueChanged(_ sender: UIPageControl) {
        let x = CGFloat(pageControl.currentPage) * candidateCollectionView.frame.width
        let offset = CGPoint(x: x, y: 0)
        candidateCollectionView.setContentOffset(offset, animated: true)
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismissAsChild(completion: nil)
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
            dismissAsChild(completion: app.action)
        case let .external(user):
            let item = UserItem.createUser(from: user)
            let vc = UserProfileViewController(user: item)
            present(vc, animated: true, completion: nil)
        }
    }
    
}

extension HomeAppsViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = scrollView.contentOffset.x / scrollView.frame.size.width
        pageControl.currentPage = Int(round(page))
    }
    
}

extension HomeAppsViewController {
    
    func dismissAsChild(completion: (() -> Void)?) {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.frame.origin.y = self.backgroundButton.bounds.height
            self.backgroundButton.backgroundColor = UIColor.black.withAlphaComponent(0)
        }) { (finished) in
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
            self.backgroundButton.removeFromSuperview()
            completion?()
        }
    }
    
    func presentAsChild(of parent: UIViewController) {
        loadViewIfNeeded()
        backgroundButton.frame = parent.view.bounds
        backgroundButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        parent.addChild(self)
        parent.view.addSubview(backgroundButton)
        didMove(toParent: parent)
        
        view.frame = CGRect(x: 0,
                            y: backgroundButton.bounds.height,
                            width: backgroundButton.bounds.width,
                            height: backgroundButton.bounds.height)
        view.autoresizingMask = .flexibleTopMargin
        backgroundButton.addSubview(view)
        UIView.animate(withDuration: 0.3, animations: {
            self.view.frame.origin.y = self.backgroundButton.bounds.height - self.preferredContentSize.height
            self.backgroundButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        })
    }
    
    @objc private func backgroundTappingAction() {
        dismissAsChild(completion: nil)
    }
    
    @objc private func updateNoPinnedHint() {
        noPinnedHintLabel.isHidden = !AppGroupUserDefaults.User.homeAppIds.isEmpty
    }
    
    private func updatePreferredContentSizeHeight() {
        guard !isBeingDismissed else {
            return
        }
        let height = preferredContentHeight()
        preferredContentSize.height = height
        view.frame.origin.y = backgroundButton.bounds.height - height
    }
    
    private func preferredContentHeight() -> CGFloat {
        view.layoutIfNeeded()
        return titleBarHeightConstraint.constant
            + pinnedWrapperHeightConstraint.constant
            + candidateCollectionViewHeightConstraint.constant
            + pageControlTopConstraint.constant
            + ceil(pageControl.bounds.height)
            + AppDelegate.current.mainWindow.safeAreaInsets.bottom
            + 22
    }
    
    private func setCandidateEmptyHintHidden(_ hidden: Bool) {
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
            candidateEmptyHintLabel.frame = CGRect(x: x, y: y, width: width, height: round(height / 3 * 2))
            if candidateEmptyHintLabel.superview == nil {
                candidateCollectionView.addSubview(candidateEmptyHintLabel)
            }
        }
    }
    
}

extension HomeAppsViewController: HomeAppsManagerDelegate {
    
    func didUpdateItems(on manager: HomeAppsManager) {
        //TODO: ‼️ uddate data
    }
    
    func didUpdate(pageCount: Int, on manager: HomeAppsManager) {
        pageControl.numberOfPages = pageCount
    }
    
    func didMove(toPage page: Int, on manager: HomeAppsManager) {
        pageControl.currentPage = page
    }
    
    func collectionViewDidScroll(_ collectionView: UICollectionView, on manager: HomeAppsManager) {}
    
    func didEnterEditingMode(on manager: HomeAppsManager) {}
    
    func didBeginFolderDragOut(transfer: HomeAppsDragInteractionTransfer, on manager: HomeAppsManager) {}
    
    func didSelect(app: Bot, on manager: HomeAppsManager) {}
    
}
