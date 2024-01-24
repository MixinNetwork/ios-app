import UIKit
import MixinServices

final class HomeAppsViewController: UIViewController {
    
    @IBOutlet weak var homeTitleLabel: UILabel!
    @IBOutlet weak var pinnedCollectionView: UICollectionView!
    @IBOutlet weak var pinnedPlaceholderStackView: UIStackView!
    @IBOutlet var pinnedPlaceholderViews: [UIImageView]!
    @IBOutlet weak var candidateCollectionView: UICollectionView!
    @IBOutlet weak var candidateCollectionLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var pageControl: UIPageControl!
    
    @IBOutlet weak var titleBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinnedWrapperHeightConstraint: NSLayoutConstraint!
    
    private let storage = HomeAppsStorage()
    
    private lazy var candidateEmptyHintLabel: UILabel = {
        let label = UILabel()
        label.text = R.string.localizable.bot_empty_tip()
        label.backgroundColor = .background
        label.textColor = R.color.text_tertiary()!
        label.numberOfLines = 0
        label.textAlignment = .center
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        candidateEmptyHintLabelIfLoaded = label
        return label
    }()
    
    private var candidateEmptyHintLabelIfLoaded: UILabel?
    
    private var appsManager: HomeAppsManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pinnedPlaceholderViews.sort { $0.tag < $1.tag }
        appsManager = HomeAppsManager(viewController: self,
                                      candidateCollectionView: candidateCollectionView,
                                      pinnedCollectionView: pinnedCollectionView)
        appsManager.delegate = self
        storage.load { pinnedItems, candidateItems in
            self.pageControl.numberOfPages = candidateItems.count
            self.setCandidateEmptyHintHidden(!candidateItems.isEmpty)
            self.updatePinnedPlaceholderViewsHidden(with: pinnedItems.count)
            self.appsManager.reloadData(pinnedItems: pinnedItems, candidateItems: candidateItems)
        }
        pageControl.currentPage = 0
        updateHomeTitleLabel(isEditing: false)
        pinnedPlaceholderStackView.spacing = HomeAppsMode.pinned.minimumInteritemSpacing
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showPinTipsIfNeeded()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        appsManager.leaveEditingMode()
    }
    
    @IBAction func pageControlValueChanged(_ sender: UIPageControl) {
        let x = CGFloat(pageControl.currentPage) * candidateCollectionView.frame.width
        let offset = CGPoint(x: x, y: 0)
        candidateCollectionView.setContentOffset(offset, animated: true)
    }
    
}

extension HomeAppsViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = scrollView.contentOffset.x / scrollView.frame.size.width
        pageControl.currentPage = Int(round(page))
    }
    
}

extension HomeAppsViewController {
    
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
    
    private func showPinTipsIfNeeded() {
        guard !AppGroupUserDefaults.User.homeAppsPinTips else {
            return
        }
        let viewController = HomeAppsPinTipsViewController()
        viewController.modalPresentationStyle = .overFullScreen
        viewController.modalTransitionStyle = .crossDissolve
        viewController.loadViewIfNeeded()
        viewController.pinnedAppViewTopConstraint.constant = pinnedCollectionView.convert(.zero, to: view).y
        viewController.appIconViewTopConstraint.constant = candidateCollectionView.convert(.zero, to: view).y
        present(viewController, animated: true, completion: nil)
    }
    
    private func updatePinnedPlaceholderViewsHidden(with pinnedAppCount: Int) {
        for (index, view) in pinnedPlaceholderViews.enumerated() {
            let hide = index < pinnedAppCount
            view.alpha = hide ? 0 : 1
        }
    }
    
    private func updateHomeTitleLabel(isEditing: Bool) {
        if isEditing {
            homeTitleLabel.textColor = .theme
            homeTitleLabel.text = R.string.localizable.done()
        } else {
            homeTitleLabel.textColor = R.color.text()!
            homeTitleLabel.text = R.string.localizable.explore()
        }
    }
    
}

extension HomeAppsViewController: HomeAppsManagerDelegate {
    
    func homeAppsManager(_ manager: HomeAppsManager, didSelectApp app: HomeApp) {
        switch app {
        case let .embedded(app):
            app.action()
        case let .external(user):
            let item = UserItem.createUser(from: user)
            let vc = UserProfileViewController(user: item)
            present(vc, animated: true, completion: nil)
        }
    }
    
    func homeAppsManager(_ manager: HomeAppsManager, didMoveToPage page: Int) {
        pageControl.currentPage = page
    }
    
    func homeAppsManager(_ manager: HomeAppsManager, didUpdatePageCount pageCount: Int) {
        pageControl.numberOfPages = pageCount
    }
    
    func homeAppsManagerDidUpdateItems(_ manager: HomeAppsManager) {
        storage.save(pinnedApps: manager.pinnedItems)
        storage.save(candidateItems: manager.items)
        setCandidateEmptyHintHidden(!manager.items.isEmpty)
        updatePinnedPlaceholderViewsHidden(with: manager.pinnedItems.count)
    }
    
    func homeAppsManagerDidEnterEditingMode(_ manager: HomeAppsManager) {
        updateHomeTitleLabel(isEditing: true)
    }
    
    func homeAppsManagerDidLeaveEditingMode(_ manager: HomeAppsManager) {
        updateHomeTitleLabel(isEditing: false)
    }
    
    func homeAppsManager(_ manager: HomeAppsManager, didBeginFolderDragOutWithTransfer transfer: HomeAppsDragInteractionTransfer) {
        
    }
    
}
