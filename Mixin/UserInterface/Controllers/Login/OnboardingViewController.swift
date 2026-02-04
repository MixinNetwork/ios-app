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
    
    private let infiniteIllusionMultiplier = 7
    
    private var hasBannerScrolledToInitialPosition = false
    
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
        collectionView.collectionViewLayout = { [banners, weak pageControl] in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.visibleItemsInvalidationHandler = { visibleItems, scrollOffset, environment in
                let location = Int(round(scrollOffset.x / environment.container.contentSize.width))
                let page = ((location % banners.count) + banners.count) % banners.count
                pageControl?.currentPage = page
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
        collectionView.reloadData()
        
        Logger.login.info(category: "Onboarding", message: "App \(Bundle.main.fullVersion) onboards, device: \(Device.current.machineName) \(ProcessInfo.processInfo.operatingSystemVersionString), id: \(Device.current.id)")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasBannerScrolledToInitialPosition {
            collectionView.scrollToItem(
                at: IndexPath(item: infiniteIllusionMultiplier / 2 * banners.count, section: 0),
                at: .centeredHorizontally,
                animated: false
            )
            hasBannerScrolledToInitialPosition = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    @IBAction func signUp(_ sender: Any) {
        let intro = CreateAccountIntroductionViewController()
        present(intro, animated: true)
        Logger.login.info(category: "Onboarding", message: "Sign up")
    }
    
    @IBAction func signIn(_ sender: Any) {
        let mobileNumber = SignInWithMobileNumberViewController()
        navigationController?.pushViewController(mobileNumber, animated: true)
        Logger.login.info(category: "Onboarding", message: "Sign in")
        reporter.report(event: .loginStart)
    }
    
}

extension OnboardingViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        infiniteIllusionMultiplier * banners.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.onboarding_banner, for: indexPath)!
        let banner = banners[indexPath.item % banners.count]
        cell.imageView.image = banner.image
        cell.titleLabel.text = banner.title
        cell.descriptionLabel.text = banner.description
        return cell
    }
    
}

extension OnboardingViewController {
    
    private struct Banner {
        let image: UIImage
        let title: String
        let description: String
    }
    
}
