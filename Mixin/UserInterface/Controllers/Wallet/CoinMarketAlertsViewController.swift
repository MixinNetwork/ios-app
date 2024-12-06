import UIKit
import MixinServices

final class CoinMarketAlertsViewController: MarketAlertViewController {
    
    private let coin: MarketAlertCoin
    private let addAlertButton = RoundedButton(type: .system)
    
    init(coin: MarketAlertCoin) {
        self.coin = coin
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func loadView() {
        super.loadView()
        tableView.snp.makeEdgesEqualToSuperview()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.alert()
        navigationItem.rightBarButtonItem = .button(
            title: R.string.localizable.all(),
            target: self,
            action: #selector(showAllMarketAlerts(_:))
        )
        addAlertButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        addAlertButton.setTitleColor(.white, for: .normal)
        addAlertButton.setTitle(R.string.localizable.add_alert(), for: .normal)
        view.addSubview(addAlertButton)
        if let label = addAlertButton.titleLabel {
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.adjustsFontForContentSizeCategory = true
        }
        addAlertButton.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(116)
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
        }
        addAlertButton.addTarget(self, action: #selector(addAlert(_:)), for: .touchUpInside)
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        tableView.contentInset.bottom = ceil(addAlertButton.intrinsicContentSize.height) + 40
    }
    
    override func reloadFromLocal() {
        DispatchQueue.global().async { [id=coin.coinID] in
            let alerts = MarketAlertDAO.shared.marketAlerts(coinIDs: [id])
            self.reloadData(alerts: alerts)
        }
    }
    
    @objc private func addAlert(_ sender: RoundedButton) {
        let addAlert = AddMarketAlertViewController(coin: self.coin)
        self.navigationController?.pushViewController(addAlert, animated: true)
    }
    
    @objc private func showAllMarketAlerts(_ sender: Any) {
        let allAlerts = AllMarketAlertsViewController()
        navigationController?.pushViewController(allAlerts, animated: true)
    }
    
}

extension CoinMarketAlertsViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}
