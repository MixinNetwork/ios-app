import UIKit
import MixinServices

final class AllMarketAlertsViewController: MarketAlertViewController {
    
    @IBOutlet weak var assetFilterView: TransactionHistoryAssetFilterView!
    @IBOutlet weak var addAlertButton: BusyButton!
    
    private var coins: [MarketAlertCoin]
    
    init() {
        self.coins = []
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func loadView() {
        super.loadView()
        let topActionsView = R.nib.allAlertsTopActionView(withOwner: self)!
        view.addSubview(topActionsView)
        topActionsView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.equalTo(view.safeAreaLayoutGuide.snp.leading).offset(20)
            make.trailing.equalTo(view.safeAreaLayoutGuide.snp.trailing).offset(-20)
            make.height.equalTo(40)
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(topActionsView.snp.bottom).offset(4)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.all_alert()
        assetFilterView.reloadData(coins: coins)
        assetFilterView.button.addTarget(self, action: #selector(pickTokens(_:)), for: .touchUpInside)
        addAlertButton.setTitle(R.string.localizable.add_alert(), for: .normal)
        addAlertButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 14, weight: .medium), adjustForContentSize: true)
    }
    
    override func reloadFromLocal() {
        let ids = coins.map(\.coinID)
        DispatchQueue.global().async {
            let alerts = if ids.isEmpty {
                MarketAlertDAO.shared.allMarketAlerts()
            } else {
                MarketAlertDAO.shared.marketAlerts(coinIDs: ids)
            }
            self.reloadData(alerts: alerts)
        }
    }
    
    @IBAction func addAlert(_ sender: BusyButton) {
        let picker = MarketAlertCoinPickerViewController()
        picker.delegate = self
        self.present(picker, animated: true)
    }
    
    @objc private func pickTokens(_ sender: Any) {
        let picker = MarketAlertCoinPickerViewController(selectedCoins: coins)
        picker.delegate = self
        present(picker, animated: true)
    }
    
}

extension AllMarketAlertsViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension AllMarketAlertsViewController: MarketAlertCoinPickerViewController.Delegate {
    
    func marketAlertCoinPickerViewController(
        _ controller: MarketAlertCoinPickerViewController,
        didPickCoin coin: MarketAlertCoin
    ) {
        dismiss(animated: true) {
            let addAlert = AddMarketAlertViewController(coin: coin)
            self.navigationController?.pushViewController(addAlert, animated: true)
        }
    }
    
    func marketAlertCoinPickerViewController(
        _ controller: MarketAlertCoinPickerViewController,
        didPickCoins coins: [MarketAlertCoin]
    ) {
        assetFilterView.reloadData(coins: coins)
        self.coins = coins
        reloadFromLocal()
    }
    
}
