import UIKit

class DisappearingMessageTimePickerWindow: BottomSheetView {
    
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
                return .oneSecond
            case .minute:
                return .oneMinute
            case .hour:
                return .oneHour
            case .day:
                return .oneDay
            case .week:
                return .oneWeek
            }
        }
    }
    
    @IBOutlet weak var pickerView: UIPickerView!
    
    var onClose: (() -> Void)?
    var onChange: ((_ duration: TimeInterval, _ timeTitle: String) -> Void)?
    
    private var shouldCallOnClose = true
    private var selectedTime: Int = 1
    private var selectedUnit: Unit = .second {
        didSet {
            guard oldValue != selectedUnit else { return }
            pickerView.reloadComponent(Component.duration.rawValue)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        pickerView.dataSource = self
        pickerView.delegate = self
    }
    
    @IBAction func setAction(_ sender: Any) {
        let selectedDuration = selectedUnit.interval * TimeInterval(selectedTime + 1)
        let durationTitle = "\(selectedTime + 1) \(selectedUnit.name)"
        onChange?(selectedDuration, durationTitle)
        shouldCallOnClose = false
        dismissPopupControllerAnimated()
    }
    
    @IBAction func closeAction(_ sender: Any) {
        shouldCallOnClose = true
        dismissPopupControllerAnimated()
    }
    
    override func dismissPopupControllerAnimated() {
        if shouldCallOnClose {
            onClose?()
        }
        super.dismissPopupControllerAnimated()
    }
    
    class func instance() -> DisappearingMessageTimePickerWindow {
        R.nib.disappearingMessageTimePickerWindow(owner: self)!
    }
    
    func render(timeInterval: TimeInterval) {
        if timeInterval < .oneMinute {
            selectedUnit = .second
            selectedTime = max(Int(timeInterval) - 1, 0)
        } else if timeInterval < .oneHour {
            selectedUnit = .minute
            selectedTime = max(Int(timeInterval / .oneMinute) - 1, 0)
        } else if timeInterval < .oneDay {
            selectedUnit = .hour
            selectedTime = max(Int(timeInterval / .oneHour) - 1, 0)
        } else if timeInterval < .oneWeek {
            selectedUnit = .day
            selectedTime = max(Int(timeInterval / .oneDay) - 1, 0)
        } else {
            selectedUnit = .week
            selectedTime = max(Int(timeInterval / .oneWeek) - 1, 0)
        }
        pickerView.selectRow(selectedTime, inComponent: Component.duration.rawValue, animated: false)
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
            return "\(row + 1)"
        case .unit:
            return (Unit(rawValue: row) ?? .second).name
        default:
            return nil
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch Component(rawValue: component) {
        case .duration:
            selectedTime = row
        case .unit:
            selectedUnit = Unit(rawValue: row) ?? .second
        default:
            break
        }
    }
    
}
