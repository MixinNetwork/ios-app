import UIKit
import MixinServices

final class OnboardingViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var signUpButton: StyledButton!
    @IBOutlet weak var signInButton: StyledButton!
    @IBOutlet weak var versionLabel: UILabel!
    
    @IBOutlet weak var actionsBottomConstraint: NSLayoutConstraint!
    
    private let banners: [Banner] = [
        Banner(
            image: R.image.onboarding_mixin()!,
            title: "Mixin",
            description: R.string.localizable.onboarding_mixin_description(),
        ),
        Banner(
            image: R.image.onboarding_decentralized()!,
            title: R.string.localizable.onboarding_decentralized_title(),
            description: R.string.localizable.onboarding_decentralized_description(),
        ),
        Banner(
            image: R.image.onboarding_trade()!,
            title: R.string.localizable.onboarding_trade_title(),
            description: R.string.localizable.onboarding_trade_description(),
        ),
        Banner(
            image: R.image.onboarding_privacy()!,
            title: R.string.localizable.onboarding_privacy_title(),
            description: R.string.localizable.onboarding_privacy_description(),
        ),
        Banner(
            image: R.image.onboarding_recover()!,
            title: R.string.localizable.onboarding_recover_title(),
            description: R.string.localizable.onboarding_recover_description(),
        ),
        Banner(
            image: R.image.onboarding_rewards()!,
            title: R.string.localizable.onboarding_reward_title(),
            description: R.string.localizable.onboarding_reward_description(),
        ),
    ]
    
    // Banners are duplicated as multiple sections to make the infinite illusion
    private let sectionsCount = 7
    
    private weak var bannerAutoScrollingTimer: Timer?
    
    init() {
        Logger.redirectLogsToLogin = true
        let nib = R.nib.onboardingView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.collectionViewLayout = { [weak pageControl] in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsetsReference = .none
            section.visibleItemsInvalidationHandler = { visibleItems, scrollOffset, environment in
                guard let firsItem = visibleItems.first else {
                    return
                }
                let focusItem: any NSCollectionLayoutVisibleItem
                if visibleItems.count == 1 {
                    focusItem = firsItem
                } else if let lastItem = visibleItems.last {
                    focusItem = scrollOffset.x < firsItem.center.x ? firsItem : lastItem
                } else {
                    return
                }
                pageControl?.currentPage = focusItem.indexPath.item
            }
            let config = UICollectionViewCompositionalLayoutConfiguration()
            config.scrollDirection = .horizontal
            return UICollectionViewCompositionalLayout(section: section, configuration: config)
        }()
        collectionView.register(R.nib.onboardingBannerCell)
        pageControl.numberOfPages = banners.count
        switch ScreenHeight.current {
        case .short:
            actionsBottomConstraint.constant = 8
        case .medium:
            actionsBottomConstraint.constant = 16
        case .long, .extraLong:
            actionsBottomConstraint.constant = 38
        }
        signUpButton.setTitle(R.string.localizable.create_account(), for: .normal)
        signUpButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        signUpButton.style = .filled
        signInButton.setTitle(R.string.localizable.landing_have_account(), for: .normal)
        signInButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        signInButton.style = .tinted
        versionLabel.text = R.string.localizable.current_version(Bundle.main.fullVersion)
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        
        Logger.login.info(category: "Onboarding", message: "App \(Bundle.main.fullVersion) onboards, device: \(Device.current.machineName) \(ProcessInfo.processInfo.operatingSystemVersionString), id: \(Device.current.id)")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        resetBannersToCenterAndScheduleAutoScrolling()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        bannerAutoScrollingTimer?.invalidate()
    }
    
    @IBAction func signUp(_ sender: Any) {
        let intro = CreateAccountIntroductionViewController()
        present(intro, animated: true)
    }
    
    @IBAction func signIn(_ sender: Any) {
        let mobileNumber = SignInWithMobileNumberViewController()
        navigationController?.pushViewController(mobileNumber, animated: true)
        Logger.login.info(category: "Onboarding", message: "Sign in")
        reporter.report(event: .loginStart)
    }
    
}

extension OnboardingViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sectionsCount
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        banners.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.onboarding_banner, for: indexPath)!
        let banner = banners[indexPath.item]
        cell.imageView.image = banner.image
        cell.titleLabel.text = banner.title
        cell.descriptionLabel.text = banner.description
        return cell
    }
    
}

extension OnboardingViewController: UICollectionViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        bannerAutoScrollingTimer?.invalidate()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        resetBannersToCenterAndScheduleAutoScrolling()
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        resetBannersToCenterAndScheduleAutoScrolling()
    }
    
}

extension OnboardingViewController {
    
    private struct Banner {
        let image: UIImage
        let title: String
        let description: String
    }
    
    private func resetBannersToCenterAndScheduleAutoScrolling() {
        bannerAutoScrollingTimer?.invalidate()
        if !collectionView.isDragging,
           !collectionView.isTracking,
           !collectionView.isDecelerating,
           collectionView.indexPathsForVisibleItems.count == 1,
           let indexPath = collectionView.indexPathsForVisibleItems.first,
           indexPath.section != sectionsCount / 2
        {
            collectionView.scrollToItem(
                at: IndexPath(item: indexPath.item, section: sectionsCount / 2),
                at: .centeredHorizontally,
                animated: false
            )
        }
        bannerAutoScrollingTimer = .scheduledTimer(
            withTimeInterval: 5,
            repeats: false
        ) { [weak collectionView, banners] _ in
            guard let collectionView else {
                return
            }
            if !collectionView.isDragging,
               !collectionView.isTracking,
               !collectionView.isDecelerating,
               collectionView.indexPathsForVisibleItems.count == 1
            {
                var indexPath = IndexPath(
                    item: collectionView.indexPathsForVisibleItems[0].item + 1,
                    section: collectionView.indexPathsForVisibleItems[0].section
                )
                if indexPath.item == banners.count {
                    indexPath.item = 0
                    indexPath.section += 1
                }
                collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            }
        }
    }
    
}
