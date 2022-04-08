import UIKit

class DisappearingMessageTimePickerWindow: BottomSheetView {
        
    @IBOutlet weak var pickerView: UIPickerView!
    
    var onPick: ((Int64) -> Void)?
    
    private var selectedDuration: Int = 1
    private var selectedUnit: Unit = .second {
        didSet {
            guard oldValue != selectedUnit else {
                return
            }
            pickerView.reloadComponent(Component.duration.rawValue)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        pickerView.dataSource = self
        pickerView.delegate = self
    }
    
    @IBAction func setAction(_ sender: Any) {
        let expireIn = Int64(selectedUnit.interval) * Int64(max(selectedDuration, 1))
        onPick?(expireIn)
        dismissPopupControllerAnimated()
    }
    
    @IBAction func closeAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }
    
    class func instance() -> DisappearingMessageTimePickerWindow {
        R.nib.disappearingMessageTimePickerWindow(owner: self)!
    }
    
    func render(expireIn: Int64) {
        let timeInterval = TimeInterval(expireIn)
        if timeInterval < .minute {
            selectedUnit = .second
            selectedDuration = Int(timeInterval)
        } else if timeInterval < .hour {
            selectedUnit = .minute
            selectedDuration = Int(timeInterval / .minute)
        } else if timeInterval < .day {
            selectedUnit = .hour
            selectedDuration = Int(timeInterval / .hour)
        } else if timeInterval < .week {
            selectedUnit = .day
            selectedDuration = Int(timeInterval / .day)
        } else {
            selectedUnit = .week
            selectedDuration = Int(timeInterval / .week)
        }
        pickerView.selectRow(index(for: selectedDuration), inComponent: Component.duration.rawValue, animated: false)
        pickerView.selectRow(selectedUnit.rawValue, inComponent: Component.unit.rawValue, animated: false)
    }
    
}

extension DisappearingMessageTimePickerWindow: UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        2
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch Component(rawValue: component) {
        case .duration:
            return selectedUnit.maxValue
        case .unit:
            return 5
        default:
            return 0
        }
    }
    
}

extension DisappearingMessageTimePickerWindow: UIPickerViewDelegate {
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch Component(rawValue: component) {
        case .duration:
            return "\(duration(for: row))"
        case .unit:
            return (Unit(rawValue: row) ?? .second).name
        default:
            return nil
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch Component(rawValue: component) {
        case .duration:
            selectedDuration = duration(for: row)
        case .unit:
            selectedUnit = Unit(rawValue: row) ?? .second
        default:
            break
        }
    }
    
}

extension DisappearingMessageTimePickerWindow {
    
    private func duration(for index: Int) -> Int {
        index + 1
    }
    
    private func index(for duration: Int) -> Int {
        max(duration - 1, 0)
    }
    
    private enum Component: Int {
        case duration = 0
        case unit = 1
    }
    
    private enum Unit: Int {
        
        case second = 0
        case minute
        case hour
        case day
        case week
        
        var maxValue: Int {
            switch self {
            case .second:
                return 59
            case .minute:
                return 59
            case .hour:
                return 23
            case .day:
                return 6
            case .week:
                return 4
            }
        }
        
        var name: String {
            switch self {
            case .second:
                return R.string.localizable.disappearing_message_seconds_unit()
            case .minute:
                return R.string.localizable.disappearing_message_minutes_unit()
            case .hour:
                return R.string.localizable.disappearing_message_hours_unit()
            case .day:
                return R.string.localizable.disappearing_message_days_unit()
            case .week:
                return R.string.localizable.disappearing_message_weeks_unit()
            }
        }
        
        var interval: TimeInterval {
            switch self {
            case .second:
                return 1
            case .minute:
                return .minute
            case .hour:
                return .hour
            case .day:
                return .day
            case .week:
                return .week
            }
        }
        
    }
    
}
