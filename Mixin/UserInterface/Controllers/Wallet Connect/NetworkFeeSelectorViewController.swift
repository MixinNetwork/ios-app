import UIKit

protocol NetworkFeeSelectorViewControllerDelegate: AnyObject {
    func networkFeeSelectorViewController(_ controller: NetworkFeeSelectorViewController, didSelectOption option: NetworkFeeOption)
}

class NetworkFeeSelectorViewController: PopupSelectorViewController {
    
    weak var delegate: NetworkFeeSelectorViewControllerDelegate?
    
    private let gasSymbol: String
    private let options: [NetworkFeeOption]
    
    init(options: [NetworkFeeOption], gasSymbol: String) {
        self.options = options
        self.gasSymbol = gasSymbol
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = 75
        tableView.register(R.nib.networkFeeOptionCell)
        tableView.dataSource = self
        tableView.delegate = self
        titleView.titleLabel.text = R.string.localizable.network_fee("")
    }
    
}

extension NetworkFeeSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        options.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.fee_option, for: indexPath)!
        let option = options[indexPath.row]
        cell.speedLabel.text = option.speed
        cell.costLabel.text = option.gasValue + " " + gasSymbol
        cell.durationLabel.text = nil
        cell.valueLabel.text = nil
        return cell
    }
    
}

extension NetworkFeeSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.networkFeeSelectorViewController(self, didSelectOption: options[indexPath.row])
        close(tableView)
    }
    
}
