import UIKit

class NetworkFeeSelectorViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var titleHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableViewBottomConstraint: NSLayoutConstraint!
    
    private let options = [
        NetworkFeeOption(speed: "Fast", cost: "$7.57 - $7.68", duration: "~15 sec", value: "0.0047 - 0.0048 ETH"),
        NetworkFeeOption(speed: "Normal", cost: "$5.74 - $6.95", duration: "~30 sec", value: "0.0036 - 0.0043 ETH"),
        NetworkFeeOption(speed: "Slow", cost: "$5.74 - $6.21", duration: "45 sec+", value: "0.0036 - 0.0039 ETH"),
    ]
    
    convenience init() {
        self.init(nib: R.nib.networkFeeSelectorView)
        transitioningDelegate = PopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.cornerRadius = 13
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        titleView.titleLabel.text = R.string.localizable.network_fee("")
        titleView.closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        tableView.register(R.nib.networkFeeOptionCell)
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        preferredContentSize.height = titleHeightConstraint.constant
        + tableViewTopConstraint.constant
        + tableView.contentSize.height
        + tableViewBottomConstraint.constant
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
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
        cell.costLabel.text = option.cost
        cell.durationLabel.text = option.duration
        cell.valueLabel.text = option.value
        return cell
    }
    
}

extension NetworkFeeSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        close(tableView)
    }
    
}
