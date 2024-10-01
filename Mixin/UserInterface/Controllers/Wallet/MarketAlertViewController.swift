import UIKit
import MixinServices

class MarketAlertViewController: UIViewController {
    
    weak var tableView: UITableView!
    
    private let headerReuseIdentifier = "h"
    
    private var viewModels: [MarketAlertViewModel] = []
    
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
            name: MarketAlertDAO.didSaveNotification,
            object: nil
        )
        reloadFromLocal()
    }
    
    @objc func reloadFromLocal() {
        
    }
    
    func requestTurnOnNotifications() {
        let alert = UIAlertController(
            title: R.string.localizable.turn_on_notifications(),
            message: R.string.localizable.price_alert_notification_permission(),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel))
        alert.addAction(UIAlertAction(title: R.string.localizable.settings(), style: .default, handler: { _ in
            UIApplication.shared.openNotificationSettings()
        }))
        present(alert, animated: true)
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
    
}

extension MarketAlertViewController: MarketAlertTokenCell.Delegate {
    
    func marketAlertTokenCellWantsToToggleExpansion(_ cell: MarketAlertTokenCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        tableView.beginUpdates()
        // `cell.viewModel` is passed by reference. When the viewModel changes, it will cause the cell’s
        // content height to adjust accordingly. See `MarketAlertTokenCell.systemLayoutSizeFitting`
        // for more details
        viewModels[indexPath.section].isExpanded.toggle()
        tableView.endUpdates()
    }
    
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
