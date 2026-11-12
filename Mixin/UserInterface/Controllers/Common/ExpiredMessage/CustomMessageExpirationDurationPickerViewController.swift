import UIKit
import MixinServices

final class CustomMessageExpirationDurationPickerViewController: UIViewController {
    
    static let durations: [Int64] = (1...6).map { Int64($0) * Int64(TimeInterval.day) }
        + (1...3).map { Int64($0) * Int64(TimeInterval.week) }
        + (1...6).map { Int64($0) * Int64(TimeInterval.month) }
        + [Int64(365 * TimeInterval.day)]
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var setButton: UIButton!
    @IBOutlet weak var pickerView: UIPickerView!
    
    private let initialDuration: Int64
    private let onPick: (Int64) -> Void
    
    init(expireIn: Int64, onPick: @escaping (Int64) -> Void) {
        initialDuration = expireIn
        self.onPick = onPick
        let nib = R.nib.customMessageExpirationDurationPickerView
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
        preferredContentSize.height = 364
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.custom_time()
        setButton.setTitle(R.string.localizable.set(), for: .normal)
        view.layer.cornerRadius = 13
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        pickerView.layer.cornerRadius = 13
        pickerView.layer.masksToBounds = true
        pickerView.dataSource = self
        pickerView.delegate = self
        let row = Self.durations.firstIndex(of: initialDuration) ?? 0
        pickerView.selectRow(row, inComponent: 0, animated: false)
    }
    
    @IBAction func setDuration(_ sender: Any) {
        let duration = Self.durations[pickerView.selectedRow(inComponent: 0)]
        dismiss(animated: true) { [onPick] in
            onPick(duration)
        }
    }
    
    @IBAction func close(_ sender: Any) {
        dismiss(animated: true)
    }
    
}

extension CustomMessageExpirationDurationPickerViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        Self.durations.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        ExpiredMessageDurationFormatter.string(from: Self.durations[row])
    }
    
}
