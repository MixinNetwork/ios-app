import UIKit
import MixinServices

final class HomeAppsViewController: UIViewController {
    
    @IBOutlet weak var homeTitleLabel: UILabel!
    @IBOutlet weak var pinnedCollectionView: UICollectionView!
    @IBOutlet weak var candidateCollectionView: UICollectionView!
    @IBOutlet weak var candidateCollectionLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet var pinnedPlaceholderViews: [UIImageView]!
    
    @IBOutlet weak var titleBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinnedWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var candidateCollectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var pageControlTopConstraint: NSLayoutConstraint!
    @IBOutlet var pinnedPlaceholderViewLeadingConstraints: [NSLayoutConstraint]!
    
    private let storage = HomeAppsStorage()
    
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
    private var candidateEmptyHintLabelIfLoaded: UILabel?
    
    private var appsManager: HomeAppsManager!
    
    class func instance() -> HomeAppsViewController {
        R.storyboard.home.apps()!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.cornerRadius = 13
        appsManager = HomeAppsManager(viewController: self, candidateCollectionView: candidateCollectionView, pinnedCollectionView: pinnedCollectionView)
        appsManager.delegate = self
        storage.load { pinnedItems, candidateItems in
            self.pageControl.numberOfPages = candidateItems.count
            self.setCandidateEmptyHintHidden(!candidateItems.isEmpty)
            self.updatePinnedPlaceholderViewsHidden(with: pinnedItems.count)
            self.appsManager.reloadData(pinnedItems: pinnedItems, candidateItems: candidateItems)
        }
        pageControl.currentPage = 0
        updateHomeTitleLabel(isEditing: false)
        pinnedPlaceholderViewLeadingConstraints.forEach({ $0.constant = HomeAppsMode.pinned.minimumInteritemSpacing })
        candidateCollectionViewHeightConstraint.constant = HomeAppsMode.regular.itemSize.height * CGFloat(HomeAppsMode.regular.rowsPerPage)
        updatePreferredContentSizeHeight()
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
        dismiss()
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
        UIView.animate(withDuration: 0.3) {
            self.view.frame.origin.y = self.backgroundButton.bounds.height - self.preferredContentSize.height
            self.backgroundButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        } completion: { _ in
            self.showPinTipsIfNeeded()
        }
        
    }
    
    @objc private func backgroundTappingAction() {
        dismiss()
    }
    
    private func dismiss() {
        if appsManager.isEditing {
            appsManager.leaveEditingMode()
        } else {
            dismissAsChild(completion: nil)
        }
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
        let height = titleBarHeightConstraint.constant
            + pinnedWrapperHeightConstraint.constant
            + candidateCollectionViewHeightConstraint.constant
            + pageControlTopConstraint.constant
            + ceil(pageControl.bounds.height)
            + AppDelegate.current.mainWindow.safeAreaInsets.bottom
        if ScreenHeight.current <= .short {
            return height + 36
        } else {
            return height + 22
        }
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
    
    private func showPinTipsIfNeeded() {
        guard !AppGroupUserDefaults.User.homeAppsPinTips else {
            return
        }
        let viewController = HomeAppsPinTipsViewController()
        viewController.pinnedViewTopOffset = view.frame.origin.y + 80.0
        viewController.modalPresentationStyle = .overFullScreen
        viewController.modalTransitionStyle = .crossDissolve
        present(viewController, animated: true, completion: nil)
    }
    
    private func updatePinnedPlaceholderViewsHidden(with pinnedAppCount: Int) {
        for (index, view) in pinnedPlaceholderViews.enumerated() {
            view.isHidden = index < pinnedAppCount
        }
    }
    
    private func updateHomeTitleLabel(isEditing: Bool) {
        if isEditing {
            homeTitleLabel.textColor = .theme
            homeTitleLabel.text = R.string.localizable.action_done()
        } else {
            homeTitleLabel.textColor = .title
            homeTitleLabel.text = R.string.localizable.home_title_apps()
        }
    }
    
}

extension HomeAppsViewController: HomeAppsManagerDelegate {
    
    func homeAppsManager(_ manager: HomeAppsManager, didSelectApp app: HomeApp) {
        switch app {
        case let .embedded(app):
            dismissAsChild(completion: app.action)
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
