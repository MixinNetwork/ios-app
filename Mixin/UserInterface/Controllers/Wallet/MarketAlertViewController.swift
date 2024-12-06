import UIKit
import MixinServices

class MarketAlertViewController: UIViewController {
    
    weak var tableView: UITableView!
    
    private let headerReuseIdentifier = "h"
    
    private var viewModels: [MarketAlertViewModel] = []
    private var expandedCoinIDs: Set<String> = []
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = R.color.background_secondary()
        let tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.backgroundColor = R.color.background_secondary()
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        view.addSubview(tableView)
        self.tableView = tableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.marketAlertTokenCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadFromLocal),
            name: MarketAlertDAO.didChangeNotification,
            object: nil
        )
        reloadFromLocal()
    }
    
    @objc func reloadFromLocal() {
        
    }
    
    func reloadData(alerts: [MarketAlert]) {
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
        }
        DispatchQueue.main.async {
            if self.expandedCoinIDs.isEmpty, let viewModel = viewModels.first {
                self.expandedCoinIDs.insert(viewModel.coin.coinID)
            }
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
        let viewModel = viewModels[indexPath.section]
        cell.viewModel = viewModel
        cell.isExpanded = expandedCoinIDs.contains(viewModel.coin.coinID)
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
    
}

extension MarketAlertViewController: MarketAlertTokenCell.Delegate {
    
    func marketAlertTokenCellWantsToToggleExpansion(_ cell: MarketAlertTokenCell) {
        tableView.beginUpdates()
        cell.isExpanded.toggle()
        if let indexPath = tableView.indexPath(for: cell) {
            let viewModel = viewModels[indexPath.section]
            if cell.isExpanded {
                expandedCoinIDs.insert(viewModel.coin.coinID)
            } else {
                expandedCoinIDs.remove(viewModel.coin.coinID)
            }
        }
        tableView.endUpdates()
    }
    
    func marketAlertTokenCell(
        _ cell: MarketAlertTokenCell,
        wantsToPerform action: MarketAlert.Action,
        to alert: MarketAlert
    ) {
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
                case .resume:
                    DispatchQueue.global().async {
                        MarketAlertDAO.shared.update(alertID: alert.alertID, status: .running)
                    }
                    hud.set(style: .notification, text: R.string.localizable.resumed())
                case .delete:
                    DispatchQueue.global().async {
                        MarketAlertDAO.shared.deleteAlert(id: alert.alertID)
                    }
                    hud.set(style: .notification, text: R.string.localizable.deleted())
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
        let editor = EditMarketAlertViewController(coin: coin, alert: alert)
        navigationController?.pushViewController(editor, animated: true)
    }
    
}
