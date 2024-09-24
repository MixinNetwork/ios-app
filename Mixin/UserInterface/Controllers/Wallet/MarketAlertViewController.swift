import UIKit
import MixinServices

final class MarketAlertViewController: UIViewController {
    
    @IBOutlet weak var assetFilterView: TransactionHistoryAssetFilterView!
    @IBOutlet weak var addAlertButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    private let headerReuseIdentifier = "h"
    private let token: TokenItem
    
    private var viewModels: [MarketAlertViewModel] = []
    
    init(token: TokenItem) {
        self.token = token
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    static func contained(token: TokenItem) -> ContainerViewController {
        let alert = MarketAlertViewController(token: token)
        let container = ContainerViewController.instance(viewController: alert, title: R.string.localizable.alert())
        container.loadViewIfNeeded()
        container.view.backgroundColor = R.color.background_secondary()
        container.navigationBar.backgroundColor = R.color.background_secondary()
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
    
    @IBAction func addAlert(_ sender: Any) {
        let addAlert = AddMarketAlertViewController.contained(token: token)
        navigationController?.pushViewController(addAlert, animated: true)
    }
    
    @objc private func reloadFromLocal() {
        DispatchQueue.global().async { [id=token.assetID] in
            let alerts = MarketAlertDAO.shared.marketAlerts()
            self.updateViewModels(alerts: alerts, expandAssetID: id)
        }
    }
    
    private func updateViewModels(alerts: [MarketAlert], expandAssetID: String) {
        assert(!Thread.isMainThread)
        var alerts = alerts
        let assetIDs = Array(Set(alerts.map(\.assetID)))
        var tokens = TokenDAO.shared.marketAlertTokens(assetIDs: assetIDs)
        if let index = tokens.firstIndex(where: { $0.assetID == expandAssetID }) {
            let token = tokens.remove(at: index)
            tokens.insert(token, at: 0)
        }
        let viewModels = tokens.map { token in
            var alertsForCurrentToken: [MarketAlert] = []
            alerts.removeAll { alert in
                if alert.assetID == token.assetID {
                    alertsForCurrentToken.append(alert)
                    return true
                } else {
                    return false
                }
            }
            return MarketAlertViewModel(token: token, alerts: alertsForCurrentToken)
        }
        viewModels.first?.isExpanded = true
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
    
    func marketAlertTokenCell(_ cell: MarketAlertTokenCell, wantsToPerform action: MarketAlert.Action, to alert: MarketAlert) {
        guard let section = tableView.indexPath(for: cell)?.section else {
            return
        }
        let viewModel = viewModels[section]
        guard let row = viewModel.alerts.firstIndex(where: { $0.alert.alertID == alert.alertID }) else {
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        RouteAPI.postAction(alertID: alert.alertID, action: action) { result in
            switch result {
            case .success:
                switch action {
                case .pause:
                    hud.set(style: .notification, text: "Paused")
                    viewModel.alerts[row].alert.status = .paused
                    self.tableView.reloadSections(IndexSet(integer: section), with: .none)
                case .resume:
                    hud.set(style: .notification, text: "Resumed")
                    viewModel.alerts[row].alert.status = .running
                    self.tableView.reloadSections(IndexSet(integer: section), with: .none)
                case .delete:
                    hud.set(style: .notification, text: R.string.localizable.deleted())
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
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
            }
            hud.scheduleAutoHidden()
        }
    }
    
    func marketAlertTokenCell(_ cell: MarketAlertTokenCell, wantsToEdit alert: MarketAlert) {
        let editor = EditMarketAlertViewController.contained(token: token, alert: alert)
        navigationController?.pushViewController(editor, animated: true)
    }
    
}
