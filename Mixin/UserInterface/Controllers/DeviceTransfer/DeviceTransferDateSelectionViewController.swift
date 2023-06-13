import UIKit

class DeviceTransferDateSelectionViewController: UIViewController {
    
    @IBOutlet weak var allDateCheckmark: UIImageView!
    @IBOutlet weak var lastDateCheckmark: UIImageView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    private var filter: DeviceTransferFilter.Time = .all
    private var changeHandler: DeviceTransferFilter.TimeChangeHandler?
    
    convenience init() {
        self.init(nib: R.nib.deviceTransferDateSelectionView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        segmentedControl.setTitle(R.string.localizable.month(), forSegmentAt: 0)
        segmentedControl.setTitle(R.string.localizable.year(), forSegmentAt: 1)
        switch filter {
        case .all:
            updateAllDateSelection()
        case .lastMonths(let months):
            updateLastDateSelection()
            textField.text = "\(months)"
            segmentedControl.selectedSegmentIndex = 0
        case .lastYears(let years):
            updateLastDateSelection()
            textField.text = "\(years)"
            segmentedControl.selectedSegmentIndex = 1
        }
    }

    class func instance(filter: DeviceTransferFilter.Time, changeHandler: @escaping DeviceTransferFilter.TimeChangeHandler) -> UIViewController {
        let controller = DeviceTransferDateSelectionViewController()
        controller.filter = filter
        controller.changeHandler = changeHandler
        return ContainerViewController.instance(viewController: controller, title: R.string.localizable.date())
    }
    
    @IBAction func selectAllDateAction(_ sender: Any) {
        updateAllDateSelection()
    }
    
    @IBAction func selectLastDateAction(_ sender: Any) {
        updateLastDateSelection()
    }
    
    @IBAction func dateUnitChangedAction(_ sender: Any) {
        updateDateFilter()
    }
    
    @IBAction func textChangedAction(_ sender: Any) {
        updateDateFilter()
    }
    
    @IBAction func editingBeginAction(_ sender: Any) {
        updateLastDateSelection()
    }
    
}

extension DeviceTransferDateSelectionViewController: ContainerViewControllerDelegate {
    
    func textBarRightButton() -> String? {
        R.string.localizable.save()
    }
    
    func barRightButtonTappedAction() {
        changeHandler?(filter)
        navigationController?.popViewController(animated: true)
    }
    
}

extension DeviceTransferDateSelectionViewController {
    
    private func updateAllDateSelection() {
        allDateCheckmark.isHidden = false
        lastDateCheckmark.isHidden = true
        segmentedControl.isEnabled = false
        filter = .all
        container?.rightButton.isEnabled = true
        textField.resignFirstResponder()
    }
    
    private func updateLastDateSelection() {
        allDateCheckmark.isHidden = true
        lastDateCheckmark.isHidden = false
        segmentedControl.isEnabled = true
        textField.becomeFirstResponder()
        updateDateFilter()
    }
    
    private func updateDateFilter() {
        guard let count = textField.text?.intValue, count > 0 else {
            container?.rightButton.isEnabled = false
            return
        }
        container?.rightButton.isEnabled = true
        if segmentedControl.selectedSegmentIndex == 0 {
            filter = .lastMonths(count)
        } else {
            filter = .lastYears(count)
        }
    }
    
}
