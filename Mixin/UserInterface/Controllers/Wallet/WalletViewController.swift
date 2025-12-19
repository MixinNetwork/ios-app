import UIKit
import LocalAuthentication
import MixinServices

class WalletViewController: UIViewController, MnemonicsBackupChecking {
    
    @IBOutlet weak var titleView: UIView!
    @IBOutlet weak var titleInfoStackView: UIStackView!
    @IBOutlet weak var walletSwitchImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    let tableHeaderView = R.nib.walletHeaderView(withOwner: nil)!
    
    private let searchAppearingAnimationDistance: CGFloat = 20
    
    private var searchCenterYConstraint: NSLayoutConstraint?
    private var searchViewController: UIViewController?
    
    init() {
        let nib = R.nib.walletView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = tableHeaderView
        updateTableViewContentInset()
        tableView.rowHeight = AssetCell.height
        tableView.register(R.nib.assetCell)
        tableView.tableFooterView = UIView()
        updateTableHeaderVisualEffect()
        NotificationCenter.default.addObserver(self, selector: #selector(updateTableHeaderVisualEffect), name: UIApplication.significantTimeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dismissSearch), name: dismissSearchNotification, object: nil)
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        layoutTableHeaderView()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInset()
    }
    
    @IBAction func switchFromWallets(_ sender: Any) {
        if let parent = parent as? WalletContainerViewController {
            parent.switchToWalletSummary(animated: true)
        }
    }
    
    @IBAction func searchAction(_ sender: Any) {
        let controller = makeSearchViewController()
        controller.view.alpha = 0
        addChild(controller)
        view.addSubview(controller.view)
        controller.view.snp.makeConstraints { (make) in
            make.size.equalTo(view.snp.size)
            make.centerX.equalToSuperview()
        }
        let constraint = controller.view.centerYAnchor.constraint(
            equalTo: view.centerYAnchor,
            constant: -searchAppearingAnimationDistance
        )
        constraint.isActive = true
        controller.didMove(toParent: self)
        view.layoutIfNeeded()
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            controller.view.alpha = 1
            constraint.constant = 0
            self.view.layoutIfNeeded()
        }
        self.searchViewController = controller
        self.searchCenterYConstraint = constraint
    }
    
    @IBAction func scanQRCode() {
        UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: true)
    }
    
    @IBAction func moreAction(_ sender: Any) {
        
    }
    
    @objc func dismissSearch() {
        guard let searchViewController = searchViewController, searchViewController.parent != nil else {
            return
        }
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            searchViewController.view.alpha = 0
            self.searchCenterYConstraint?.constant = -self.searchAppearingAnimationDistance
            self.view.layoutIfNeeded()
        } completion: { _ in
            searchViewController.willMove(toParent: nil)
            searchViewController.view.removeFromSuperview()
            searchViewController.removeFromParent()
        }
    }
    
    func addIconIntoTitleView(image: UIImage?) {
        let iconView = UIImageView(image: image)
        iconView.contentMode = .scaleAspectFit
        iconView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        iconView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleInfoStackView.addArrangedSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(22)
        }
    }
    
    func makeSearchViewController() -> UIViewController {
        fatalError("Must override")
    }
    
    func layoutTableHeaderView() {
        let fittingSize = CGSize(
            width: view.bounds.width,
            height: UIView.layoutFittingExpandedSize.height
        )
        let headerSize = tableHeaderView.systemLayoutSizeFitting(
            fittingSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        tableHeaderView.frame.size.height = headerSize.height
        tableView.tableHeaderView = tableHeaderView
    }
    
    @objc private func updateTableHeaderVisualEffect() {
        let now = Date()
        let showSnowfall = now.isChristmas || now.isChineseNewYear
        tableHeaderView.showSnowfallEffect = showSnowfall
    }
    
    private func updateTableViewContentInset() {
        if view.safeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
}
