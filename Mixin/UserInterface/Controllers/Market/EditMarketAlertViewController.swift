import UIKit
import MixinServices

final class EditMarketAlertViewController: AddMarketAlertViewController {
    
    private let alert: MarketAlert
    
    override var initialInput: String? {
        if let decimalValue = Decimal(string: alert.value, locale: .enUSPOSIX) {
            let value = switch alertType.valueType {
            case .absolute:
                decimalValue
            case .percentage:
                decimalValue * 100
            }
            return formatter.string(decimal: value)
        } else {
            return nil
        }
    }
    
    init(coin: MarketAlertCoin, alert: MarketAlert) {
        self.alert = alert
        super.init(coin: coin, type: alert.type, frequency: alert.frequency)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.edit_alert()
        addAlertButton.setTitle(R.string.localizable.edit_alert(), for: .normal)
    }
    
    override func addAlert(_ sender: Any) {
        guard let decimalInputValue else {
            return
        }
        let requestValue = switch alertType.valueType {
        case .absolute:
            decimalInputValue
        case .percentage:
            decimalInputValue / 100
        }
        formatter.locale = .enUSPOSIX
        defer {
            formatter.locale = .current
        }
        guard let value = formatter.string(decimal: requestValue) else {
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
