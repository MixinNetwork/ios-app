import UIKit
import MixinServices

final class MarketAlertViewController: UIViewController {
    
    @IBOutlet weak var assetFilterView: TransactionHistoryAssetFilterView!
    @IBOutlet weak var addAlertButton: BusyButton!
    @IBOutlet weak var tableView: UITableView!
    
    private let headerReuseIdentifier = "h"
    
    private var coins: [MarketAlertCoin]
    private var viewModels: [MarketAlertViewModel] = []
    
    init(market: Market) {
        let coin = MarketAlertCoin(
            coinID: market.coinID,
            name: market.name,
            symbol: market.symbol,
            iconURL: market.iconURL,
            currentPrice: market.currentPrice
        )
        self.coins = [coin]
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    static func contained(market: Market) -> ContainerViewController {
        let alert = MarketAlertViewController(market: market)
        let container = ContainerViewController.instance(viewController: alert, title: R.string.localizable.alert())
        container.loadViewIfNeeded()
        container.view.backgroundColor = R.color.background_secondary()
        container.navigationBar.backgroundColor = R.color.background_secondary()
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        assetFilterView.reloadData(coins: coins)
        assetFilterView.button.addTarget(self, action: #selector(pickTokens(_:)), for: .touchUpInside)
        addAlertButton.setTitle(R.string.localizable.add_alert(), for: .normal)
        addAlertButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 14, weight: .medium), adjustForContentSize: true)
        tableView.register(R.nib.marketAlertTokenCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadFromLocal),
            name: MarketAlertDAO.didSaveNotification,
            object: nil
        )
        reloadFromLocal()
        let job = ReloadMarketAlertsJob()
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    @IBAction func addAlert(_ sender: BusyButton) {
        sender.isBusy = true
        NotificationManager.shared.requestAuthorization { isAuthorized in
            sender.isBusy = false
            if isAuthorized {
                if self.coins.count == 1 {
                    let coin = self.coins[0]
                    let addAlert = AddMarketAlertViewController.contained(coin: coin)
                    self.navigationController?.pushViewController(addAlert, animated: true)
                } else {
                    let picker = MarketAlertCoinPickerViewController()
                    picker.delegate = self
                    self.present(picker, animated: true)
                }
            } else {
                let alert = UIAlertController(
                    title: R.string.localizable.turn_on_notifications(),
                    message: R.string.localizable.price_alert_notification_permission(),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel))
                alert.addAction(UIAlertAction(title: R.string.localizable.settings(), style: .default, handler: { _ in
                    UIApplication.shared.openNotificationSettings()
                }))
                self.present(alert, animated: true)
            }
        }
    }
    
    @objc private func pickTokens(_ sender: Any) {
        let picker = MarketAlertCoinPickerViewController(selectedCoins: coins)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func reloadFromLocal() {
        let ids = coins.map(\.coinID)
        DispatchQueue.global().async {
            let alerts = if ids.isEmpty {
                MarketAlertDAO.shared.allMarketAlerts()
            } else {
                MarketAlertDAO.shared.marketAlerts(coinIDs: ids)
            }
            self.updateViewModels(alerts: alerts)
        }
    }
    
    private func updateViewModels(alerts: [MarketAlert]) {
        assert(!Thread.isMainThread)
        let viewModels: [MarketAlertViewModel]
        if alerts.isEmpty {
            viewModels = []
        } else {
            var alerts = alerts
            let coinIDs = Array(Set(alerts.map(\.coinID)))
            let coins = MarketDAO.shared.marketAlertCoins(coinIDs: coinIDs)
            viewModels = coins.map { coin in
                var alertsForCurrentToken: [MarketAlert] = []
                alerts.removeAll { alert in
                    if alert.coinID == coin.coinID {
                        alertsForCurrentToken.append(alert)
                        return true
                    } else {
                        return false
                    }
                }
                return MarketAlertViewModel(coin: coin, alerts: alertsForCurrentToken)
            }
            viewModels.first?.isExpanded = true
        }
        DispatchQueue.main.async {
            self.viewModels = viewModels
            self.tableView.reloadData()
            self.tableView.checkEmpty(
                dataCount: viewModels.count,
                text: R.string.localizable.no_alerts(),
                photo: R.image.emptyIndicator.ic_data()!
            )
        }
    }
    
}

