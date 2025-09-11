import UIKit
import MixinServices

final class ReceiveMoneyViewController: UIViewController {
    
    @IBOutlet weak var sectionView: UIView!
    @IBOutlet weak var linkView: DepositLinkView!
    @IBOutlet weak var actionStackView: UIStackView!
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var setAmountButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    
    private let link: DepositLink
    
    init(account: Account) {
        self.link = .mixin(account: account)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.receive_money()
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.receive_money(),
            wallet: .privacy
        )
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        sectionView.layer.cornerRadius = 8
        sectionView.layer.masksToBounds = true
        linkView.size = .large
        linkView.load(link: link)
        scanButton.configuration?.title = R.string.localizable.scan()
        setAmountButton.configuration?.title = R.string.localizable.set_amount()
        shareButton.configuration?.title = R.string.localizable.share()
    }
    
    @IBAction func scan(_ sender: Any) {
        UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: true)
    }
    
    @IBAction func setAmount(_ sender: Any) {
        let selector = MixinTokenSelectorViewController()
        selector.searchFromRemote = true
        selector.onSelected = { [weak self, link] (token, _) in
            let inputAmount = DepositInputAmountViewController(link: link, token: token)
            let navigationController = GeneralAppearanceNavigationController(
                rootViewController: inputAmount
            )
            self?.present(navigationController, animated: true)
        }
        present(selector, animated: true)
    }
    
    @IBAction func share(_ sender: Any) {
        let share = ShareDepositLinkViewController(link: link)
        present(share, animated: true)
    }
    
    @objc func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
    }
    
}

extension ReceiveMoneyViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}
