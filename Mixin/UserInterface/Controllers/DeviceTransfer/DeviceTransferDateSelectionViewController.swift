import UIKit

class DeviceTransferDateSelectionViewController: UIViewController {
    
    @IBOutlet weak var allDateCheckmark: UIImageView!
    @IBOutlet weak var lastDateCheckmark: UIImageView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    private let filter: DeviceTransferFilter!
    
    init(filter: DeviceTransferFilter) {
        self.filter = filter
        let nib = R.nib.deviceTransferDateSelectionView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    class func instance(filter: DeviceTransferFilter) -> UIViewController {
        let controller = DeviceTransferDateSelectionViewController(filter: filter)
        return ContainerViewController.instance(viewController: controller, title: R.string.localizable.date())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        segmentedControl.setTitle(R.string.localizable.month(), forSegmentAt: 0)
        segmentedControl.setTitle(R.string.localizable.year(), forSegmentAt: 1)
        switch filter.time {
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
    
    @IBAction func selectAllDateAction(_ sender: Any) {
        updateAllDateSelection()
    }
    
    @IBAction func selectLastDateAction(_ sender: Any) {
        updateLastDateSelection()
    }
    
    @IBAction func dateUnitChangedAction(_ sender: Any) {
        updateSaveButton()
    }
    
    @IBAction func textChangedAction(_ sender: Any) {
        updateSaveButton()
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
        if !allDateCheckmark.isHidden {
            filter.time = .all
        } else if let count = textField.text?.intValue {
            if segmentedControl.selectedSegmentIndex == 0 {
                filter.time = .lastMonths(count)
            } else {
                filter.time = .lastYears(count)
            }
        }
        navigationController?.popViewController(animated: true)
    }
    
}

extension DeviceTransferDateSelectionViewController {
    
    private func updateAllDateSelection() {
        allDateCheckmark.isHidden = false
        lastDateCheckmark.isHidden = true
        segmentedControl.isEnabled = false
        container?.rightButton.isEnabled = true
        textField.resignFirstResponder()
    }
    
    private func updateLastDateSelection() {
        allDateCheckmark.isHidden = true
        lastDateCheckmark.isHidden = false
        segmentedControl.isEnabled = true
        textField.becomeFirstResponder()
        updateSaveButton()
    }
    
    private func updateSaveButton() {
        if let count = textField.text?.intValue, count > 0 {
            container?.rightButton.isEnabled = true
        } else {
            container?.rightButton.isEnabled = false
        }
    }
    
}
