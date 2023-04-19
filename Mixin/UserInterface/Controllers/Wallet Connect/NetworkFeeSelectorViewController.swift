import UIKit

protocol NetworkFeeSelectorViewControllerDelegate: AnyObject {
    func networkFeeSelectorViewController(_ controller: NetworkFeeSelectorViewController, didSelectOption option: NetworkFeeOption)
}

class NetworkFeeSelectorViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var titleHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableViewBottomConstraint: NSLayoutConstraint!
    
    weak var delegate: NetworkFeeSelectorViewControllerDelegate?
    
    private let gasSymbol: String
    private let options: [NetworkFeeOption]
    
    init(options: [NetworkFeeOption], gasSymbol: String) {
        self.options = options
        self.gasSymbol = gasSymbol
        let nib = R.nib.networkFeeSelectorView
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = PopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
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