extension MarketAlertViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        viewModels.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.market_alert_token, for: indexPath)!
        cell.viewModel = viewModels[indexPath.section]
        cell.delegate = self
        return cell
    }
    
}

extension MarketAlertViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        10
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { 
        nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        tableView.beginUpdates()
        // `cell.viewModel` is passed by reference. When the viewModel changes, it will cause the cell’s
        // content height to adjust accordingly. See `MarketAlertTokenCell.systemLayoutSizeFitting`
        // for more details
        viewModels[indexPath.section].isExpanded.toggle()
        tableView.endUpdates()
    }
    
}

extension MarketAlertViewController: MarketAlertTokenCell.Delegate {
    
    func marketAlertTokenCell(
        _ cell: MarketAlertTokenCell,
        wantsToPerform action: MarketAlert.Action,
        to alert: MarketAlert
    ) {
        guard let section = tableView.indexPath(for: cell)?.section else {
            return
        }
        let viewModel = viewModels[section]
        let row = viewModel.alerts.firstIndex {
            $0.alert.alertID == alert.alertID
        }
        guard let row else {
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        RouteAPI.postAction(alertID: alert.alertID, action: action) { result in
            switch result {
            case .success:
                switch action {
                case .pause:
                    DispatchQueue.global().async {
                        MarketAlertDAO.shared.update(alertID: alert.alertID, status: .paused)
                    }
                    hud.set(style: .notification, text: R.string.localizable.paused())
                    viewModel.alerts[row].alert.status = .paused
                    self.tableView.reloadSections(IndexSet(integer: section), with: .none)
                case .resume:
                    DispatchQueue.global().async {
                        MarketAlertDAO.shared.update(alertID: alert.alertID, status: .running)
                    }
                    hud.set(style: .notification, text: R.string.localizable.resumed())
                    viewModel.alerts[row].alert.status = .running
                    self.tableView.reloadSections(IndexSet(integer: section), with: .none)
                case .delete:
                    DispatchQueue.global().async {
                        MarketAlertDAO.shared.deleteAlert(id: alert.alertID)
                    }
                    hud.set(style: .notification, text: R.string.localizable.deleted())
                    UIView.performWithoutAnimation {
                        viewModel.alerts.remove(at: row)
                        if viewModel.alerts.isEmpty {
                            self.viewModels.remove(at: section)
                            self.tableView.deleteSections(IndexSet(integer: section), with: .none)
                            self.tableView.checkEmpty(
                                dataCount: self.viewModels.count,
                                text: R.string.localizable.no_alerts(),
                                photo: R.image.emptyIndicator.ic_data()!
                            )
                        } else {
                            self.tableView.reloadSections(IndexSet(integer: section), with: .none)
                        }
                    }
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        }
    }
    
    func marketAlertTokenCell(
        _ cell: MarketAlertTokenCell,
        wantsToEdit alert: MarketAlert,
        coin: MarketAlertCoin
    ) {
        let editor = EditMarketAlertViewController.contained(coin: coin, alert: alert)
        navigationController?.pushViewController(editor, animated: true)
    }
    
}

extension MarketAlertViewController: MarketAlertCoinPickerViewController.Delegate {
    
    func marketAlertCoinPickerViewController(
        _ controller: MarketAlertCoinPickerViewController,
        didPickCoin coin: MarketAlertCoin
    ) {
        dismiss(animated: true) {
            let addAlert = AddMarketAlertViewController.contained(coin: coin)
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
