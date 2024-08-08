import UIKit

protocol TransactionHistoryDatePickerViewControllerDelegate: AnyObject {
    
    func transactionHistoryDatePickerViewController(
        _ controller: TransactionHistoryDatePickerViewController,
        didPickStartDate startDate: Date?,
        endDate: Date?
    )
    
}

final class TransactionHistoryDatePickerViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var startButton: OutlineButton!
    @IBOutlet weak var endButton: OutlineButton!
    @IBOutlet weak var datePickerBackgroundView: UIView!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var fixedPeriodStackView: UIStackView!
    @IBOutlet weak var trayWrapperView: UIView!
    
    private enum PickingDate {
        case start
        case end
    }
    
    weak var delegate: TransactionHistoryDatePickerViewControllerDelegate?
    
    private let trayView = R.nib.authenticationPreviewDoubleButtonTrayView(withOwner: nil)!
    private let fixedPeriods = [7, 30, 90]
    
    private var pickingDate: PickingDate = .start
    private var startDate: Date? {
        didSet {
            updateStartButton()
        }
    }
    private var endDate: Date? {
        didSet {
            updateEndButton()
        }
    }
    
    init(startDate: Date?, endDate: Date?) {
        self.startDate = startDate
        self.endDate = endDate
        let nib = R.nib.transactionHistoryDatePickerView
        super.init(nibName: nib.name, bundle: nib.bundle)
        modalPresentationStyle = .custom
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        preferredContentSize.height = 535
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.layer.masksToBounds = true
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.cornerRadius = 13
        
        titleView.titleLabel.text = R.string.localizable.select_date()
        updateNavigationSubtitle()
        titleView.closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        
        startButton.layer.cornerRadius = 8
        startButton.layer.masksToBounds = true
        updateStartButton()
        
        endButton.layer.cornerRadius = 8
        endButton.layer.masksToBounds = true
        updateEndButton()
        
        datePickerBackgroundView.layer.cornerRadius = 8
        datePickerBackgroundView.layer.masksToBounds = true
        if let startDate {
            datePicker.date = startDate
        }
        
        for period in fixedPeriods {
            let button = OutlineButton(type: .system)
            button.tag = period
            button.setTitle(R.string.localizable.number_of_days(period), for: .normal)
            button.setTitleColor(R.color.text(), for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14)
            button.layer.cornerRadius = 19
            button.layer.masksToBounds = true
            fixedPeriodStackView.addArrangedSubview(button)
            button.snp.makeConstraints { make in
                make.height.equalTo(38)
            }
            button.addTarget(self, action: #selector(loadFixedPeriod(_:)), for: .touchUpInside)
        }
        
        trayWrapperView.addSubview(trayView)
        trayView.snp.makeEdgesEqualToSuperview()
        trayView.leftButton.setTitle(R.string.localizable.reset(), for: .normal)
        trayView.leftButton.addTarget(self, action: #selector(reset(_:)), for: .touchUpInside)
        trayView.rightButton.setTitle(R.string.localizable.apply(), for: .normal)
        trayView.rightButton.addTarget(self, action: #selector(apply(_:)), for: .touchUpInside)
    }
    
    @IBAction func changeStartDate(_ sender: Any) {
        pickingDate = .start
        startButton.isSelected = true
        endButton.isSelected = false
        if let startDate {
            datePicker.date = startDate
        }
    }
    
    @IBAction func changeEndDate(_ sender: Any) {
        pickingDate = .end
        startButton.isSelected = false
        endButton.isSelected = true
        if let endDate {
            datePicker.date = endDate
        }
    }
    
    @IBAction func changeDate(_ picker: UIDatePicker) {
        let calendar: Calendar = .current
        switch pickingDate {
        case .start:
            startDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: picker.date)
        case .end:
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: picker.date)
        }
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func loadFixedPeriod(_ sender: OutlineButton) {
        let calendar: Calendar = .current
        let numberOfDays = TimeInterval(sender.tag)
        switch (startDate, endDate) {
        case (.none, .none):
            let now = Date()
            let daysBeforeNow = now.advanced(by: -numberOfDays * .day)
            self.startDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: daysBeforeNow)
            self.endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)
        case let (.some(startDate), .none):
            let daysAfter = startDate.advanced(by: numberOfDays * .day)
            self.endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: daysAfter)
        case let (_, .some(endDate)):
            let daysBefore = endDate.advanced(by: -numberOfDays * .day)
            self.startDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: daysBefore)
        }
        if startButton.isSelected, let startDate {
            datePicker.date = startDate
        } else if endButton.isSelected, let endDate {
            datePicker.date = endDate
        }
    }
    
    @objc private func reset(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        delegate?.transactionHistoryDatePickerViewController(
            self,
            didPickStartDate: nil,
            endDate: nil
        )
    }
    
    @objc private func apply(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        delegate?.transactionHistoryDatePickerViewController(
            self,
            didPickStartDate: startDate,
            endDate: endDate
        )
    }
    
    private func updateNavigationSubtitle() {
        let date = DateFormatter.shortDatePeriod(from: startDate, to: endDate) ?? R.string.localizable.all_dates()
        titleView.subtitleLabel.text = date
    }
    
    private func updateStartButton() {
        let title = if let startDate {
            DateFormatter.shortDateOnly.string(from: startDate)
        } else {
            R.string.localizable.start()
        }
        startButton.setTitle(title, for: .normal)
    }
    
    private func updateEndButton() {
        let title = if let endDate {
            DateFormatter.shortDateOnly.string(from: endDate)
        } else {
            R.string.localizable.end()
        }
        endButton.setTitle(title, for: .normal)
    }
    
}
