import UIKit
import MixinServices

final class EditMarketAlertViewController: AddMarketAlertViewController {
    
    private let alert: MarketAlert
    
    init(coin: MarketAlertCoin, alert: MarketAlert) {
        self.alert = alert
        super.init(coin: coin)
        self.alertType = alert.type
        self.alertFrequency = alert.frequency
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    static func contained(coin: MarketAlertCoin, alert: MarketAlert) -> ContainerViewController {
        let alert = EditMarketAlertViewController(coin: coin, alert: alert)
        let container = ContainerViewController.instance(viewController: alert, title: R.string.localizable.edit_alert())
        container.loadViewIfNeeded()
        container.view.backgroundColor = R.color.background_secondary()
        container.navigationBar.backgroundColor = R.color.background_secondary()
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let decimalValue = Decimal(string: alert.value, locale: .enUSPOSIX) {
            inputTextField.text = formatter.string(decimal: decimalValue)
        }
        addAlertButton.setTitle(R.string.localizable.edit_alert(), for: .normal)
    }
    
    override func addAlert(_ sender: Any) {
        formatter.locale = .enUSPOSIX
        defer {
            formatter.locale = .current
        }
        guard let decimalInputValue, let value = formatter.string(decimal: decimalInputValue) else {
            return
        }
        let newAlert = alert.replacing(type: alertType, frequency: alertFrequency, value: value)
        addAlertButton.isBusy = true
        RouteAPI.updateMarketAlert(alert: newAlert) { [weak self] result in
            self?.addAlertButton.isBusy = false
            switch result {
            case .success(let alert):
                DispatchQueue.global().async {
                    MarketAlertDAO.shared.save(alert: alert)
                }
                self?.navigationController?.popViewController(animated: true)
            case .failure(let error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
}
